# VSMP Royalties Management System

Rails application for managing music royalties for VSMP (Videmus Music Publishing).

## Technology Stack

- **Framework**: Ruby on Rails 8.0
- **Database**: PostgreSQL 16 (multi-database configuration)
- **Job Queue**: SolidQueue with Mission Control
- **Storage**: AWS S3 (via ActiveStorage)
- **Deployment**: Kubernetes with Flux CD

## Database Configuration

This application uses Rails' multi-database feature with **four separate databases**:

1. **vsmp_royalties** - Primary database (models, business logic)
2. **vsmp_royalties_cache** - ActiveSupport::Cache::Store backend
3. **vsmp_royalties_queue** - SolidQueue job queue
4. **vsmp_royalties_cable** - ActionCable connections

### Database Setup (Production)

When deploying to production, ensure all four databases exist and the `vsmp_royalties` user has full permissions:

```sql
-- Create databases
CREATE DATABASE vsmp_royalties;
CREATE DATABASE vsmp_royalties_cache;
CREATE DATABASE vsmp_royalties_queue;
CREATE DATABASE vsmp_royalties_cable;

-- Create user
CREATE USER vsmp_royalties WITH PASSWORD 'your_secure_password';

-- Grant ownership (recommended for Rails multi-db)
ALTER DATABASE vsmp_royalties OWNER TO vsmp_royalties;
ALTER DATABASE vsmp_royalties_cache OWNER TO vsmp_royalties;
ALTER DATABASE vsmp_royalties_queue OWNER TO vsmp_royalties;
ALTER DATABASE vsmp_royalties_cable OWNER TO vsmp_royalties;

-- Alternative: Grant specific permissions
GRANT ALL PRIVILEGES ON DATABASE vsmp_royalties TO vsmp_royalties;
GRANT ALL PRIVILEGES ON DATABASE vsmp_royalties_cache TO vsmp_royalties;
GRANT ALL PRIVILEGES ON DATABASE vsmp_royalties_queue TO vsmp_royalties;
GRANT ALL PRIVILEGES ON DATABASE vsmp_royalties_cable TO vsmp_royalties;

-- For PostgreSQL 15+, grant schema permissions
\c vsmp_royalties
GRANT ALL ON SCHEMA public TO vsmp_royalties;
\c vsmp_royalties_cache
GRANT ALL ON SCHEMA public TO vsmp_royalties;
\c vsmp_royalties_queue
GRANT ALL ON SCHEMA public TO vsmp_royalties;
\c vsmp_royalties_cable
GRANT ALL ON SCHEMA public TO vsmp_royalties;
```

Database credentials are stored in Rails encrypted credentials (see `config/credentials.yml.enc`).

## Development

```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:setup

# Run tests
bin/rails test

# Start development server
bin/dev
```

## Production Deployment

The application is deployed to Kubernetes via Flux CD.

### Deployment Architecture

- **Namespace**: `applications`
- **Registry**: `registry.lvs.me.uk/vsmp-royalties`
- **URL**: <https://royalties.lvs.me.uk>
- **Health Check**: <https://royalties.lvs.me.uk/up>

### Checking Deployment Status

```bash
# Connect to cluster
./scripts/connect-k8s.sh

# Check Flux kustomization
flux get kustomizations | grep vsmp

# Check pods
kubectl get pods -n applications | grep vsmp

# View pod logs
kubectl logs -n applications -l app.kubernetes.io/name=vsmp-royalties --tail=100

# Follow logs
kubectl logs -n applications -l app.kubernetes.io/name=vsmp-royalties -f

# Check ingress
kubectl get ingress -n applications | grep vsmp

# Check secrets
kubectl get secret vsmp-royalties-secrets -n applications
```

### Debugging Production Issues

```bash
# Force reconciliation
flux reconcile kustomization vsmp-royalties --with-source

# Check Flux logs
flux logs --kind=Kustomization --name=vsmp-royalties --tail=50

# Get pod details
kubectl describe pod -n applications -l app.kubernetes.io/name=vsmp-royalties

# Exec into pod
kubectl exec -it -n applications deployment/vsmp-royalties -- /bin/bash

# Check Rails console (if needed)
kubectl exec -it -n applications deployment/vsmp-royalties -- bin/rails console

# Check database connection
kubectl exec -it -n applications deployment/vsmp-royalties -- bin/rails runner "puts ActiveRecord::Base.connection.execute('SELECT version()').first"
```

### Triggering New Deployments

Deployments are triggered automatically via GitHub Actions when code is pushed to master:

1. Push changes to `applications/vsmp-royalties/`
2. GitHub Actions builds and tags Docker image
3. Flux ImagePolicy detects new image
4. Flux updates `k8s/deployment.yaml` and deploys
5. Pod startup runs `db:prepare` (migrations run automatically)

Manual trigger:

```bash
gh workflow run "Build and Push Images"
```

### Image Automation

Images are automatically updated by Flux when new versions are pushed to the registry.

```bash
# Check image policy status
flux get image policy vsmp-royalties -n flux-system

# Check image repository
flux get image repository vsmp-royalties -n flux-system
```

## Monitoring

- **Logs**: Grafana Loki (via Promtail)
- **Metrics**: Prometheus
- **Jobs**: Mission Control at `/jobs`

Access Grafana at <https://grafana.lvs.me.uk> to view logs and metrics.

## Configuration

- **Secrets**: Encrypted with SOPS and deployed via Flux
- **Rails credentials**: `config/credentials.yml.enc` (key in secrets)
- **Environment variables**: Configured in `k8s/deployment.yaml`

## Health Check

The application provides a health check endpoint:

```bash
curl https://royalties.lvs.me.uk/up
```

Expected response: `200 OK`
