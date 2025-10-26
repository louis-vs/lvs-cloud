# Deployment Guide (Kubernetes + Flux)

## Overview

LVS Cloud uses **Flux GitOps** - all deployments are managed by pushing to Git. Changes are automatically detected and applied.

## Adding a New Application

### 1. Create Helm Chart

```bash
mkdir -p applications/my-app/chart/templates
```

**Chart.yaml:**

```yaml
apiVersion: v2
name: my-app
description: My application
type: application
version: 1.0.0
appVersion: "1.0.0"
```

**chart/values.yaml** (defaults):

```yaml
replicaCount: 2

image:
  repository: registry.lvs.me.uk/my-app
  pullPolicy: IfNotPresent
  tag: ""

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: my-app.lvs.me.uk
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: my-app-tls
      hosts:
        - my-app.lvs.me.uk

resources:
  requests: { cpu: "200m", memory: "256Mi" }
  limits: { cpu: "1", memory: "1Gi" }

readinessProbe:
  httpGet: { path: /healthz, port: http }
  initialDelaySeconds: 5
livenessProbe:
  httpGet: { path: /healthz, port: http }
  initialDelaySeconds: 10

env: []
```

**chart/templates/deployment.yaml**, **service.yaml**, **ingress.yaml** - copy from `applications/ruby-demo-app/chart/templates/`

### 2. Production Values

**values.yaml** (root of app directory):

```yaml
# Image config is in helmrelease.yaml for Flux automation
# Keep other app configuration here

env:
  - name: DB_USER
    value: my_app_user
  - name: DB_HOST
    value: postgresql
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: my_app_db
  - name: DB_PASSWORD  # Construct DATABASE_URL in your app code
    valueFrom:
      secretKeyRef:
        name: postgresql-auth
        key: my-app-password
```

### 3. HelmRelease with Image Automation

**helmrelease.yaml:**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-app
  namespace: default
spec:
  interval: 5m
  chart:
    spec:
      chart: ./applications/my-app/chart
      sourceRef:
        kind: GitRepository
        name: monorepo
        namespace: flux-system
      valuesFiles:
        - ./applications/my-app/values.yaml
  values:
    # Image automation - Flux updates these fields automatically
    image:
      repository: registry.lvs.me.uk/my-app # {"$imagepolicy": "flux-system:my-app:name"}
      tag: "1.0.0" # {"$imagepolicy": "flux-system:my-app:tag"}
```

**Note**: Image config goes in `spec.values` (not `values.yaml`) so Flux Image Automation can update it directly. This ensures only changes to this app's `helmrelease.yaml` trigger reconciliation, not changes to unrelated apps.

### 4. Flux Image Automation

**platform/flux-image-automation/my-app.yaml:**

```yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  image: registry.lvs.me.uk/my-app
  interval: 1m
  secretRef:
    name: registry-credentials  # Required for authentication
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: my-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: my-app
  policy:
    semver:
      range: ">=1.0.0"  # Matches tags like 1.0.1, 1.2.3, etc.
```

**Note**: The `registry-credentials` secret is created during bootstrap (see `docs/BOOTSTRAP.md`). It contains authentication for accessing the private registry.

### 5. Register App

Update `applications/kustomization.yaml`:

```yaml
resources:
  - ruby-demo-app/helmrelease.yaml
  - my-app/helmrelease.yaml
```

Update `platform/flux-image-automation/kustomization.yaml`:

```yaml
resources:
  - image-update.yaml
  - ruby-demo-app.yaml
  - my-app.yaml
```

### 6. Push to Deploy

```bash
git add applications/my-app platform/flux-image-automation/my-app.yaml applications/kustomization.yaml platform/flux-image-automation/kustomization.yaml
git commit -m "feat(my-app): add new application"
git push
```

**Flux will:**

1. Detect new HelmRelease in Git
2. Pull chart and values from monorepo
3. Render Helm templates with values
4. Deploy to cluster with initial image tag
5. Start monitoring registry for new image tags

**For subsequent deployments:**

1. Push code changes → GitHub Actions builds image with tag `1.0.X`
2. Flux ImageRepository scans registry (every 1m), finds new tag
3. Flux ImagePolicy selects latest semver tag
4. Flux ImageUpdateAutomation commits update to `helmrelease.yaml`
5. Flux applies updated HelmRelease → Kubernetes performs rolling update

## Database-Enabled Apps

### Add Database Secret

**platform/postgresql-new/secret-auth.yaml** - add your password key:

```yaml
stringData:
  postgres-password: "${POSTGRES_ADMIN_PASSWORD}"
  my-app-password: "${POSTGRES_MY_APP_PASSWORD}"
