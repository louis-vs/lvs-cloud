# LVS Cloud - Kubernetes Private Cloud

**Kubernetes-native private cloud** running on a single k3s node with enterprise GitOps patterns. Push code → Flux automatically deploys.

## Quick Status

| Service | URL | Status |
|---------|-----|--------|
| **Grafana** | <https://grafana.lvs.me.uk> | ✅ (admin/secure-pass) |
| **Registry** | <https://registry.lvs.me.uk> | ✅ (robot_user) |
| **Ruby Demo** | <https://app.lvs.me.uk> | ✅ |

**Infrastructure:** Hetzner cx22 (2 vCPU, 4GB RAM) + 50GB block storage
**Total Cost:** €9.89/month (€4.90 server + €4.99 Object Storage)

## Architecture

```
Developer → Git Push
         ↓
   GitHub Actions (build + push image)
         ↓
   registry.lvs.me.uk/app:1.2.3
         ↓
   Flux CD (detects new tag)
         ↓
   Updates values.yaml → commits
         ↓
   k3s deploys with rolling update
         ↓
   Live app with TLS cert
```

**Stack:**

- **k3s**: Lightweight Kubernetes (weekly auto-upgrades)
- **Flux CD**: GitOps operator with image automation
- **Longhorn**: Distributed storage with S3 backups (Hetzner)
- **cert-manager**: Automated TLS certificates
- **PostgreSQL**: Bitnami Helm chart (Longhorn PVCs)
- **LGTM**: Loki + Grafana + Tempo + Mimir (observability)
- **External Registry**: Docker + Caddy (outside cluster)

## Quick Commands

```bash
# SSH to server
ssh ubuntu@$(dig +short app.lvs.me.uk)

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Monitor Flux
flux get all
flux logs --all-namespaces --follow

# Force reconciliation
flux reconcile source git monorepo
flux reconcile kustomization apps

# View application logs
kubectl logs -f -l app.kubernetes.io/name=ruby-demo-app

# Port-forward to services
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

## Deployment Flow

**Code changes:**

1. Edit code in `applications/ruby-demo-app/`
2. Push to `master`
3. GitHub Actions builds image → pushes as `1.0.X`
4. Flux detects new tag
5. Updates `applications/ruby-demo-app/values.yaml`
6. Commits change → triggers Helm reconcile
7. K8s rolls out new pods with probes

**Infrastructure changes:**

1. Edit Terraform in `infrastructure/`
2. Push to `master`
3. GitHub Actions runs `terraform plan`
4. Reply "LGTM" to approval issue
5. Terraform recreates server with k3s + Flux
6. Flux deploys everything from Git

## Current Status

- [x] **k3s cluster**: Single node, weekly auto-upgrades ✅
- [x] **Flux GitOps**: Automatic image updates + deployments ✅
- [x] **Longhorn storage**: PVCs with S3 backups ✅
- [x] **cert-manager**: Automated TLS for apps ✅
- [x] **PostgreSQL**: Shared database server with per-app DBs ✅
- [x] **LGTM stack**: Full observability (Grafana dashboards persist) ✅
- [x] **External registry**: Docker + Caddy with Let's Encrypt ✅
- [x] **Helm charts**: Apps packaged with values + image setters ✅

**System Status**: ✅ Production ready - Full Kubernetes + GitOps

## Documentation

- **[DEPLOY.md](DEPLOY.md)**: Adding apps, database setup, deployment patterns
- **[OPS.md](OPS.md)**: Troubleshooting, monitoring, maintenance
- **[POSTGRES.md](POSTGRES.md)**: Database management (kept for reference)

### Migration Guides (docs/migration/)

- **[ARCHITECTURE.md](docs/migration/ARCHITECTURE.md)**: New architecture overview
- **[K3S_SETUP.md](docs/migration/K3S_SETUP.md)**: k3s installation & config
- **[FLUX_SETUP.md](docs/migration/FLUX_SETUP.md)**: Flux GitOps & image automation
- **[REGISTRY.md](docs/migration/REGISTRY.md)**: External registry setup
- **[STORAGE.md](docs/migration/STORAGE.md)**: Longhorn + S3 backups
- **[APPS.md](docs/migration/APPS.md)**: Converting apps to Helm charts

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <description>

Examples:
feat(platform): add new monitoring dashboard
fix(ruby-demo-app): resolve database connection issue
chore(infrastructure): upgrade k3s version
docs: update deployment guide
```

## Repository Structure

```
lvs-cloud/
├── clusters/prod/              # Flux entry point
├── infrastructure/
│   ├── main.tf                 # Hetzner + k3s
│   └── longhorn/               # Storage setup
├── platform/
│   ├── cert-manager/           # TLS automation
│   ├── postgresql-new/         # Database server
│   ├── flux-image-automation/  # Image policies
│   └── helmrepositories/       # Helm chart sources
├── applications/
│   └── ruby-demo-app/
│       ├── chart/              # Helm chart
│       ├── values.yaml         # Flux image setters
│       └── helmrelease.yaml    # Deployment config
└── docs/migration/             # Migration guides
```

## Next Steps

See [DEPLOY.md](DEPLOY.md) for adding new applications.
