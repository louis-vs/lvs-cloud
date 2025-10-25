# Bootstrap Guide: Fresh Cluster Deployment

This guide walks through deploying the entire platform from scratch after Terraform provisions the infrastructure.

## Prerequisites

Before starting, ensure you have:

1. **GitHub Secrets configured** (required for Terraform workflow):
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

3. **Flux CLI installed locally**:

   ```bash
   brew install fluxcd/tap/flux
   ```

## Deployment Steps

### 1. Trigger Infrastructure Deployment

```bash
# Push to master branch to trigger Terraform workflow
git push origin master

# Wait for workflow to create GitHub issue
# Reply "LGTM" to the approval issue

# Wait ~5 minutes for server provisioning
# Verify DNS resolves to new server
dig +short app.lvs.me.uk
```

### 2. SSH to Server

```bash
ssh ubuntu@$(dig +short app.lvs.me.uk)

# Verify k3s is running
kubectl get nodes
# Should show: STATUS Ready
```

### 3. Bootstrap Flux

```bash
# Generate Flux SSH deploy key
ssh-keygen -t ed25519 -C "flux-bot@lvs.me.uk" -f /tmp/flux-deploy-key -N ""

# Display public key
cat /tmp/flux-deploy-key.pub

# Add to GitHub as Deploy Key with WRITE access:
# https://github.com/louis-vs/lvs-cloud/settings/keys/new
# Title: "Flux Deploy Key"
# Key: <paste public key>
# [x] Allow write access

# Bootstrap Flux (installs Flux and connects to Git)
flux bootstrap git \
  --url=ssh://git@github.com/louis-vs/lvs-cloud.git \
  --branch=master \
  --path=clusters/prod \
  --private-key-file=/tmp/flux-deploy-key

# Wait for bootstrap to complete (~2 minutes)
# You should see: "✔ Flux bootstrap completed"
```

### 4. Create Kubernetes Secrets

Flux needs these secrets to deploy platform services:

```bash
# Get GitHub SSH host keys
ssh-keyscan github.com > /tmp/known_hosts

# Create Flux Git authentication secret
kubectl create secret generic flux-git-ssh \
  -n flux-system \
  --from-file=identity=/tmp/flux-deploy-key \
  --from-file=known_hosts=/tmp/known_hosts

# Create PostgreSQL authentication secret
# Replace passwords with secure values
kubectl create secret generic postgresql-auth -n default \
  --from-literal=postgres-password='CHANGE_ME_ADMIN_PASSWORD' \
  --from-literal=user-password='CHANGE_ME_USER_PASSWORD' \
  --from-literal=ruby-password='CHANGE_ME_USER_PASSWORD'

# Create Longhorn S3 backup credentials
# Replace with your actual Hetzner S3 credentials
kubectl create secret generic longhorn-backup -n longhorn-system \
  --from-literal=AWS_ACCESS_KEY_ID='YOUR_HETZNER_S3_ACCESS_KEY' \
  --from-literal=AWS_SECRET_ACCESS_KEY='YOUR_HETZNER_S3_SECRET_KEY' \
  --from-literal=AWS_DEFAULT_REGION='nbg1' \
  --from-literal=AWS_ENDPOINTS='[{"s3":"https://nbg1.your-objectstorage.com"}]'

# Create PostgreSQL S3 backup credentials
kubectl create secret generic pg-backup-s3 -n default \
  --from-literal=S3_ENDPOINT='https://nbg1.your-objectstorage.com' \
  --from-literal=S3_BUCKET='lvs-cloud-pg-backups' \
  --from-literal=S3_REGION='nbg1' \
  --from-literal=S3_ACCESS_KEY='YOUR_HETZNER_S3_ACCESS_KEY' \
  --from-literal=S3_SECRET_KEY='YOUR_HETZNER_S3_SECRET_KEY'

# Clean up temporary files
rm /tmp/flux-deploy-key /tmp/flux-deploy-key.pub /tmp/known_hosts
```

### 5. Monitor Deployment

Flux will now automatically deploy all platform services in the correct order:

```bash
# Watch Flux reconciliation progress
watch flux get kustomizations

# Expected order (with approximate timing):
# 1. flux-system (immediate) - Flux itself
# 2. helmrepositories (30s) - Helm chart repositories
# 3. storage-install (10-15m) - Longhorn storage system
# 4. cert-manager-install (5-10m) - TLS certificate manager
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

### 6. Verify Deployment

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
```

## Deployment Timeline

Total time from Terraform provision to fully operational: **30-45 minutes**

- Terraform provision: 5 minutes
- Flux bootstrap: 2 minutes
- Platform deployment: 20-30 minutes
  - Longhorn: 10-15 minutes (largest component)
  - cert-manager: 5-10 minutes
  - PostgreSQL: 5-10 minutes
  - Apps: 5 minutes
- TLS certificate issuance: 2-5 minutes

## Dependency Graph

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

## Post-Deployment

### Building and Deploying Applications

```bash
# From your local machine
cd applications/ruby-demo-app

# Build and push image
docker build -t registry.lvs.me.uk/ruby-demo-app:1.0.1 .
echo "$REGISTRY_PASSWORD" | docker login registry.lvs.me.uk -u robot_user --password-stdin
docker push registry.lvs.me.uk/ruby-demo-app:1.0.1

# Update values.yaml with new image tag
# Flux will automatically deploy the new version
git add applications/ruby-demo-app/values.yaml
git commit -m "feat(ruby-demo-app): update to v1.0.1"
git push
```

### Accessing Services

- **Ruby Demo App**: <https://app.lvs.me.uk>
- **Registry**: <https://registry.lvs.me.uk> (basic auth: robot_user)
- **Longhorn UI**: `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80`

### Database Access

```bash
# From within the cluster
kubectl run psql --rm -it --image=postgres:16 -- \
  psql postgresql://ruby_demo_user:PASSWORD@postgresql:5432/ruby_demo

# From local machine (port forward)
kubectl port-forward svc/postgresql 5432:5432
psql postgresql://ruby_demo_user:PASSWORD@localhost:5432/ruby_demo
```

## Rollback

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

## Success Criteria

Deployment is complete when:

- [ ] All Flux kustomizations show `READY True`
- [ ] All pods are `Running` or `Completed`
- [ ] `curl https://app.lvs.me.uk` returns valid HTML
- [ ] TLS certificate is valid (browser shows lock icon)
- [ ] Longhorn storage class is available
- [ ] PostgreSQL is accepting connections

## Common Issues

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

## Next Steps

See:

- [DEPLOY.md](../DEPLOY.md) - Adding new applications
- [OPS.md](../OPS.md) - Operations and maintenance
- [README.md](../README.md) - Architecture overview
