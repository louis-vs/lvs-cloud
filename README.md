# LVS Cloud - Private Cloud Infrastructure

**Personal private cloud platform** that scales while being maintainable by a single developer. Enterprise-grade monitoring with automatic deployments at startup costs.

## Quick Status

| Service | URL | Status |
|---------|-----|--------|
| **Grafana** | <https://grafana.lvs.me.uk> | ✅ (admin/secure-pass) |
| **Registry** | <https://registry.lvs.me.uk> | ✅ (see .env) |
| **Ruby Demo** | <https://app.lvs.me.uk> | ✅ |

**Internal Services** (accessible via Grafana):

- **Mimir**: Metrics storage & querying
- **Tempo**: Distributed tracing
- **Loki**: Log aggregation
- **Grafana Alloy**: Metrics & log collection agent

**Infrastructure:** Hetzner cx22 (2 vCPU, 4GB RAM) + 50GB block storage
**Total Cost:** €9.89/month (€4.90 server + €4.99 Object Storage)

## Consolidated DevOps Architecture

**Two Control Points:**

- **GitHub**: CI/CD pipeline, infrastructure deployments, code management
- **Grafana**: Monitoring, dashboards, logs, traces, metrics - everything observability

```plaintext
GitHub Push → Actions → Registry → Watchtower → Live
     ↓           ↓         ↓          ↓         ↓
   Code      Build    Push Image  Auto-update  Running
                                               ↓
                                        PostgreSQL ← Apps
                                               ↓
                                        Grafana Alloy
                                               ↓
                                        LGTM Stack
                                               ↓
                                        Grafana Dashboards
```

**Platform Services:**

- **Traefik**: SSL termination & automatic routing
- **Registry**: Private container registry (registry.lvs.me.uk)
- **PostgreSQL**: Shared database server with per-app databases and users
- **LGTM Stack**: Loki + Grafana + Tempo + Mimir (full observability)
- **Grafana Alloy**: Automatic metrics & log collection from all containers
- **Persistent Dashboards**: All Grafana data persisted for custom dashboard development

## Quick Commands

```bash
# Deploy everything (requires approval for infrastructure changes)
gh workflow run "Deploy Infrastructure & Applications"

# Deploy specific app only
gh workflow run "Deploy Infrastructure & Applications" -f app_name=ruby-demo-app

# Deploy all apps and platform services
gh workflow run "Deploy Infrastructure & Applications" -f deploy_everything=true

# Check service status
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker ps'

# View logs
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker logs grafana'

# Emergency rebuild
cd infrastructure && terraform destroy -auto-approve && terraform apply -auto-approve
```

## Current Status

- [x] **GitOps**: Apps deploy automatically on ANY file changes via unified workflow ✅
- [x] **Security**: All services use secure credentials from GitHub secrets ✅
- [x] **Structure**: Clean separation - platform/ for services, applications/ for apps ✅
- [x] **Scalability**: Dynamic app detection supports unlimited apps via matrix strategy ✅
- [x] **Storage**: Persistent data on 50GB block storage, configs in Git for reproducibility ✅
- [x] **Monitoring**: LGTM stack with persistent dashboards, app metrics collection working ✅
- [x] **Consolidated DevOps**: GitHub for CI/CD, Grafana for all observability ✅

**System Status**: ✅ Production ready - dashboards working, log streams active, metrics collecting

## Future Development

- **TypeScript App**: tRPC-based application template for modern web apps
- **Go App**: Builtin server template with Go templates for backend services
- **Python App**: FastAPI application template for API development
- **Additional Templates**: More language/framework templates as needed

## Next: Adding Apps

See [DEPLOY.md](DEPLOY.md) for adding new applications.
See [OPS.md](OPS.md) for troubleshooting and maintenance.
