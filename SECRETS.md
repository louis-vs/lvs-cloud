# Secrets Management

Complete inventory of all secrets used in LVS Cloud infrastructure.

## Secret Storage Strategy

**Primary:** SOPS-encrypted secrets stored in git (age encryption)
**Backup:** Secrets persist in k3s SQLite datastore on block storage (`/srv/data/k3s/server/db/state.db`)
**Recovery:** Restore from encrypted git files + age private key

All secrets are encrypted with [SOPS](https://github.com/getsops/sops) using [age](https://github.com/FiloSottile/age) encryption and stored in git. Flux automatically decrypts them during deployment using the `sops-age` secret in the `flux-system` namespace.

### How It Works

1. Secrets are stored encrypted in git in namespace-specific directories
2. Each secret file has plaintext metadata (name, namespace, labels) but encrypted data values
3. Flux decrypts secrets automatically using the age private key
4. Once deployed to the cluster, secrets persist in the k3s SQLite datastore on block storage

### SOPS Configuration

- **Encryption key**: age public key `age18q37g469gr690ywae38e56ckk463u9kpynhqe8tpcn9m00vg85xqzs9epa`
- **Configuration file**: `.sops.yaml` (defines encryption rules by directory)
- **Decryption secret**: `sops-age` in `flux-system` namespace (contains age private key)
- **Encrypted fields**: Only `data` and `stringData` fields in Secret resources

### PostgreSQL Admin Password Security

**IMPORTANT:** The PostgreSQL admin (postgres user) password is **NOT stored in the cluster** for security reasons:

- Admin password is set during initial bootstrap
- Database backups use dedicated `pgbackup` user with REPLICATION privileges
- If you lose the admin password, you can reset it via direct pod access or during disaster recovery

## Kubernetes Secrets Inventory

All secrets below are encrypted with SOPS and stored in git. They are automatically deployed by Flux.

### flux-system Namespace

Stored in: `clusters/prod/flux-system/secrets/`

| Secret Name | File | Keys | Purpose |
|-------------|------|------|---------|
| `sops-age` | N/A (bootstrap only) | `age.agekey` | Age private key for SOPS decryption (NOT in git) |
| `flux-git-ssh` | `flux-git-ssh.yaml` | `identity`, `known_hosts` | Flux Git authentication (SSH deploy key for lvs-cloud repo) |
| `registry-credentials` | `registry-credentials.yaml` | Docker config | Flux Image Automation registry scanning credentials |

### platform Namespace

Stored in: `platform/secrets/`

| Secret Name | File | Keys | Purpose |
|-------------|------|------|---------|
| `registry-auth` | `registry-auth.yaml` | `htpasswd` | Docker registry htpasswd authentication |
| `s3-backup` | `s3-backup.yaml` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS` | S3 credentials for PostgreSQL dumps and metrics |
| `grafana-admin` | `grafana-admin.yaml` | `admin-user`, `admin-password` | Grafana admin login credentials |
| `postgresql-backup-auth` | `postgresql-backup-auth.yaml` | `backup-password` | PostgreSQL backup user password (pgbackup user with REPLICATION) |
| `grafana-oauth` | `grafana-oauth.yaml` | `oauth-client-secret` | Grafana OIDC client secret (matches authelia) |
| `authelia` | `authelia.yaml` | `storage.encryption.key`, `storage.postgres.password.txt`, `session.encryption.key`, `session.redis.password.txt`, `identity_providers.oidc.hmac.key`, `identity_providers.oidc.clients.grafana.secret.txt`, `identity_validation.reset_password.jwt.hmac.key`, `oidc.rsa.key` | Authelia SSO encryption keys and OIDC secrets |

### applications Namespace

Stored in: `applications/secrets/`

| Secret Name | File | Keys | Purpose |
|-------------|------|------|---------|
| `ruby-app-postgresql` | `ruby-app-postgresql.yaml` | `password` | Ruby demo app database credentials |

### Infrastructure Secrets

Stored in: `infrastructure/secrets/`

| Secret Name | Namespace | File | Keys | Purpose |
|-------------|-----------|------|------|---------|
| `longhorn-backup` | `longhorn-system` | `longhorn-backup.yaml` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS` | Longhorn S3 backups to Hetzner |
| `s3-backup` | `kube-system` | `s3-backup.yaml` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS` | S3 credentials for k3s SQLite backups |

### Auto-Generated Secrets

These secrets are automatically created by Kubernetes controllers:

| Secret Name Pattern | Namespace | Type | Purpose | Created By |
|---------------------|-----------|------|---------|------------|
| `*-tls` | Various | `tls.crt`, `tls.key` | TLS certificates for ingresses | cert-manager |
| `sh.helm.release.v1.*` | Various | Helm release data | Helm release history and values | Helm |
| Webhook CA/TLS secrets | `cert-manager`, `longhorn-system` | Certificate data | Internal webhook certificates | cert-manager, Longhorn |
| Prometheus/Alertmanager secrets | `platform` | Configuration | Auto-generated monitoring configs | kube-prometheus-stack |

## GitHub Secrets

Stored in GitHub repository settings (`louis-vs/lvs-cloud`). Used by GitHub Actions workflows.

| Secret Name | Usage | Required For |
|-------------|-------|--------------|
| `HCLOUD_TOKEN_RO` | Read-only Hetzner Cloud API token | Terraform plan |
| `HCLOUD_TOKEN_RW` | Read-write Hetzner Cloud API token | Terraform apply |
| `HETZNER_S3_ACCESS_KEY` | Hetzner S3 access key | Terraform state backend |
| `HETZNER_S3_SECRET_KEY` | Hetzner S3 secret key | Terraform state backend |
| `REGISTRY_PASSWORD` | Registry plaintext password | k3s registry authentication (cloud-init) |
| `REGISTRY_HTPASSWD` | Registry bcrypt hash | Docker registry authentication |

**How to generate `REGISTRY_HTPASSWD`:**

```bash
htpasswd -nbB robot_user "your-password" | cut -d: -f2
```

## S3 Buckets

Created manually via Hetzner Cloud Console (not managed by Terraform).

| Bucket Name | Region | Purpose | Used By |
|-------------|--------|---------|---------|
| `lvs-cloud-terraform-state` | nbg1 | Terraform state storage | Terraform backend |
| `lvs-cloud-longhorn-backups` | nbg1 | Longhorn volume backups | Longhorn recurring job (weekly) |
| `lvs-cloud-pg-backups` | nbg1 | PostgreSQL database dumps | PostgreSQL cronjob (daily) |
| `lvs-cloud-k3s-backups` | nbg1 | k3s SQLite database snapshots | k3s backup cronjob (daily) |

**To create a new bucket:**

1. Hetzner Cloud Console → Storage → Object Storage → Create Bucket
2. Region: Nuremberg (nbg1)
3. Enable versioning for backup buckets

## Managing SOPS Secrets

### Prerequisites

Install required tools locally:

```bash
brew install age sops
```

See README.md for age key generation and setup.

### Adding a New Secret

Use the migration script to add new secrets:

```bash
# Create the secret in the cluster first (manually or via bootstrap)
kubectl create secret generic my-secret -n platform \
  --from-literal=key1=value1 \
  --from-literal=key2=value2

# Migrate to SOPS
./scripts/migrate-secret-to-sops.sh my-secret platform

# Review, commit, and push
git add platform/secrets/
git commit -m "feat(platform): add my-secret to SOPS"
git push

# Verify Flux deploys it
flux reconcile kustomization platform-secrets
kubectl get secret my-secret -n platform
```

### Modifying an Existing Secret

```bash
# Edit the encrypted file (SOPS decrypts automatically in your editor)
sops platform/secrets/grafana-admin.yaml

# Make your changes to the data fields, save and exit

# Commit and push
git add platform/secrets/grafana-admin.yaml
git commit -m "feat(platform): update grafana admin password"
git push

# Flux will decrypt and apply automatically
flux reconcile kustomization platform-secrets
```

### Viewing Encrypted Secrets

```bash
# View decrypted content without editing
sops -d platform/secrets/grafana-admin.yaml

# View specific key
sops -d --extract '["data"]["admin-password"]' platform/secrets/grafana-admin.yaml | base64 -d
```

### Rotating Secrets

Example: Rotating S3 credentials

```bash
# 1. Generate new credentials in Hetzner Console

# 2. Edit the encrypted secret
sops platform/secrets/s3-backup.yaml

# 3. Update the base64-encoded values
echo -n "new-access-key" | base64  # Copy this value
echo -n "new-secret-key" | base64  # Copy this value

# 4. Commit and push
git add platform/secrets/s3-backup.yaml
git commit -m "feat(platform): rotate S3 credentials"
git push

# 5. Flux applies, pods pick up new secret
flux reconcile kustomization platform-secrets

# 6. Restart affected pods if needed
kubectl rollout restart deployment -n platform postgresql-backup
```

### Bootstrap Process with SOPS

#### Fresh Cluster Bootstrap

1. Run `infrastructure/bootstrap/bootstrap.sh` following [BOOTSTRAP.md](infrastructure/bootstrap/BOOTSTRAP.md)
2. Create `sops-age` secret in flux-system namespace (contains age private key)
3. Patch flux-system Kustomization to enable SOPS decryption
4. Flux automatically decrypts and deploys all secrets from git

**Total time:** 30-45 minutes

#### Server Recreation (k3s datastore persists)

1. Verify k3s SQLite datastore persisted: `kubectl get kustomization -n flux-system`
2. All secrets (including `sops-age`) persist automatically in etcd
3. No secret recreation needed
4. Services restart and work immediately

**Total time:** 5-10 minutes

## Secret Recovery Scenarios

### Scenario 1: Lost Age Private Key

**Problem:** Developer machine lost, need age private key to decrypt secrets or bootstrap new cluster

**Recovery:**

1. Retrieve age private key backup from password manager
2. Copy to `~/.config/sops/age/keys.txt`
3. You can now decrypt secrets: `sops -d platform/secrets/grafana-admin.yaml`
4. For bootstrap: Create `sops-age` secret in cluster from backed-up key

**Prevention:** **CRITICAL** - Backup `age.agekey` to password manager immediately after generation

### Scenario 2: Block Storage Loss

**Problem:** Hetzner block storage deleted, k3s SQLite datastore lost, all secrets gone

**Recovery:**

With SOPS, recovery is straightforward:

1. Run fresh cluster bootstrap following [BOOTSTRAP.md](infrastructure/bootstrap/BOOTSTRAP.md)
2. Create `sops-age` secret from backed-up age private key
3. Patch flux-system Kustomization for SOPS decryption
4. Flux automatically deploys all secrets from git (encrypted files)
5. All services restore automatically - no manual secret recreation needed

**No credentials needed** - all secrets are in git (encrypted), just need the age private key.

### Scenario 3: Compromised Secret

**Problem:** Secret leaked or suspected compromise

**Rotation using SOPS:**

```bash
# 1. Edit the encrypted secret
sops platform/secrets/grafana-admin.yaml

# 2. Update the compromised values (SOPS decrypts automatically)
#    Change the data field values (base64 encoded)

# 3. Save and commit
git add platform/secrets/grafana-admin.yaml
git commit -m "feat(platform): rotate compromised secret"
git push

# 4. Flux applies automatically
flux reconcile kustomization platform-secrets

# 5. Restart affected pods if they don't auto-reload
kubectl rollout restart deployment -n platform kube-prometheus-stack-grafana
```

**For critical secrets like age private key:**

If the age private key is compromised, you need to:

1. Generate new age keypair: `age-keygen -o new-age.agekey`
2. Update `.sops.yaml` with new public key
3. Re-encrypt all secrets with new key: `sops updatekeys platform/secrets/*.yaml`
4. Update `sops-age` secret in cluster
5. Commit all changes
6. Backup new private key to password manager

## Secret Validation

After bootstrap or disaster recovery, verify all required secrets exist:

```bash
# Flux secrets
kubectl get secret flux-git-ssh -n flux-system
kubectl get secret registry-credentials -n flux-system

# Platform secrets
kubectl get secret grafana-admin -n platform
kubectl get secret postgresql-backup-auth -n platform

# Application secrets (per-namespace)
kubectl get secret ruby-app-postgresql -n applications

# Backup secrets
kubectl get secret longhorn-backup -n longhorn-system
kubectl get secret s3-backup -n platform
kubectl get secret s3-backup -n kube-system

# Authelia secrets (if deployed)
kubectl get secret authelia -n platform
kubectl get secret grafana-oauth -n platform
kubectl get configmap authelia-users -n platform
```

**Expected output:** All commands should return secret details (not "NotFound")

## Security Best Practices

### Local Development

1. **Never commit secrets to git**
   - `.gitignore` excludes `.env`, `.localvars`, `*-deploy-key`
   - Pre-commit hook scans for accidentally committed secrets

2. **Use password manager for storage**
   - Store all bootstrap credentials in 1Password/Bitwarden
   - Use secure notes for multi-line secrets (SSH keys, OIDC secrets)

3. **Encrypt local credential files**
   - If using `.localvars`, encrypt with GPG
   - Or retrieve secrets from password manager at runtime

### Production

1. **Rotate secrets periodically**
   - Set calendar reminder for yearly rotation
   - Rotate immediately if compromise suspected
   - Use `sops` to edit encrypted files in place

2. **Monitor secret access**
   - Check Kubernetes audit logs for secret access
   - Alert on unexpected secret reads

3. **Backup age private key**
   - **CRITICAL**: Store `age.agekey` in password manager
   - Without this key, you cannot decrypt any secrets
   - Treat it like a root password

4. **Backup encrypted secrets**
   - All secrets already in git (encrypted)
   - k3s SQLite backups to S3 provide additional recovery point
   - Age private key is the only credential needed for full recovery

## Reference Files

| File | Purpose |
|------|---------|
| `.sops.yaml` | SOPS encryption configuration for all secret directories |
| `scripts/migrate-secret-to-sops.sh` | Automates secret migration to SOPS encryption |
| `infrastructure/bootstrap/BOOTSTRAP.md` | Bootstrap guide including SOPS setup |
| `platform/authelia/BOOTSTRAP.md` | Authelia secret creation instructions |
| `DISASTER_RECOVERY.md` | etcd restore and secret recovery procedures |
| `.gitignore` | Excludes age private key and credential files from git |
| `.pre-commit-config.yaml` | Scans for accidentally committed secrets |

## Backup Schedule

| What | Frequency | Retention | S3 Bucket |
|------|-----------|-----------|-----------|
| k3s SQLite backups | Daily 3 AM | Manual retention | lvs-cloud-k3s-backups |
| PostgreSQL dumps | Daily 1 AM | 30 days | lvs-cloud-pg-backups |
| Longhorn volumes | Weekly Sunday 3 AM | 4 weeks | lvs-cloud-longhorn-backups |
