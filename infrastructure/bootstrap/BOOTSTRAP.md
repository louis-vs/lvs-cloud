# Bootstrap Guide

This guide covers cluster setup after Terraform provisions infrastructure. With persistent etcd, most config survives server recreation.

## Understanding Bootstrap Scenarios

**Two distinct scenarios:**

1. **Fresh Cluster Bootstrap** - etcd is empty (first deploy or after data loss)
   - Full bootstrap required: install Flux, create all secrets, wait for platform deployment
   - Takes 30-45 minutes
   - Requires all credentials

2. **Server Recreation Verification** - etcd persists from previous deployment
   - Minimal steps: verify etcd intact, check Flux status, confirm secrets exist
   - Takes 2-5 minutes
   - No credential input needed

**How to tell which scenario you're in:**

```bash
# After Terraform provisions the server, SSH and check:
ssh ubuntu@$(dig +short app.lvs.me.uk)

# Check if Flux kustomizations exist in etcd
kubectl get kustomization -n flux-system

# If you see flux-system and other kustomizations → Server Recreation (skip to that section)
# If "No resources found" or namespace doesn't exist → Fresh Cluster Bootstrap
```

---

## Server Recreation Verification

**Use this when:** Terraform recreated the server but etcd persists (block storage intact).

With persistent etcd at `/srv/data/k3s`, all Kubernetes resources survive server recreation:

- Flux configuration and state
- All secrets (PostgreSQL passwords, registry credentials)
- HelmReleases and kustomizations
- Deployed applications

**Verification process:**

### 1. Check Server is Ready

```bash
# Verify k3s is running
ssh ubuntu@$(dig +short app.lvs.me.uk) kubectl get nodes
# Should show: STATUS Ready
```

### 2. Verify Flux Resources Persisted

```bash
# Setup kubectl (use connect-k8s.sh or manual SSH tunnel)
./scripts/connect-k8s.sh

# Check Flux kustomizations exist
kubectl get kustomization -n flux-system
# Should show: flux-system, helmrepositories, storage-install, etc.

# Check Flux is reconciling
flux get all
# All should show READY True (may take few minutes for pods to restart)
```

### 3. Verify Secrets Exist

```bash
# Check critical secrets (including SOPS decryption key)
kubectl get secret -n flux-system sops-age
kubectl get secret -n flux-system flux-git-ssh
kubectl get secret -n flux-system registry-credentials
kubectl get secret -n platform postgresql-auth
kubectl get secret -n longhorn-system longhorn-backup

# All should exist (output: "NAME ... AGE")

# Verify SOPS decryption is still configured in flux-system kustomization
kubectl get kustomization flux-system -n flux-system -o jsonpath='{.spec.decryption}'
# Should output: {"provider":"sops","secretRef":{"name":"sops-age"}}
```

**Note:** The `sops-age` secret and SOPS decryption configuration persist in etcd and do NOT need to be recreated during server recreation.

### 4. Monitor Service Recovery

```bash
# Watch pods restart and attach to persistent volumes
kubectl get pods -A -w

# Wait until all pods are Running (5-10 minutes)
# Longhorn will recognize existing volumes automatically
```

### 5. Verify Applications

```bash
# Check HelmReleases reconciled
flux get helmreleases -A

# Test application
curl https://app.lvs.me.uk
# Should return HTML

# Test registry
curl -u robot_user:PASSWORD https://registry.lvs.me.uk/v2/_catalog
# Should return existing images
```

**If verification fails:** You may have lost etcd data. Proceed to Fresh Cluster Bootstrap section instead.

---

## Fresh Cluster Bootstrap

**Use this when:** Deploying a brand new cluster or after etcd data loss.

**Quick Start:** Run `infrastructure/bootstrap/bootstrap.sh` after Terraform provisions the server. The script automates all steps below.

**Secret Management:** See [SECRETS.md](../../SECRETS.md) for complete secret inventory and management procedures.