```

### Create Database

SSH to server and run:

```bash
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "CREATE DATABASE my_app_db"
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "CREATE USER my_app_user WITH PASSWORD '<password>'"
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "GRANT ALL PRIVILEGES ON DATABASE my_app_db TO my_app_user"
```

### App Connection

**IMPORTANT**: Kubernetes doesn't support `$(VAR)` shell substitution in env values. Instead, pass individual env vars and construct the DATABASE_URL in your application code.

**In your app's values.yaml:**

```yaml
env:
  - name: DB_USER
    value: my_app_user
  - name: DB_HOST
    value: postgresql
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: my_app_db
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgresql-auth
        key: my-app-password
```

**In your application code:**

```ruby
# Ruby example
DB_USER = ENV.fetch('DB_USER')
DB_PASSWORD = ENV.fetch('DB_PASSWORD')
DB_HOST = ENV.fetch('DB_HOST')
DB_PORT = ENV.fetch('DB_PORT')
DB_NAME = ENV.fetch('DB_NAME')

DATABASE_URL = "postgresql://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"
```

```python
# Python example
import os
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_HOST = os.getenv('DB_HOST')
DB_PORT = os.getenv('DB_PORT')
DB_NAME = os.getenv('DB_NAME')

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
```

## DNS Setup

Add A record: `my-app.lvs.me.uk → server-ip`

cert-manager will automatically obtain Let's Encrypt certificate.

## Monitoring Deployment

```bash
# Watch Flux reconciliation
flux get helmreleases -w

# Watch pods
kubectl get pods -l app.kubernetes.io/name=my-app -w

# Check pod logs
kubectl logs -f -l app.kubernetes.io/name=my-app

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Force reconcile
flux reconcile helmrelease my-app
```

## Troubleshooting

### HelmRelease Stuck

```bash
# Check HelmRelease status
flux get helmrelease my-app

# Describe for events
kubectl describe helmrelease my-app

# Check Helm controller logs
kubectl -n flux-system logs deploy/helm-controller -f

# Manually render chart
helm template applications/my-app/chart -f applications/my-app/values.yaml
```

### Image Not Updating

```bash
# Check ImageRepository
flux get images repository my-app

# Check ImagePolicy
flux get images policy my-app

# Force scan
flux reconcile image repository my-app

# Check commits from Flux
git log --oneline -5
```

### Pod CrashLooping

```bash
# Check logs
kubectl logs my-app-<pod-id>

# Describe pod
kubectl describe pod my-app-<pod-id>

# Check resource limits
kubectl top pod my-app-<pod-id>

# Check probes
kubectl get pod my-app-<pod-id> -o yaml | grep -A 10 Probe
```

## Infrastructure Changes

### Terraform Updates

1. Edit `infrastructure/main.tf`
2. Push to GitHub
3. Workflow runs `terraform plan`
4. Reply "LGTM" to approval issue
5. Terraform applies changes

**Note**: Infrastructure changes recreate the server. Longhorn data persists, but pods restart.

### Adding New Platform Services

1. Create manifests in `platform/<service>/`
2. Add kustomization.yaml
3. Update `platform/kustomization.yaml`
4. Push to Git → Flux deploys

## Quick Reference

**Build & push image:**

```bash
cd applications/my-app
docker build -t registry.lvs.me.uk/my-app:1.2.3 .
echo "$PASSWORD" | docker login registry.lvs.me.uk -u robot_user --password-stdin
docker push registry.lvs.me.uk/my-app:1.2.3
```

**Flux automatically detects and deploys.**

**Check deployment:**

```bash
kubectl get pods -l app.kubernetes.io/name=my-app
kubectl logs -f -l app.kubernetes.io/name=my-app
```

**Access app:**

`https://my-app.lvs.me.uk` (TLS automatic)

## Next Steps

- [OPS.md](OPS.md) - Operations & troubleshooting
- [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) - Bootstrap guide for fresh clusters
- [applications/ruby-demo-app/](applications/ruby-demo-app/) - Working example application
