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

### Database-Enabled Apps

LVS Cloud provides a shared PostgreSQL server for all applications. Each app gets its own database and user.

#### Environment Variables

Add these to your `docker-compose.prod.yml`:

```yaml
environment:
  - DATABASE_URL=postgresql://your_app_user:${POSTGRES_YOUR_APP_PASSWORD}@postgresql:5432/your_app_db
  # Alternative format:
  - DB_HOST=postgresql
  - DB_PORT=5432
  - DB_NAME=your_app_db
  - DB_USER=your_app_user
  - DB_PASSWORD=${POSTGRES_YOUR_APP_PASSWORD}
```

#### Connection Examples

**Ruby (using pg gem):**

```ruby
require 'pg'
conn = PG.connect(ENV['DATABASE_URL'])
```

**TypeScript (using pg or Prisma):**

```typescript
// Using pg
import { Pool } from 'pg'
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

// Using Prisma
// DATABASE_URL in .env file
```

**Python (using psycopg2 or SQLAlchemy):**

```python
import psycopg2
conn = psycopg2.connect(os.environ['DATABASE_URL'])

# SQLAlchemy
from sqlalchemy import create_engine
engine = create_engine(os.environ['DATABASE_URL'])
```

**Go (using lib/pq):**

```go
import "database/sql"
import _ "github.com/lib/pq"

db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
```

#### Available Databases

| App Type | Database | User | Password Secret |
|----------|----------|------|-----------------|
| Ruby Demo | `ruby_demo` | `ruby_demo_user` | `POSTGRES_RUBY_PASSWORD` |
| TypeScript | `typescript_app` | `typescript_user` | `POSTGRES_TS_PASSWORD` |
| Python API | `python_api` | `python_user` | `POSTGRES_PYTHON_PASSWORD` |
| Go Service | `go_service` | `go_user` | `POSTGRES_GO_PASSWORD` |

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
- `platform/postgresql/**` - Database changes

**Note**: User apps in `applications/` trigger the applications job in the unified workflow

## Storage Architecture

### Block Storage (Persistent)

- **Volume**: 50GB Hetzner block storage mounted at `/mnt/data`
- **Persistent data**: All service data stored on block storage for durability
- **Paths**:
  - `/mnt/data/grafana` - Grafana dashboards, users, settings
  - `/mnt/data/mimir` - Metrics storage (replaces Prometheus data)
  - `/mnt/data/tempo` - Distributed tracing data
  - `/mnt/data/loki` - Log aggregation data
  - `/mnt/data/registry` - Container images
  - `/mnt/data/postgresql` - PostgreSQL databases and data

### VM Storage (Ephemeral)

- **Configuration files**: Service configs stored in VM (reproducible via Git)
- **Logs**: Docker container logs (managed by Docker daemon)

### Permissions

Services run with unique UIDs for security isolation:

- Grafana: `472:472`
- Mimir: `10001:10001`
- Tempo: `10002:10002`
- Loki: `10003:10003`
- Registry: `1000:1000`
- PostgreSQL: `10004:10004`

## Secrets Management

GitHub Repository Secrets:

```bash
HCLOUD_TOKEN_RO=xxx         # Read-only Hetzner API
HCLOUD_TOKEN_RW=xxx         # Read-write Hetzner API
S3_ACCESS_KEY=xxx           # Object Storage access
S3_SECRET_KEY=xxx           # Object Storage secret
SSH_PRIVATE_KEY=xxx         # Server access
REGISTRY_USERNAME=admin     # From .env file
REGISTRY_PASSWORD=xxx       # From .env file
GRAFANA_ADMIN_PASS=xxx      # Grafana admin password
POSTGRES_ADMIN_PASSWORD=xxx # PostgreSQL admin password
POSTGRES_RUBY_PASSWORD=xxx  # Ruby app database password
POSTGRES_TS_PASSWORD=xxx    # TypeScript app database password
POSTGRES_PYTHON_PASSWORD=xxx # Python app database password
POSTGRES_GO_PASSWORD=xxx    # Go app database password
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
- `registry.lvs.me.uk`

**Note**: Mimir, Tempo, and Loki are internal-only services (not exposed to internet)

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