### Prerequisites

Before starting, ensure you have:

1. **GitHub Secrets configured** (required for GitHub workflows):
   - `HCLOUD_TOKEN_RO` - Hetzner Cloud read-only API token
   - `HCLOUD_TOKEN_RW` - Hetzner Cloud read-write API token
   - `HETZNER_S3_ACCESS_KEY` - Hetzner S3 access key
   - `HETZNER_S3_SECRET_KEY` - Hetzner S3 secret key
   - `REGISTRY_PASSWORD` - Plaintext password for k3s registry authentication
   - `REGISTRY_HTPASSWD` - Bcrypt hash: `htpasswd -nbB robot_user "password" | cut -d: -f2`

2. **Hetzner S3 Buckets created** (via Hetzner Console):
   - `lvs-cloud-terraform-state` (Nuremberg region)
   - `lvs-cloud-longhorn-backups` (Nuremberg region)
   - `lvs-cloud-pg-backups` (Nuremberg region)
   - `lvs-cloud-etcd-backups` (Nuremberg region)

3. **Flux CLI installed locally**:

   ```bash
   brew install fluxcd/tap/flux
   ```

### Deployment Steps

#### 1. Trigger Infrastructure Deployment

```bash
# Push to master branch to trigger Terraform workflow
git push origin master

# Wait for workflow to create GitHub issue
# Reply "LGTM" to the approval issue

# Wait ~5 minutes for server provisioning
# Verify DNS resolves to new server
dig +short app.lvs.me.uk
```

#### 2. Verify Server is Ready

```bash
# Wait ~5 minutes for server provisioning, then verify
ssh ubuntu@$(dig +short app.lvs.me.uk) kubectl get nodes
# Should show: STATUS Ready

# If successful, exit back to your local machine
```

#### 3. Bootstrap Flux (FROM LOCAL MACHINE)

**IMPORTANT: Run these commands from your LOCAL machine, NOT on the server.**

```bash
# Generate Flux SSH deploy key (on your local machine)
ssh-keygen -t ed25519 -C "flux-bot@lvs.me.uk" -f /tmp/flux-deploy-key -N ""

# Display public key
cat /tmp/flux-deploy-key.pub

# Add to GitHub as Deploy Key with WRITE access:
# https://github.com/louis-vs/lvs-cloud/settings/keys/new
# Title: "Flux Deploy Key"
# Key: <paste public key>
# [x] Allow write access

# Bootstrap Flux (installs Flux on server, run from local machine)
# First, set up SSH tunnel for k3s API access (run in separate terminal)
# Leave this running for the entire bootstrap process
ssh -L 6443:127.0.0.1:6443 ubuntu@$(dig +short app.lvs.me.uk) -N

# In your main terminal, get the kubeconfig from the server
ssh ubuntu@$(dig +short app.lvs.me.uk) cat /etc/rancher/k3s/k3s.yaml > /tmp/k3s-kubeconfig.yaml

# Set kubectl context to use this config (points to localhost:6443 via tunnel)
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml

# Verify connection
kubectl get nodes

# Bootstrap Flux
flux bootstrap git \
  --url=ssh://git@github.com/louis-vs/lvs-cloud.git \
  --branch=master \
  --path=clusters/prod \
  --private-key-file=/tmp/flux-deploy-key

# Wait for bootstrap to complete (~2 minutes)
# You should see: "✔ Flux bootstrap completed"
```

#### 4. Configure SOPS Decryption (FROM LOCAL MACHINE)

**Continue using the same kubectl context and SSH tunnel from step 3.**

**IMPORTANT:** This step is ONLY required during fresh cluster bootstrap. The configuration persists in etcd, so server recreation does NOT require re-running these commands.

Configure age decryption for Flux to decrypt SOPS-encrypted secrets:

```bash
# Create the sops-age secret from your local age key
cat age.agekey | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin

# Verify secret was created
kubectl get secret sops-age -n flux-system

# Wait for Flux bootstrap to complete (flux-system kustomization should be READY)
flux get kustomizations flux-system

# Enable SOPS decryption in the flux-system Kustomization
# This patch is required because gotk-sync.yaml is managed by flux bootstrap
# and changes to it in git are overwritten. The patch modifies the cluster resource directly.
kubectl patch kustomization flux-system -n flux-system --type=merge \
  -p '{"spec":{"decryption":{"provider":"sops","secretRef":{"name":"sops-age"}}}}'

# Verify decryption is configured
kubectl get kustomization flux-system -n flux-system -o jsonpath='{.spec.decryption}' | jq
# Should output: {"provider":"sops","secretRef":{"name":"sops-age"}}
```

**Why patching is necessary:**

- The `clusters/prod/flux-system/gotk-sync.yaml` file in git includes decryption config
- However, `flux bootstrap` manages this file and overwrites it during bootstrap
- The kubectl patch directly modifies the Kustomization resource in the cluster
- Once patched, the config persists in etcd and survives server recreation

**Note:** All secrets in this repository are encrypted with SOPS and stored in git. The `sops-age` secret allows Flux to decrypt them automatically. See [SECRETS.md](../../SECRETS.md) for secret management procedures.

#### 5. Create Initial Kubernetes Secrets (FROM LOCAL MACHINE)

**Continue using the same kubectl context and SSH tunnel from step 3.**

**IMPORTANT:** Most secrets are now managed by SOPS and stored encrypted in git. The following secrets are bootstrap-only and are NOT in git:

```bash
# Get GitHub SSH host keys
ssh-keyscan github.com > /tmp/known_hosts

# Create Flux Git authentication secret
kubectl create secret generic flux-git-ssh \
  -n flux-system \
  --from-file=identity=/tmp/flux-deploy-key \
  --from-file=known_hosts=/tmp/known_hosts

# NOTE: Application database passwords are created per-application namespace
# See platform/authelia/BOOTSTRAP.md and applications/ruby-demo-app/README.md

# Create PostgreSQL backup user secret
# This user has REPLICATION privileges for pg_dumpall backups
kubectl create secret generic postgresql-backup-auth -n platform \
  --from-literal=backup-password='CHANGE_ME_BACKUP_PASSWORD'

# Create S3 backup credentials for platform services (PostgreSQL, metrics)
# NOTE: This is now created automatically by bootstrap.sh
kubectl create secret generic s3-backup -n platform \
  --from-literal=AWS_ACCESS_KEY_ID='YOUR_HETZNER_S3_ACCESS_KEY' \
  --from-literal=AWS_SECRET_ACCESS_KEY='YOUR_HETZNER_S3_SECRET_KEY' \
  --from-literal=AWS_ENDPOINTS='nbg1.your-objectstorage.com' \
  --from-literal=AWS_DEFAULT_REGION='nbg1'

# Create registry credentials for Flux Image Automation
# This allows Flux to scan the private registry for new image tags
kubectl create secret docker-registry registry-credentials \
  -n flux-system \
  --docker-server=registry.lvs.me.uk \
  --docker-username=robot_user \
  --docker-password='YOUR_REGISTRY_PASSWORD'
```

**Note:** The grafana-admin secret is created automatically by the bootstrap script after the monitoring namespace is available. You don't need to create it manually.

#### 6. Monitor Initial Deployment (FROM LOCAL MACHINE)

**Continue using the same kubectl context and SSH tunnel.**

Flux will now start deploying platform services. Monitor until Longhorn is ready:

```bash
# Watch Flux reconciliation progress
watch flux get kustomizations

# Wait for storage-install to show READY True
# This takes 10-15 minutes

# Expected initial order:
# 1. flux-system (immediate) - Flux itself
# 2. helmrepositories (30s) - Helm chart repositories
# 3. image-automation (1m) - Flux Image Automation resources
# 4. storage-install (10-15m) - Longhorn storage system
# 5. cert-manager-install (5-10m) - TLS certificate manager

# Wait until storage-install shows READY True, then proceed to step 7
```

