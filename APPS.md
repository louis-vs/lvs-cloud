# Application Guide

Streamlined guide for deploying and debugging applications on LVS Cloud.

## Deploying a New App

### 1. PostgreSQL Setup (if needed)

**Add user/password to init scripts:**

Edit `platform/postgresql-new/init-scripts.yaml`:

- Add user creation in `02-create-users.sql` ConfigMap
- Add database grants in `03-grant-permissions.sql` ConfigMap

**Add password to secret:**

Edit `platform/postgresql-new/secret-auth.yaml`:

```yaml
stringData:
  my-app-password: "${POSTGRES_MY_APP_PASSWORD}"
```

**Create database and user on server:**

```bash
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "CREATE DATABASE my_app_db"
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "CREATE USER my_app_user WITH PASSWORD '<password>'"
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "GRANT ALL PRIVILEGES ON DATABASE my_app_db TO my_app_user"
```

### 2. Create Application Structure

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
  requests: { cpu: "50m", memory: "128Mi" }
  limits: { cpu: "500m", memory: "512Mi" }

env: []
```

**chart/templates/** - copy from `applications/ruby-demo-app/chart/templates/`

### 3. Production Values

**values.yaml** (root of app directory):

```yaml
# Database connection (if needed)
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

**In your app code**, construct DATABASE_URL from individual env vars:

```ruby
# Ruby
DATABASE_URL = "postgresql://#{ENV['DB_USER']}:#{ENV['DB_PASSWORD']}@#{ENV['DB_HOST']}:#{ENV['DB_PORT']}/#{ENV['DB_NAME']}"
```

```python
# Python
DATABASE_URL = f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
```

### 4. HelmRelease with Image Automation

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
    image:
      repository: registry.lvs.me.uk/my-app # {"$imagepolicy": "flux-system:my-app:name"}
      tag: "1.0.0" # {"$imagepolicy": "flux-system:my-app:tag"}
```

### 5. Flux Image Automation

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
    name: registry-credentials
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
      range: ">=1.0.0"
```

### 6. Register and Deploy

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

Add DNS A record: `my-app.lvs.me.uk → server-ip`

Push to deploy:

```bash
git add applications/my-app platform/flux-image-automation/my-app.yaml applications/kustomization.yaml platform/flux-image-automation/kustomization.yaml
git commit -m "feat(my-app): add new application"
git push
```

## Essential Debugging

### Quick Status Checks

```bash
# Cluster overview
kubectl get nodes
kubectl get pods -A

# App status
kubectl get pods -l app.kubernetes.io/name=my-app
kubectl logs -f -l app.kubernetes.io/name=my-app

# Flux status
flux get helmreleases
flux get images all

# Database
kubectl exec -it postgresql-0 -- psql -U postgres -c '\l'
```

### Common Issues

**Pod not starting:**

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs -p <pod-name>  # Previous logs if crashed
```

**Flux not syncing:**

```bash
flux get sources git monorepo
flux reconcile source git monorepo
flux reconcile helmrelease my-app
```

**Image not updating:**

```bash
flux get images repository my-app
flux get images policy my-app
flux reconcile image repository my-app
kubectl get secret registry-credentials -n flux-system  # Should exist
```

**Database connection issues:**

```bash
kubectl exec -it postgresql-0 -- psql -U postgres -c "\du"
kubectl exec -it postgresql-0 -- psql -U my_app_user -d my_app_db -c "SELECT 1"
```

**Certificate issues:**

```bash
kubectl get certificates
kubectl describe certificate my-app-tls
kubectl -n cert-manager logs deploy/cert-manager -f
```

### Force Reconciliation

```bash
# Force Flux to resync everything
flux reconcile source git monorepo --with-source
flux reconcile kustomization apps
flux reconcile helmrelease my-app

# Force image scan
flux reconcile image repository my-app

# Full reconciliation chain (git -> chart -> helmrelease)
flux reconcile source git monorepo -n flux-system
flux reconcile source chart default-my-app -n flux-system
flux reconcile helmrelease my-app -n default

# Restart pod
kubectl rollout restart deployment/my-app
```

### Updating Helm Charts

When modifying Helm chart templates (not just values), you must bump the chart version to force Flux to repackage:

**Important**: If you only change chart templates (`chart/templates/*`) without bumping the version in `Chart.yaml`, Flux will not repackage the chart and changes won't deploy.

```bash
# 1. Edit chart files in applications/my-app/chart/templates/
# 2. Bump version in applications/my-app/chart/Chart.yaml
#    version: 1.0.0 -> 1.0.1
# 3. Commit and push
git add applications/my-app/chart/
git commit -m "fix(my-app): update chart template"
git push

# 4. Monitor deployment
flux reconcile source git monorepo -n flux-system
flux reconcile source chart default-my-app -n flux-system
flux reconcile helmrelease my-app -n default

# Verify new chart version deployed
kubectl get helmrelease my-app -n default -o jsonpath='{.status.lastAttemptedRevision}'
```

### Resource Monitoring

```bash
# Node and pod resources
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Persistent volumes
kubectl get pv
kubectl -n longhorn-system get volumes

# Database sizes
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC"
```

### Emergency Procedures

**Rollback deployment:**

```bash
git revert HEAD
git push
```

**Restart cluster:**

```bash
ssh ubuntu@$(dig +short app.lvs.me.uk)
sudo systemctl restart k3s
```

**Backup database:**

```bash
kubectl exec postgresql-0 -- pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql.gz
```

## Access Points

- **Grafana**: <https://grafana.lvs.me.uk>
- **Registry**: <https://registry.lvs.me.uk>
- **SSH**: `ssh ubuntu@$(dig +short app.lvs.me.uk)`
- **PostgreSQL** (internal): `postgresql.default.svc.cluster.local:5432`

## Further Reading

- **docs/BOOTSTRAP.md** - Fresh cluster setup
- **applications/ruby-demo-app/** - Working example
- **Flux Docs**: <https://fluxcd.io/docs/>
