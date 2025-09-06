# LVS Cloud - Private Cloud Infrastructure

Personal private cloud on Hetzner with enterprise-grade monitoring, automatic deployments, and cost-effective hosting.

## Quick Status

| Service | URL | Status |
|---------|-----|--------|
| **Grafana** | https://grafana.lvs.me.uk | ✅ (admin/secure-pass) |
| **Registry** | https://registry.lvs.me.uk | ✅ (see .env) |
| **Prometheus** | https://prometheus.lvs.me.uk | ✅ |
| **Ruby Demo** | https://app.lvs.me.uk | ✅ |

**Server:** Hetzner cx22 (2 vCPU, 4GB RAM)
**Total Cost:** €9.89/month (€4.90 server + €4.99 Object Storage)

## Architecture

```
GitHub Push → Actions → Registry → Watchtower → Live
     ↓           ↓         ↓          ↓         ↓
   Code      Build    Push Image  Auto-update  Running
```

**Services:**
- **Traefik**: SSL termination, routing
- **Registry**: Container images (registry.lvs.me.uk)
- **Monitoring**: Grafana + Prometheus + Loki
- **Apps**: Whatever you deploy

## Quick Commands

```bash
# Deploy infrastructure (requires approval)
gh workflow run "Deploy Infrastructure"

# Check service status
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker ps'

# View logs
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker logs grafana'

# Emergency rebuild
cd infrastructure && terraform destroy -auto-approve && terraform apply -auto-approve
```

## Current Issues

- [x] **GitOps**: Apps only deploy on compose file changes, not code changes ✅
- [x] **Security**: Grafana uses hardcoded admin/admin123 password ✅
- [x] **Structure**: Platform services mixed with user apps in applications/ ✅
- [ ] **Monitoring**: No app metrics collection configured
- [x] **Scalability**: Only handles one hardcoded Ruby app ✅

## Next: Adding Apps

See [DEPLOY.md](DEPLOY.md) for adding new applications.
See [OPS.md](OPS.md) for troubleshooting and maintenance.