#### 7. Create Longhorn Secret (FROM LOCAL MACHINE)

**After storage-install shows READY True**, create the Longhorn backup secret:

```bash
# Verify longhorn-system namespace exists
kubectl get namespace longhorn-system

# Create Longhorn S3 backup credentials
# Replace with your actual Hetzner S3 credentials
kubectl create secret generic longhorn-backup -n longhorn-system \
  --from-literal=AWS_ACCESS_KEY_ID='YOUR_HETZNER_S3_ACCESS_KEY' \
  --from-literal=AWS_SECRET_ACCESS_KEY='YOUR_HETZNER_S3_SECRET_KEY' \
  --from-literal=AWS_DEFAULT_REGION='nbg1' \
  --from-literal=AWS_ENDPOINTS='[{"s3":"https://nbg1.your-objectstorage.com"}]'

# Clean up temporary files
rm /tmp/flux-deploy-key /tmp/flux-deploy-key.pub /tmp/known_hosts /tmp/k3s-kubeconfig.yaml
```

#### 8. Monitor Full Deployment (FROM LOCAL MACHINE)

**Continue using the same kubectl context and SSH tunnel.**

Wait for all remaining services to deploy:

```bash
# Watch Flux reconciliation progress
watch flux get kustomizations

# Remaining deployment order:
# 5. storage-config (1m) - Longhorn recurring backup jobs
# 6. cert-manager-config (1m) - Let's Encrypt cluster issuers
# 7. registry (5m) - Docker registry
# 8. postgresql (5-10m) - PostgreSQL database
# 9. apps (5m) - Ruby demo application

# All should show: READY True
```

**Troubleshooting during deployment:**

```bash
# Check specific kustomization status
kubectl describe kustomization storage-install -n flux-system

# Check HelmRelease status
kubectl get helmreleases -A

# Check pod status
kubectl get pods -A

# Check logs for failing pods
kubectl logs -n <namespace> <pod-name>

# Force reconciliation if stuck
flux reconcile kustomization <name> --with-source
```

#### 9. Verify Deployment (FROM LOCAL MACHINE)

**Continue using the same kubectl context and SSH tunnel.**

Once all kustomizations show `READY True`:

```bash
# Check all services are running
kubectl get pods -A
# All pods should be Running or Completed

# Check Longhorn storage class
kubectl get storageclass
# Should show: longhorn (default)

# Check cert-manager certificates
kubectl get certificates -A
# Should show: ruby-demo-app-tls, registry-tls Ready

# Check ingresses
kubectl get ingresses -A
# Should show: app.lvs.me.uk, registry.lvs.me.uk

# Test registry
curl -u robot_user:PASSWORD https://registry.lvs.me.uk/v2/_catalog
# Should return: {"repositories":[]}

# Test application
curl https://app.lvs.me.uk
# Should return HTML response

# Verify Flux Image Automation
flux get images repository
flux get images policy
flux get image update
# Should show:
# - ruby-demo-app ImageRepository: READY True
# - ruby-demo-app ImagePolicy: latest tag detected
# - monorepo-auto ImageUpdateAutomation: READY True
```

### How Image Automation Works

Once deployed, the system automatically updates applications:

1. **Developer pushes code** → GitHub Actions builds image with tag `1.0.X`
2. **Flux ImageRepository** scans `registry.lvs.me.uk` every 1 minute
3. **Flux ImagePolicy** selects latest semver tag matching `>=1.0.0`
4. **Flux ImageUpdateAutomation** commits change to `helmrelease.yaml`:
   - Updates `spec.values.image.tag` from `1.0.5` → `1.0.6`
   - Commits with message "chore: update images"
   - Pushes to master branch
5. **Flux Kustomization** detects git change, applies updated HelmRelease
6. **Kubernetes** performs rolling update with health checks

