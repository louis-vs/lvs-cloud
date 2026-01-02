# Application Deployment Guide

Comprehensive guide for deploying applications on LVS Cloud using raw Kubernetes manifests.

## Architecture

Applications are deployed as raw Kubernetes manifests (not Helm charts) with:

- **Flux Kustomization** managing deployments
- **Flux Image Automation** updating container images
- **Traefik** providing ingress and TLS
- **Authelia** handling authentication

## Deploying a New App

### 1. PostgreSQL Setup (if needed)

**Add user/password to init scripts:**

Edit `platform/postgresql/init-scripts.yaml`:

- Add user creation in `02-create-users.sql` ConfigMap
- Add database grants in `03-grant-permissions.sql` ConfigMap

**Add password to secret:**

Edit `platform/postgresql/secret-auth.yaml`:

```yaml
stringData:
  my-app-password: "${POSTGRES_MY_APP_PASSWORD}"
```

**Create database and user on server:**

```bash
kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c \
  "CREATE DATABASE my_app_db"
kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c \
  "CREATE USER my_app_user WITH PASSWORD '<password>'"
kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c \
  "GRANT ALL PRIVILEGES ON DATABASE my_app_db TO my_app_user"
```

### 2. Create Application Structure

```bash
mkdir -p applications/my-app/k8s
```

### 3. Create Kubernetes Manifests

**k8s/deployment.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: applications
  labels:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/instance: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: my-app
      app.kubernetes.io/instance: my-app
  template:
    metadata:
      labels:
        app.kubernetes.io/name: my-app
        app.kubernetes.io/instance: my-app
    spec:
      containers:
      - name: my-app
        image: registry.lvs.me.uk/my-app:1.0.0 # {"$imagepolicy": "flux-system:my-app"}
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            cpu: "50m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        env:
          - name: DB_USER
            value: my_app_user
          - name: DB_HOST
            value: postgresql.platform.svc.cluster.local
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

**k8s/service.yaml:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: applications
  labels:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/instance: my-app
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/instance: my-app
```

**k8s/ingress.yaml:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: applications
  labels:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/instance: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    traefik.ingress.kubernetes.io/router.middlewares: applications-authelia-forwardauth@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - my-app.lvs.me.uk
      secretName: my-app-tls
  rules:
    - host: my-app.lvs.me.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
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

### 4. Create Kustomization

**kustomization.yaml** (root of app directory):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: applications
resources:
  - k8s/deployment.yaml
  - k8s/service.yaml
  - k8s/ingress.yaml
commonLabels:
  app.kubernetes.io/name: my-app
  app.kubernetes.io/instance: my-app
```

### 5. Flux Image Automation

**imagepolicy.yaml** (root of app directory):

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

**Note:** Flux will automatically update the `image:` field in `k8s/deployment.yaml` when new versions are pushed to the registry.

### 6. Register Flux Kustomization

Create **clusters/prod/my-app.yaml:**

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: monorepo
  path: ./applications/my-app
  prune: true
  wait: true
  timeout: 5m
  dependsOn:
    - name: storage-install
    - name: cert-manager-install
```

Update `clusters/prod/kustomization.yaml`:

```yaml
resources:
  # ... existing apps ...
  - my-app.yaml
```

Add DNS A record: `my-app.lvs.me.uk → server-ip`

Push to deploy:

```bash
git add applications/my-app/ clusters/prod/my-app.yaml clusters/prod/kustomization.yaml
git commit -m "feat(my-app): add new application"
git push
```

Monitor deployment:

```bash
flux reconcile kustomization my-app --with-source
kubectl get pods -n applications -l app.kubernetes.io/name=my-app
```

## CI/CD and Testing

### Automatic Build and Push

The monorepo includes a GitHub Actions workflow (`.github/workflows/build-and-push.yml`) that automatically:

1. **Detects changes** to applications on push to master
2. **Runs tests** (if `.ci/test.sh` exists)
3. **Builds Docker images** using multi-stage Dockerfiles
4. **Pushes to registry** at `registry.lvs.me.uk`
5. **Tags releases** with semver versions (1.0.{RUN_NUMBER})
6. **Flux auto-deploys** new images via ImagePolicy

**Key features:**

- Per-app test isolation with fail-fast disabled
- PostgreSQL service container available for tests
- Docker build cache optimization
- Only builds apps with changes (or all apps on manual trigger)

### Adding Tests

Create `applications/my-app/.ci/test.sh` to run tests before deployment:

```bash
#!/bin/bash
set -e

# Run tests using the 'test' Docker build target
docker run --rm \
  --network host \
  -e RAILS_ENV=test \
  -e DATABASE_URL="postgresql://test_user:test_password@localhost:5432/test_db" \
  my-app:test \
  bash -c "bin/rails db:create db:schema:load && bin/rails test"

echo "✅ All tests passed!"
```

**PostgreSQL service container available in CI:**

- Host: `localhost:5432`
- User: `test_user`
- Password: `test_password`
- Database: `test_db`
- Version: PostgreSQL 16
- Network: `host` mode for container access

**Multi-stage Dockerfile pattern:**

Your Dockerfile should include a `test` target for testing:

```dockerfile
# Build stage with dependencies
FROM base AS build
RUN bundle install
COPY . .
RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Test stage - includes test dependencies
FROM build AS test
ENV BUNDLE_WITHOUT=""
RUN bundle install --with test
CMD ["bin/rails", "test"]

# Production stage - minimal, no test deps
FROM base AS production
ENV BUNDLE_WITHOUT="development test"
# ... production setup
```

**Notes:**

- Tests run before images are pushed to registry
- Failed tests block deployment
- Use `DATABASE_URL` to let Rails automatically configure database connection
- Apps without `.ci/test.sh` skip testing (warning shown in logs)
