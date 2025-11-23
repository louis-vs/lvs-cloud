# Application Deployment Guide

Comprehensive guide for deploying applications on LVS Cloud.

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

**IMPORTANT:** This file must include the complete structure (image, service, ingress, resources, env), not just env vars. It overrides/augments chart defaults.

```yaml
# Production values for my-app
# Flux image setters will update image values automatically

image:
  pullPolicy: Always

replicaCount: 2

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
  requests:
    cpu: "50m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

# Database connection (if needed)
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
  namespace: applications
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