**Key detail**: Image tag is in `helmrelease.yaml` `spec.values`, NOT in `values.yaml`. This ensures only changes to the specific app trigger reconciliation.

**Viewing automation in action**:

```bash
# Watch for new images
watch -n 5 'flux get images repository'

# See what Flux will update
flux get images policy ruby-demo-app

# Check ImageUpdateAutomation status
flux get image update monorepo-auto

# View commits from Flux
git log --oneline --author="flux-bot"
```

### Deployment Timeline

Total time from Terraform provision to fully operational: **30-45 minutes**

- Terraform provision: 5 minutes
- Flux bootstrap: 2 minutes
- Platform deployment: 20-30 minutes
  - Longhorn: 10-15 minutes (largest component)
  - cert-manager: 5-10 minutes
  - PostgreSQL: 5-10 minutes
  - Apps: 5 minutes
- TLS certificate issuance: 2-5 minutes

### Dependency Graph

```
flux-system (Flux controllers)
    ↓
helmrepositories (Bitnami, Jetstack, Longhorn Helm repos)
    ↓
    ├─→ storage-install (Longhorn HelmRelease)
    │       ↓
    │   storage-config (RecurringJobs - requires Longhorn CRDs)
    │       ↓
    │   ├─→ registry (Docker registry with PVC + TLS)
    │   └─→ postgresql (PostgreSQL with PVC)
    │
    └─→ cert-manager-install (cert-manager HelmRelease)
            ↓
        cert-manager-config (ClusterIssuers - requires cert-manager CRDs)
            ↓
        registry, apps (require TLS certificates)
```

### Post-Deployment

#### Authelia SSO Setup

After the platform is deployed, set up Authelia for SSO authentication:

```bash
# See detailed instructions in platform/authelia/BOOTSTRAP.md
# Summary:
# 1. Create PostgreSQL database for Authelia
# 2. Generate encryption keys and OIDC secrets
# 3. Create Kubernetes secrets
# 4. Create users ConfigMap
# 5. Add DNS record for auth.lvs.me.uk
# 6. Deploy via Flux
```

See [platform/authelia/BOOTSTRAP.md](../../platform/authelia/BOOTSTRAP.md) for complete setup instructions.

#### Building and Deploying Applications

```bash
# From your local machine
cd applications/ruby-demo-app

# Build and push image (GitHub Actions does this automatically)
# For manual testing:
docker build -t registry.lvs.me.uk/ruby-demo-app:1.0.1 .
echo "$REGISTRY_PASSWORD" | docker login registry.lvs.me.uk -u robot_user --password-stdin
docker push registry.lvs.me.uk/ruby-demo-app:1.0.1

# Image automation will detect the new tag and update helmrelease.yaml automatically
# No manual git commits needed - Flux handles it!

# To manually update (if automation is disabled):
# Edit applications/ruby-demo-app/helmrelease.yaml spec.values.image.tag
# git add applications/ruby-demo-app/helmrelease.yaml
# git commit -m "feat(ruby-demo-app): update to v1.0.1"
# git push
```

#### Accessing Services

- **Ruby Demo App**: <https://app.lvs.me.uk>
- **Registry**: <https://registry.lvs.me.uk> (basic auth: robot_user)
- **Longhorn UI**: `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80`

#### Database Access

```bash
# From within the cluster
kubectl run psql --rm -it --image=postgres:16 -- \
  psql postgresql://ruby_demo_user:PASSWORD@postgresql:5432/ruby_demo

# From local machine (port forward)
kubectl port-forward svc/postgresql 5432:5432
psql postgresql://ruby_demo_user:PASSWORD@localhost:5432/ruby_demo
```

---

## Persistence Model

### What Persists on Block Storage

All critical data is stored on the persistent block storage volume (`/dev/sdb` → `/srv/data`):

