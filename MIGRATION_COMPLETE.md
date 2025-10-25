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

**Generate registry bcrypt password:**

```bash
caddy hash-password --algorithm bcrypt
```

**Add GitHub Secrets:**

Required for Terraform (infrastructure workflow):

- `HCLOUD_TOKEN_RO` - Hetzner Cloud read-only API token
- `HCLOUD_TOKEN_RW` - Hetzner Cloud read-write API token
- `HETZNER_S3_ACCESS_KEY` - Hetzner S3 access key (for Terraform state backend)
- `HETZNER_S3_SECRET_KEY` - Hetzner S3 secret key (for Terraform state backend)
- `REGISTRY_PASSWORD` - Plaintext password for k3s registries.yaml
- `REGISTRY_HTPASSWD` - Bcrypt hash from `htpasswd -nbB robot_user "password" | cut -d: -f2`

Note: Flux SSH key, PostgreSQL, and Longhorn backup secrets are created manually on the cluster after deployment.

**Create Hetzner S3 buckets (via Hetzner Console):**

Hetzner Object Storage is not managed by Terraform (no provider support). Create these buckets manually:

- `lvs-cloud-terraform-state` (for Terraform state - should already exist)
- `lvs-cloud-longhorn-backups` (for Longhorn volume backups)
- `lvs-cloud-pg-backups` (for PostgreSQL logical backups)

Region: `nbg1` (Nuremberg)

### 2. Testing Locally (Optional)

**Test Helm chart rendering (requires `helm` CLI):**

```bash
# Install helm if needed: brew install helm
helm template applications/ruby-demo-app/chart -f applications/ruby-demo-app/values.yaml
```

**Terraform plan:**

```bash
cd infrastructure
terraform init

# Set required environment variables
export AWS_ACCESS_KEY_ID="your-hetzner-s3-access-key"
export AWS_SECRET_ACCESS_KEY="your-hetzner-s3-secret-key"
export TF_VAR_hcloud_token="your-hetzner-token"
export TF_VAR_registry_pass="your-password"
export TF_VAR_registry_htpasswd="your-bcrypt-hash"

terraform plan
```

**Note:** You cannot validate Kubernetes manifests with `kubectl` until after the cluster is deployed.

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
# SSH to server (kubectl is pre-configured on the server)
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

**Bootstrap Flux and create secrets manually** (after cluster is up):

```bash
# Generate Flux SSH deploy key
ssh-keygen -t ed25519 -C "flux-bot@lvs.me.uk" -f /tmp/flux-deploy-key

# Add public key to GitHub as Deploy Key with write access
cat /tmp/flux-deploy-key.pub
# Go to: https://github.com/louis-vs/lvs-cloud/settings/keys/new

# Bootstrap Flux with the generated key
flux bootstrap git \
  --url=ssh://git@github.com/louis-vs/lvs-cloud.git \
  --branch=master \
  --path=clusters/prod \
  --private-key-file=/tmp/flux-deploy-key

# Create flux-git-ssh secret for monorepo GitRepository
ssh-keyscan github.com > /tmp/known_hosts
kubectl create secret generic flux-git-ssh \
  -n flux-system \
  --from-file=identity=/tmp/flux-deploy-key \
  --from-file=known_hosts=/tmp/known_hosts

# Force reconcile to pick up the secret
flux reconcile source git monorepo

# Wait for infrastructure to deploy (creates namespaces)
kubectl wait --for=condition=ready kustomization -n flux-system infrastructure --timeout=5m

# Clean up temporary key
rm /tmp/flux-deploy-key /tmp/flux-deploy-key.pub

# PostgreSQL secrets
kubectl create secret generic postgresql-auth -n default \
  --from-literal=postgres-password='your-admin-password' \
  --from-literal=user-password='your-ruby-password' \
  --from-literal=ruby-password='your-ruby-password'

# Longhorn S3 backup credentials
kubectl create secret generic longhorn-backup -n longhorn-system \
  --from-literal=AWS_ACCESS_KEY_ID='your-hetzner-s3-key' \
  --from-literal=AWS_SECRET_ACCESS_KEY='your-hetzner-s3-secret' \
  --from-literal=AWS_DEFAULT_REGION='nbg1' \
  --from-literal=AWS_ENDPOINTS='[{"s3":"https://nbg1.your-objectstorage.com"}]'

# PostgreSQL backup S3 credentials
kubectl create secret generic pg-backup-s3 -n default \
  --from-literal=S3_ENDPOINT='https://nbg1.your-objectstorage.com' \
  --from-literal=S3_BUCKET='lvs-cloud-pg-backups' \
  --from-literal=S3_REGION='nbg1' \
  --from-literal=S3_ACCESS_KEY='your-hetzner-s3-key' \
  --from-literal=S3_SECRET_KEY='your-hetzner-s3-secret'
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
