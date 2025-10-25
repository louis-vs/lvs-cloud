# Migration Complete: Docker → Kubernetes (k3s) + Flux GitOps

## Summary

Complete redesign from Docker Compose to Kubernetes-native architecture with enterprise GitOps patterns.

## What Changed

### Before (Docker Compose)

- Manual deployments via SSH + deploy.sh scripts
- Watchtower for automatic updates
- Traefik for SSL + routing
- Docker volumes at `/mnt/data`
- GitHub Actions SCP files → run scripts

### After (Kubernetes + Flux)

- **Automatic GitOps deployments** (push to Git → Flux deploys)
- **k3s** single-node Kubernetes cluster
- **Flux CD** for continuous deployment
- **Longhorn** distributed storage with S3 backups
- **cert-manager** for automated TLS
- **Helm charts** for all applications
- **In-cluster registry** with Longhorn storage and TLS

## New Architecture

```
Git Push → GitHub Actions (build image) → Registry
                                              ↓
                                    Flux detects change
                                              ↓
                                    Updates manifests
                                              ↓
                                    Commits change
                                              ↓
                                    k3s rolls out pods
```

## Directory Structure

```
infrastructure/           # ONLY Terraform + cloud-init
  ├── main.tf
  ├── cloud-init.yml
  └── ...

platform/                 # ALL Kubernetes platform services
  ├── helmrepositories/   # Helm chart repositories
  ├── storage-install/    # Longhorn deployment
  ├── storage-config/     # Longhorn recurring jobs
  ├── cert-manager-install/  # cert-manager deployment
  ├── cert-manager-config/   # Let's Encrypt issuers
  ├── registry/           # Docker Registry v2
  └── postgresql-new/     # PostgreSQL database

applications/             # User applications
  └── ruby-demo-app/

clusters/prod/            # Flux entry point
  ├── sources.yaml        # Git repository source
  ├── helmrepositories.yaml
  ├── storage-install.yaml
  ├── storage-config.yaml
  ├── cert-manager-install.yaml
  ├── cert-manager-config.yaml
  ├── registry.yaml
  ├── postgresql.yaml
  └── apps.yaml

docs/
  ├── BOOTSTRAP.md        # Complete setup guide
  ├── DEPLOY.md           # Application deployment
  └── OPS.md              # Operations & troubleshooting
```

## Deployment Order

Services deploy in this order with proper dependency management:

1. **flux-system** - Flux controllers
2. **helmrepositories** - Chart repositories (Bitnami, Jetstack, Longhorn)
3. **storage-install** - Longhorn storage system (~15 minutes)
4. **cert-manager-install** - TLS certificate manager (~10 minutes)
5. **storage-config** - Longhorn recurring backup jobs
6. **cert-manager-config** - Let's Encrypt cluster issuers
7. **registry** - Docker Registry v2 (~5 minutes)
8. **postgresql** - PostgreSQL database (~5-10 minutes)
9. **apps** - Applications (ruby-demo-app)

Total deployment time: **30-45 minutes**

## Key Features

### Automatic Deployments

1. Push code to `master`
2. GitHub Actions builds image with semver tag
3. Push to registry
4. Flux detects change and updates manifests
5. k3s performs rolling update
6. Pods deploy with health checks, resources, TLS

**Zero manual intervention after initial bootstrap.**

### Storage (Longhorn)

- PVCs for all stateful apps
- Daily snapshots (7 day retention)
- Weekly backups to Hetzner S3 (4 week retention)
- Single replica (appropriate for single node)
- Path: `/srv/data/longhorn` on host

### Docker Registry

- In-cluster deployment via Helm chart
- Traefik ingress with automated TLS from cert-manager
- Longhorn PVC for persistent storage (50GB)
- Basic auth (htpasswd)
- Daily snapshots + weekly S3 backups

### cert-manager

- Automated TLS for all Ingresses
- HTTP-01 challenge via Traefik
- Auto-renewal 30 days before expiry
- ClusterIssuers: staging + production

### Weekly k3s Upgrades

- systemd timer runs every Sunday 03:00
- Cordons node → upgrades k3s → uncordons
- Automatic (no manual intervention)

## Getting Started

**For fresh deployment:**

See [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) for complete step-by-step instructions.

**Quick summary:**

1. Ensure GitHub secrets are configured
2. Create Hetzner S3 buckets
3. Push to master → approve Terraform workflow
4. SSH to server
5. Run Flux bootstrap + create secrets (~5 commands)
6. Wait 30-45 minutes for automatic deployment
7. Done!

## Cost

**No change**: €9.89/month (€4.90 server + €4.99 storage)

## Performance

- **Single node**: cx22 (2 vCPU, 4GB RAM)
- **Kubernetes overhead**: ~500MB RAM for system pods
- **Available for apps**: ~3.5GB RAM, ~1.5 CPU
- **Storage**: Longhorn adds ~200MB overhead

## Documentation

- [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) - Complete setup from scratch
- [README.md](README.md) - Architecture overview
- [DEPLOY.md](DEPLOY.md) - Application deployment
- [OPS.md](OPS.md) - Operations & troubleshooting

## Status

✅ **Migration complete** - Ready for deployment

Next: Follow [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) for fresh cluster setup.