1. **k3s cluster state** (`/srv/data/k3s`)
   - etcd database containing all Kubernetes resources
   - Longhorn volume CRDs with volume metadata
   - Secrets, ConfigMaps, deployments, services

2. **Longhorn volume data** (`/srv/data/longhorn`)
   - Actual persistent volume contents (PostgreSQL data, registry images)
   - Volume snapshots and metadata
   - Disk configuration

3. **Application data** (stored in Longhorn volumes)
   - PostgreSQL databases (including users, schemas, data)
   - Docker registry images
   - Any other PVC-backed data

### How Server Recreation Works

When Terraform recreates the server:

1. **Ephemeral components** (recreated):
   - Server OS and packages
   - k3s binary and systemd service
   - Flux controllers
   - Application pods

2. **Persistent components** (automatically restored):
   - k3s reads cluster state from `/srv/data/k3s/server/db/`
   - Longhorn recognizes existing volumes in `/srv/data/longhorn/replicas/`
   - Kubernetes resources (deployments, services) recreated from etcd
   - Application pods automatically reattach to existing volumes

### Verification After Server Recreation

After recreating the server, verify volumes persisted correctly:

```bash
# Check k3s is using persistent data dir
ssh ubuntu@$(dig +short app.lvs.me.uk) "systemctl cat k3s | grep data-dir"
# Should show: --data-dir /srv/data/k3s

# Check Longhorn recognizes existing volumes
kubectl get volumes.longhorn.io -n longhorn-system
# Should show existing volumes with matching PVC names

# Check PVCs are bound to existing volumes
kubectl get pvc -A
# All should show: STATUS Bound

# Verify PostgreSQL data persisted
kubectl exec postgresql-0 -n platform -- psql -U postgres -c '\du'
# Should show ruby_demo_user and other existing users

# Check registry images persisted
curl -u robot_user:PASSWORD https://registry.lvs.me.uk/v2/_catalog
# Should show existing images, not empty
```

### PostgreSQL Database Setup (Fresh Cluster Only)

On **first bootstrap only**, create application databases and users. These persist via Longhorn PVC and survive server recreation:

```bash
# IMPORTANT: Admin password is stored ONLY locally (not in cluster)
# Retrieve it from your password manager
POSTGRES_PASSWORD='your-local-admin-password'
BACKUP_PASSWORD=$(kubectl get secret postgresql-backup-auth -n platform -o jsonpath='{.data.backup-password}' | base64 -d)

# Application users and databases are created per-application
# See applications/ruby-demo-app/README.md for ruby app database setup

# Create backup user with REPLICATION privileges for pg_dumpall
kubectl exec postgresql-0 -n platform -- env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -U postgres -c "CREATE USER pgbackup WITH REPLICATION PASSWORD '$BACKUP_PASSWORD';"

kubectl exec postgresql-0 -n platform -- env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -U postgres -c "GRANT pg_read_all_data TO pgbackup;"
```

**Note:** These users/databases persist forever in the PostgreSQL PVC. After server recreation, they're automatically available—no need to recreate.

**Authelia database:** Created separately during Authelia bootstrap (see [platform/authelia/BOOTSTRAP.md](../../platform/authelia/BOOTSTRAP.md)).

**Admin password security:** The postgres admin password is NOT stored in the cluster. Store it in your local password manager. If you lose it, you can reset it by accessing the pod directly or recreating the database during disaster recovery.

### Disaster Scenarios

**Total block storage failure:**

- Complete data loss—no automated recovery possible
- Restore from manual backups or accept data loss
- S3 backups (Longhorn, PostgreSQL) can provide off-site recovery

**Accidental server deletion:**

- Block storage survives (`lifecycle { prevent_destroy = true }` in Terraform)
- Recreate server via Terraform → automatic full state recovery
- Zero data loss, ~5 minute downtime

**k3s corruption:**

- etcd on persistent storage means corruption also persists
- Restore from etcd snapshots if configured
- Last resort: Manual PV/PVC rebinding (complex, not documented)

