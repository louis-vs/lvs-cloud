# Ruby Demo App

Simple Sinatra web application demonstrating GitOps deployment with PostgreSQL database.

## Database Setup

On **first deployment only**, create the database user and secret:

```bash
# Generate a secure password for the database user
RUBY_PASSWORD=$(openssl rand -base64 24)

# Get admin password from your local password manager
POSTGRES_PASSWORD='your-local-admin-password'

# Create PostgreSQL user and database
kubectl exec postgresql-0 -n platform -- env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -U postgres -c "CREATE USER ruby_demo_user WITH PASSWORD '$RUBY_PASSWORD';"

kubectl exec postgresql-0 -n platform -- env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -U postgres -c "CREATE DATABASE ruby_demo OWNER ruby_demo_user;"

kubectl exec postgresql-0 -n platform -- env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -U postgres -d ruby_demo -c "GRANT ALL PRIVILEGES ON DATABASE ruby_demo TO ruby_demo_user; GRANT ALL ON SCHEMA public TO ruby_demo_user;"

# Create application secret in applications namespace
kubectl create secret generic ruby-app-postgresql -n applications \
  --from-literal=ruby-password="$RUBY_PASSWORD"
```

**Note:** The database user and secret persist across pod restarts. Only create them once during initial setup.

## Application Details

- **Language:** Ruby (Sinatra)
- **Database:** PostgreSQL (shared platform instance)
- **Database Name:** `ruby_demo`
- **Database User:** `ruby_demo_user`
- **Namespace:** `applications`

## Deployment

Deployed via Flux GitOps:

- Image built by GitHub Actions on push to main
- Flux Image Automation scans registry and updates `k8s/deployment.yaml`
- Rolling deployment with 2 replicas
- Manifests managed in `k8s/` directory

## Access

<https://app.lvs.me.uk>
