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
   registry.lvs.me.uk/app:1.0.X
         ↓
   Flux ImageRepository (scans registry)
         ↓
   Flux ImagePolicy (selects latest tag)
         ↓
   Flux ImageUpdateAutomation (commits update)
         ↓
   Updates helmrelease.yaml spec.values.image.tag
         ↓
   Flux applies updated HelmRelease
         ↓
   k3s performs rolling update
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
# Setup kubectl access (run once per session)
./scripts/connect-k8s.sh

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

# Kill kubectl tunnel if needed
pkill -f 'ssh.*6443:127.0.0.1:6443'
```

## Deployment Flow

**Code changes:**

1. Edit code in `applications/ruby-demo-app/`
2. Push to `master`
3. GitHub Actions builds image → pushes as `1.0.X`
4. Flux ImageRepository scans registry (every 1m)
5. Flux ImagePolicy selects latest semver tag
6. Flux ImageUpdateAutomation commits update to `helmrelease.yaml` spec.values.image.tag
7. Flux applies updated HelmRelease to cluster
8. K8s performs rolling update with health probes

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

- **[docs/BOOTSTRAP.md](docs/BOOTSTRAP.md)**: Complete setup guide from scratch
- **[DEPLOY.md](DEPLOY.md)**: Adding apps, database setup, deployment patterns
- **[OPS.md](OPS.md)**: Troubleshooting, monitoring, maintenance
- **[POSTGRES.md](POSTGRES.md)**: Database management reference

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
│       ├── chart/              # Helm chart templates
│       ├── values.yaml         # App configuration
│       └── helmrelease.yaml    # Flux deployment + image automation
└── docs/                       # Documentation
```

## Getting Started

**New cluster?** Run `./bootstrap.sh` after Terraform provisions the server.

**Add an app?** See [DEPLOY.md](DEPLOY.md) for the application deployment guide.