### Rollback

If deployment fails, you can roll back:

```bash
# On the server
flux suspend kustomization --all
kubectl delete namespace longhorn-system cert-manager
flux resume kustomization --all

# Locally
git revert HEAD
git push
```

### Success Criteria

Fresh cluster bootstrap is complete when:

- [ ] All Flux kustomizations show `READY True`
- [ ] All pods are `Running` or `Completed`
- [ ] `curl https://app.lvs.me.uk` returns valid HTML
- [ ] TLS certificate is valid (browser shows lock icon)
- [ ] Longhorn storage class is available
- [ ] PostgreSQL is accepting connections

---

## Troubleshooting

### Cloud-Init Issues

If the server boots but k3s is not running or SSH fails:

**Check cloud-init status:**

```bash
# SSH to server (if possible)
ssh ubuntu@$(dig +short app.lvs.me.uk)

# Check cloud-init completion status
cloud-init status --long
# Should show: status: done

# View cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Check custom completion log
cat /var/log/lvs-cloud-setup.log
```

**Common cloud-init issues:**

1. **Block storage not mounted:**

   ```bash
   # Check volume attachment
   lsblk
   # Should show /dev/sdb mounted at /srv/data

   # Check mount status
   mount | grep /srv/data

   # Check cloud-init mount logs
   sudo grep "Mount volume" /var/log/cloud-init-output.log -A 20

   # Manual mount if needed
   sudo mount /dev/sdb /srv/data
   ```

1. **k3s not running:**

   ```bash
   # Check k3s service status
   sudo systemctl status k3s

   # Check k3s logs
   sudo journalctl -u k3s --no-pager -n 100

   # Verify k3s using correct data directory
   sudo systemctl cat k3s | grep data-dir
   # Should show: --data-dir /srv/data/k3s

   # Check if k3s can access etcd
   sudo ls -la /srv/data/k3s/server/db/
   ```

1. **Re-run cloud-init after failure:**

   ```bash
   # Clean cloud-init state
   sudo cloud-init clean --logs

   # Re-run cloud-init
   sudo cloud-init init
   sudo cloud-init modules --mode=config
   sudo cloud-init modules --mode=final

   # Or: destroy and recreate server via Terraform
   ```

**Access server console if SSH fails:**

1. Go to Hetzner Cloud Console
2. Select server → Console
3. View boot logs and login directly
4. Check `/var/log/cloud-init-output.log` for errors

### Bootstrap Script Issues

**Script hangs or fails:**

```bash
# Check SSH tunnel is running
ps aux | grep "ssh.*6443"

# Test kubectl connection
kubectl get nodes

# If tunnel died, restart it in a separate terminal
ssh -L 6443:127.0.0.1:6443 ubuntu@$(dig +short app.lvs.me.uk) -N
```

**Namespace waits timing out:**

The script waits for `longhorn-system` and `monitoring` namespaces. If these timeout:

```bash
# Check Flux reconciliation
flux get kustomizations

# Check HelmRelease status
kubectl get helmrelease -A

# Force reconcile if stuck
flux reconcile kustomization storage-install --with-source
```

### HelmRelease stuck "InProgress"

```bash
# Check helm-controller logs
kubectl logs -n flux-system deploy/helm-controller --tail=100

# Check if HelmRepository is ready
kubectl get helmrepository -n flux-system
```

### Pods stuck "Pending"

```bash
# Check if PVC is bound
kubectl get pvc -A

# Check Longhorn status
kubectl get pods -n longhorn-system
```

### TLS certificate not issuing

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager --tail=100

# Check certificate status
kubectl describe certificate ruby-demo-app-tls -n default
```

---

## Next Steps

- [DEPLOY.md](../../DEPLOY.md) - Adding new applications
- [OPS.md](../../OPS.md) - Operations and maintenance
- [README.md](../../README.md) - Architecture overview
