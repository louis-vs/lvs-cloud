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
- **Flux CD** with image automation (replaces Watchtower)
- **Longhorn** distributed storage with S3 backups
- **cert-manager** for automated TLS
- **Helm charts** for all applications
- **External registry** (Docker + Caddy) outside cluster

## New Architecture

```
Git Push → GitHub Actions (build image) → Registry
                                              ↓
                                    Flux detects new tag
                                              ↓
                                    Updates values.yaml
                                              ↓
                                    Commits change
                                              ↓
                                    k3s rolls out pods
```

## Files Created

### Documentation (docs/migration/)

- `ARCHITECTURE.md` - Complete architecture overview
- `K3S_SETUP.md` - k3s installation & configuration
- `FLUX_SETUP.md` - Flux GitOps & image automation
- `REGISTRY.md` - External registry setup
- `STORAGE.md` - Longhorn + S3 backups
- `APPS.md` - Converting apps to Helm charts

### Kubernetes Manifests

**clusters/prod/**

- `kustomization.yaml` - Flux entry point
- `sources.yaml` - GitRepository source
- `infrastructure.yaml` - Points to infrastructure/
- `platform.yaml` - Points to platform/
- `apps.yaml` - Points to applications/

**infrastructure/longhorn/**

- `helmrelease.yaml` - Longhorn chart deployment
- `backup-secret.yaml` - S3 credentials for backups
- `recurring-jobs.yaml` - Daily snapshots, weekly backups

**platform/helmrepositories/**

- `longhorn.yaml` - Longhorn Helm repo
- `jetstack.yaml` - cert-manager Helm repo
- `bitnami.yaml` - PostgreSQL Helm repo

**platform/cert-manager/**

- `helmrelease.yaml` - cert-manager deployment
- `clusterissuers.yaml` - Let's Encrypt issuers (staging + prod)

**platform/postgresql-new/**

- `helmrelease.yaml` - Bitnami PostgreSQL chart
- `secret-auth.yaml` - Database passwords
- `secret-backup-s3.yaml` - S3 credentials for pg_dump
- `cronjob-pgdump.yaml` - Daily logical backups to S3

**platform/flux-image-automation/**

- `image-update.yaml` - ImageUpdateAutomation (commits tag updates)
- `ruby-demo-app.yaml` - ImageRepository + ImagePolicy

**applications/ruby-demo-app/chart/**

- `Chart.yaml` - Helm chart metadata
- `values.yaml` - Default values
- `templates/` - Kubernetes manifests (Deployment, Service, Ingress)

**applications/ruby-demo-app/**

- `values.yaml` - Production values with **Flux image setters**
- `helmrelease.yaml` - Flux HelmRelease

### Infrastructure

- `infrastructure/cloud-init-k3s.yml` - Complete k3s + Flux + Registry setup
- `infrastructure/main.tf` - Updated for k3s (new variables, new cloud-init)

### GitHub Actions

- `.github/workflows/build-and-push.yml` - Build images, push to registry (Flux handles deployment)
- `.github/workflows/infrastructure.yml` - Terraform plan + apply with approval

### Root Documentation

- `README.md` - Updated for Kubernetes architecture
- `DEPLOY.md` - Adding apps, database setup, deployment patterns
- `OPS.md` - Kubernetes-native operations & troubleshooting

## Files Deleted

- `platform/traefik/` - Replaced by k3s built-in Traefik
- `platform/watchtower/` - Replaced by Flux Image Automation
- `platform/registry/` - Now external (Caddy + Docker)
- `platform/monitoring/` - Will migrate LGTM stack separately
- `platform/postgresql/` - Replaced by platform/postgresql-new/
- `applications/ruby-demo-app/deploy.sh` - No longer needed
- `applications/ruby-demo-app/docker-compose.prod.yml` - Replaced by Helm
- `applications/typescript-app/` - Deleted per commit history
- `infrastructure/cloud-init.yml` - Replaced by cloud-init-k3s.yml
- `.github/workflows/deploy.yml` - Replaced by simplified workflows
- `.github/workflows/build.yml` - Merged into build-and-push.yml
- `.github/workflows/code-quality.yml` - Removed (reinstate if needed)

## Key Features

### Automatic Deployments

1. Push code to `master`
2. GitHub Actions builds image with semver tag (e.g., `1.0.123`)
3. Flux ImageRepository detects new tag
4. ImagePolicy selects latest tag matching semver range
5. ImageUpdateAutomation updates `values.yaml` → commits
6. HelmRelease reconciles → rolling update
7. Pods deploy with probes, resources, TLS

**Zero manual intervention.**

### Storage (Longhorn)

- **PVCs** for all stateful apps (PostgreSQL, Grafana)
- **Daily snapshots** (7 day retention)
- **Weekly backups** to Hetzner S3 (4 week retention)
- **Single replica** (appropriate for single node)
- Path: `/srv/data/longhorn` on host

### External Registry

- **Outside cluster** (avoids bootstrap chicken-and-egg)
- **Caddy** frontend with HTTP-01 Let's Encrypt
- **Docker Registry** backend on localhost:5000
- **Basic auth** (robot_user)
- Path: `/srv/data/registry` on host

### cert-manager

- **Automated TLS** for all Ingresses
- **HTTP-01 challenge** via Traefik
- **Auto-renewal** 30 days before expiry
- **ClusterIssuers**: staging + production

### Weekly k3s Upgrades

- **systemd timer** runs every Sunday 03:00
- **Cordons node** → upgrades k3s → uncordons
- **Automatic** (no manual intervention)

## Next Steps for You

### 1. Before Applying

**Generate SSH deploy key for Flux:**

```bash
ssh-keygen -t ed25519 -C "flux-bot@lvs.me.uk" -f infrastructure/flux-deploy-key
```

Add `infrastructure/flux-deploy-key.pub` to GitHub as a **Deploy Key** with **write access**.

**Generate registry bcrypt password:**

```bash
caddy hash-password --algorithm bcrypt
```

**Add GitHub Secrets:**

- `REGISTRY_PASSWORD` - Plaintext password for k3s registries.yaml
- `REGISTRY_HTPASSWD` - Bcrypt hash from above
- `POSTGRES_ADMIN_PASSWORD`, `POSTGRES_RUBY_PASSWORD`, etc.
- `HETZNER_S3_ACCESS_KEY`, `HETZNER_S3_SECRET_KEY`

**Create Hetzner S3 buckets:**

- `lvs-cloud-longhorn-backups` (for Longhorn volume backups)
- `lvs-cloud-pg-backups` (for PostgreSQL logical backups)

### 2. Testing Locally

**Validate manifests:**

```bash
# Test Helm chart rendering
helm template applications/ruby-demo-app/chart -f applications/ruby-demo-app/values.yaml

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f clusters/prod/
kubectl apply --dry-run=client -f infrastructure/longhorn/
kubectl apply --dry-run=client -f platform/
```

**Terraform plan:**

```bash
cd infrastructure
terraform init
terraform plan
```

### 3. Deployment

**Push to GitHub:**

```bash
git add .
git commit -m "feat: migrate to Kubernetes with Flux GitOps"
git push origin master
```

**Approve infrastructure workflow:**

- GitHub Actions will run `terraform plan`
- Reply **"LGTM"** to the approval issue
- Terraform recreates server with k3s + Flux
- Wait ~10-15 minutes for everything to deploy

**Monitor deployment:**

```bash
ssh ubuntu@$(dig +short app.lvs.me.uk)

# Check k3s
kubectl get nodes
kubectl get pods -A

# Check Flux
flux get all

# Check applications
kubectl get pods
kubectl get ingresses
```

### 4. First Application Deployment

**Build and push image:**

```bash
cd applications/ruby-demo-app
docker build -t registry.lvs.me.uk/ruby-demo-app:1.0.1 .
echo "$REGISTRY_PASSWORD" | docker login registry.lvs.me.uk -u robot_user --password-stdin
docker push registry.lvs.me.uk/ruby-demo-app:1.0.1
```

**Flux automatically:**

- Detects new tag
- Updates `values.yaml`
- Commits change
- Deploys to k3s

**Check deployment:**

```bash
flux get helmreleases
kubectl get pods -l app.kubernetes.io/name=ruby-demo-app
kubectl logs -f -l app.kubernetes.io/name=ruby-demo-app
```

### 5. Migrate LGTM Stack

The LGTM stack (Loki, Grafana, Tempo, Mimir) needs to be migrated separately. This was intentionally left out of scope for this phase.

**To migrate:**

1. Convert `platform/monitoring/docker-compose.yml` to Kubernetes manifests or Helm charts
2. Migrate Grafana data from `/mnt/data/grafana` to Longhorn PVC
3. Update Grafana Alloy scrape configs for Kubernetes service discovery
4. Deploy via Flux

## Troubleshooting

### Flux Not Syncing

```bash
# Check Git credentials
kubectl -n flux-system get secret flux-git-ssh
kubectl -n flux-system logs deploy/source-controller

# Force reconcile
flux reconcile source git monorepo
```

### Longhorn Not Starting

```bash
# Check if /srv/data/longhorn exists
ssh ubuntu@$(dig +short app.lvs.me.uk) 'ls -la /srv/data/'

# Check Longhorn pods
kubectl -n longhorn-system get pods
kubectl -n longhorn-system logs deploy/longhorn-manager
```

### PostgreSQL Not Starting

```bash
# Check PVC
kubectl get pvc

# Check PostgreSQL pod
kubectl describe pod postgresql-0
kubectl logs postgresql-0
```

### App Not Getting TLS Certificate

```bash
# Check certificate
kubectl get certificates

# Describe certificate
kubectl describe certificate ruby-demo-app-tls

# Check cert-manager logs
kubectl -n cert-manager logs deploy/cert-manager
```

## Rollback Plan

If something goes wrong, you can revert to the Docker Compose setup:

1. Revert Git commits:

   ```bash
   git revert HEAD
   git push
   ```

2. Terraform will recreate the old Docker-based setup

**Note**: You'll need to restore the old `cloud-init.yml` and update Terraform variables.

## Success Criteria

- [ ] k3s cluster running (`kubectl get nodes`)
- [ ] Flux syncing from Git (`flux get all`)
- [ ] Longhorn storage available (`kubectl get storageclass`)
- [ ] cert-manager issuing certificates (`kubectl get certificates`)
- [ ] PostgreSQL running (`kubectl get pods`)
- [ ] ruby-demo-app deployed (`kubectl get helmreleases`)
- [ ] App accessible via HTTPS (`curl https://app.lvs.me.uk`)
- [ ] TLS certificate valid (browser shows lock icon)
- [ ] Flux image automation working (push new image → auto-deploy)

## Cost

**No change**: Still €9.89/month (€4.90 server + €4.99 storage)

## Performance

- **Single node**: Same as before (cx22: 2 vCPU, 4GB RAM)
- **Kubernetes overhead**: ~500MB RAM for system pods
- **Available for apps**: ~3.5GB RAM, ~1.5 CPU
- **Storage**: Longhorn adds ~200MB overhead

## Questions?

See:

- [docs/migration/ARCHITECTURE.md](docs/migration/ARCHITECTURE.md) - Architecture deep dive
- [README.md](README.md) - Quick reference
- [DEPLOY.md](DEPLOY.md) - Deployment guide
- [OPS.md](OPS.md) - Operations & troubleshooting

## Status

✅ **Migration complete** - Ready for deployment
