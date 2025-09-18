# Deployment Guide

## Adding New Apps

### App Structure Required

```plaintext
applications/your-app/
├── Dockerfile
├── docker-compose.prod.yml  # Required for deployment
├── your app code...
```

### docker-compose.prod.yml Template

```yaml
services:
  your-app:
    image: registry.lvs.me.uk/your-app:latest
    container_name: your-app
    restart: unless-stopped
    environment:
      - YOUR_ENV=production
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.your-app.rule=Host(`your-app.lvs.me.uk`)'
      - 'traefik.http.routers.your-app.entrypoints=websecure'
      - 'traefik.http.routers.your-app.tls.certresolver=letsencrypt'
      - 'traefik.http.services.your-app.loadbalancer.server.port=8080'
    networks:
      - web
      - monitoring # Connect to monitoring for metrics

networks:
  web:
    name: web
    external: true
  monitoring:
    name: monitoring
    external: true
```

### DNS Setup

Add A record: `your-app.lvs.me.uk → server-ip`

### Current Deployment Flow

1. **Push code** → `applications/your-app/**`
2. **Workflow detects** changed apps automatically
3. **Builds Docker image** with multi-arch support (amd64/arm64)
4. **Pushes to registry** → registry.lvs.me.uk/your-app:latest
5. **SSH deploys** directly to server with health checks
6. **Zero downtime** deployment via Docker Compose

## Infrastructure Changes

### Terraform Changes

**REQUIRES APPROVAL** - Can destroy/recreate server

```bash
# Make changes to infrastructure/
git add infrastructure/
git commit -m "infra: update server config"
git push origin master

# Manually approve in GitHub Actions
# OR force run: gh workflow run "Deploy Infrastructure & Applications"
```

### What Triggers Infrastructure Deploy

- `infrastructure/**` - Terraform changes
- `platform/traefik/**` - SSL/routing changes
- `platform/monitoring/**` - Monitoring changes
- `platform/registry/**` - Registry changes

**Note**: User apps in `applications/` trigger the applications job in the unified workflow

## Secrets Management

GitHub Repository Secrets:

```bash
HCLOUD_TOKEN_RO=xxx      # Read-only Hetzner API
HCLOUD_TOKEN_RW=xxx      # Read-write Hetzner API
S3_ACCESS_KEY=xxx        # Object Storage access
S3_SECRET_KEY=xxx        # Object Storage secret
SSH_PRIVATE_KEY=xxx      # Server access
REGISTRY_USERNAME=admin  # From .env file
REGISTRY_PASSWORD=xxx    # From .env file
GRAFANA_ADMIN_PASS=xxx   # Grafana admin password
```

## First Time Setup

### 1. Hetzner Setup

- Create API tokens (RO + RW)
- Create Object Storage bucket: `lvs-cloud-terraform-state`
- Get S3 credentials for bucket

### 2. Environment Setup

```bash
cp .env.example .env
# Edit .env with your values
source .env
```

### 3. Terraform State Setup

```bash
cd infrastructure
terraform init  # Uses S3 backend automatically
terraform apply # Creates server + initial setup
```

### 4. DNS Setup

Point these A records to your server IP:

- `app.lvs.me.uk`
- `grafana.lvs.me.uk`
- `prometheus.lvs.me.uk`
- `registry.lvs.me.uk`

### 5. GitHub Secrets

Add all secrets listed above to repository settings.

## Disaster Recovery

### Complete Rebuild

```bash
# 1. Destroy everything
cd infrastructure && terraform destroy -auto-approve

# 2. Recreate
terraform apply -auto-approve

# 3. Wait ~10 minutes for services to start
# SSL certs will regenerate automatically
```

### State Recovery

If you lose terraform state:

1. Import existing server: `terraform import hcloud_server.main <server-id>`
2. Or destroy and recreate (faster)
