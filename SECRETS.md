# Secrets Management

Complete inventory of all secrets used in LVS Cloud infrastructure.

## Secret Storage Strategy

**Primary:** Kubernetes secrets created imperatively during bootstrap
**Backup:** Secrets persist in k3s SQLite datastore on block storage (`/srv/data/k3s/server/db/state.db`)
**Recovery:** Daily k3s SQLite backups to S3

All secrets are created by `infrastructure/bootstrap/bootstrap.sh` during fresh cluster bootstrap. After initial creation, secrets persist across server recreation via persistent k3s SQLite datastore.

### PostgreSQL Admin Password Security

**IMPORTANT:** The PostgreSQL admin (postgres user) password is **NOT stored in the cluster** for security reasons:

- Admin password set only during initial bootstrap (stored in your local password manager)
- Database backups use dedicated `pgbackup` user with REPLICATION privileges
- Application users (ruby_demo_user, authelia) have passwords in their respective secrets
- If you lose the admin password, you can reset it via direct pod access or during disaster recovery

## Kubernetes Secrets Inventory

### Created During Bootstrap

These secrets are created automatically by the bootstrap script:

| Secret Name | Namespace | Keys | Purpose | Created By |
|-------------|-----------|------|---------|------------|
| `flux-git-ssh` | `flux-system` | `identity`, `known_hosts` | Flux Git authentication (SSH deploy key for lvs-cloud repo) | bootstrap.sh:186-195 |
| `postgresql-auth` | `platform` | `user-password`, `ruby-password` | PostgreSQL application user passwords (NOT admin password) | bootstrap.sh:196-204 |
| `postgresql-backup-auth` | `platform` | `backup-password` | PostgreSQL backup user password (for pgbackup user with REPLICATION privileges) | Manual during bootstrap |
| `registry-credentials` | `flux-system` | Docker config | Flux Image Automation registry scanning credentials | bootstrap.sh:206-215 |
| `longhorn-backup` | `longhorn-system` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS` | Longhorn S3 backups to Hetzner Object Storage | bootstrap.sh:230-239 |
| `s3-backup` | `platform` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS` | S3 credentials for PostgreSQL dumps and metrics | bootstrap.sh:241-251 |
| `s3-backup` | `kube-system` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS` | S3 credentials for k3s SQLite backups | bootstrap.sh:253-263 |
| `grafana-admin` | `platform` | `admin-user`, `admin-password` | Grafana admin login credentials | bootstrap.sh:278-287 |
| `registry-auth` | `platform` | `htpasswd` | Docker registry htpasswd authentication | Deployed with docker-registry Helm chart |

### Created Manually (Authelia)

These secrets are created manually after platform deployment following `platform/authelia/BOOTSTRAP.md`:

| Secret Name | Namespace | Keys | Purpose | Documentation |
|-------------|-----------|------|---------|---------------|
| `authelia` | `platform` | `storage.encryption.key`, `storage.postgres.password.txt`, `session.encryption.key`, `session.redis.password.txt` (empty), `identity_providers.oidc.hmac.key`, `identity_providers.oidc.clients.grafana.secret.txt`, `identity_validation.reset_password.jwt.hmac.key`, `oidc.rsa.key` | Authelia SSO encryption keys, database password, and OIDC secrets | platform/authelia/BOOTSTRAP.md:45-69 |
| `grafana-oauth` | `platform` | `oauth-client-secret` | Grafana OIDC client secret (plaintext, must match hashed secret in authelia) | platform/authelia/BOOTSTRAP.md:67-68 |

### Created Manually (User Database)

| Secret Name | Namespace | Type | Purpose | Documentation |
|-------------|-----------|------|---------|---------------|
| `authelia-users` | `platform` | ConfigMap | User database with Argon2id password hashes | platform/authelia/BOOTSTRAP.md:78-97 |

### Application Secrets

Application-specific secrets created by HelmReleases:

| Secret Name | Namespace | Keys | Purpose | Created By |
|-------------|-----------|------|---------|------------|
| `ruby-app-postgresql` | `applications` | `ruby-password` | Ruby demo app database password (references postgresql-auth) | Ruby demo app HelmRelease |

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

## Bootstrap Process

### Fresh Cluster Bootstrap

Run `infrastructure/bootstrap/bootstrap.sh` which will:

1. **Prompt for credentials:**
   - PostgreSQL admin password
   - PostgreSQL ruby_demo_user password
   - Grafana admin password
   - Registry password (from GitHub secret)
   - S3 access key
   - S3 secret key

2. **Bootstrap Flux:**
   - Generate SSH deploy key (if needed)
   - Install Flux controllers
   - Configure GitOps repository

3. **Create Kubernetes secrets:**
   - flux-git-ssh
   - postgresql-auth
   - registry-credentials
   - longhorn-backup (waits for namespace)
   - pg-backup-s3
   - etcd-backup-s3
   - grafana-admin (waits for namespace)

4. **Deploy platform:**
   - Flux reconciles git repository
   - Platform services deploy automatically

**Total time:** 30-45 minutes

### Server Recreation (k3s datastore persists)

When Terraform recreates the server but block storage is intact:

1. SSH to server and verify k3s SQLite datastore persisted:

   ```bash
   kubectl get kustomization -n flux-system
   ```

2. If kustomizations exist, all secrets persist automatically
3. No credential input required
4. Services restart and reattach to persistent volumes

**Total time:** 5-10 minutes

## Secret Recovery Scenarios

### Scenario 1: Lost Local Credentials

**Problem:** Developer machine lost, need credentials to bootstrap new cluster

**Recovery:**

1. Retrieve credentials from password manager
2. Run bootstrap script with stored credentials
3. All secrets recreated identically

**Prevention:** Store all bootstrap credentials in password manager (1Password/Bitwarden)

### Scenario 2: Block Storage Loss

**Problem:** Hetzner block storage deleted, k3s SQLite datastore lost, all secrets gone

**Recovery:**

1. Run `infrastructure/bootstrap/bootstrap.sh` (fresh cluster bootstrap)
2. Enter all credentials from password manager
3. Restore k3s SQLite database from S3 backup (see below)
4. Manually recreate Authelia secrets following `platform/authelia/BOOTSTRAP.md`

**Restore k3s SQLite from S3:**

```bash
# Download latest k3s SQLite backup
mc alias set hetzner https://nbg1.your-objectstorage.com <ACCESS_KEY> <SECRET_KEY>
mc ls hetzner/lvs-cloud-k3s-backups/
mc cp hetzner/lvs-cloud-k3s-backups/2025/11/k3s-sqlite-20251116T030000Z.db.gz /tmp/

# Extract backup
gunzip /tmp/k3s-sqlite-20251116T030000Z.db.gz

# Restore k3s SQLite database (requires cluster downtime)
sudo systemctl stop k3s
sudo cp /tmp/k3s-sqlite-20251116T030000Z.db /srv/data/k3s/server/db/state.db
sudo chown root:root /srv/data/k3s/server/db/state.db
sudo systemctl start k3s
```

### Scenario 3: Compromised Secret

**Problem:** Secret leaked or suspected compromise

**Rotation procedure:**

**PostgreSQL passwords:**

```bash
# Update secret
kubectl patch secret postgresql-auth -n platform --type='json' \
  -p='[{"op": "replace", "path": "/data/postgres-password", "value": "'$(echo -n 'new-password' | base64)'"}]'

# Restart PostgreSQL
kubectl rollout restart statefulset postgresql -n platform

# Update password in password manager
```

**Registry password:**

```bash
# Update GitHub secret REGISTRY_PASSWORD
# Update cloud-init.yml variable
# Run terraform apply to update server
# Restart k3s: ssh ubuntu@server "sudo systemctl restart k3s"
```

**S3 credentials:**

```bash
# Generate new S3 access key in Hetzner Console
# Update secrets: longhorn-backup, s3-backup (both namespaces)
# Restart affected pods
kubectl delete pod -n longhorn-system -l app=longhorn-manager
kubectl delete secret s3-backup -n platform && kubectl delete secret s3-backup -n kube-system
# Recreate secrets using new credentials (see bootstrap.sh)
```

**Grafana admin password:**

```bash
# Update secret
kubectl patch secret grafana-admin -n platform --type='json' \
  -p='[{"op": "replace", "path": "/data/admin-password", "value": "'$(echo -n 'new-password' | base64)'"}]'

# Restart Grafana
kubectl rollout restart deployment -n platform kube-prometheus-stack-grafana
```

## Secret Validation

After bootstrap or disaster recovery, verify all required secrets exist:

```bash
# Flux secrets
kubectl get secret flux-git-ssh -n flux-system
kubectl get secret registry-credentials -n flux-system

# Application secrets
kubectl get secret postgresql-auth -n platform
kubectl get secret grafana-admin -n platform

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

2. **Monitor secret access**
   - Check Kubernetes audit logs for secret access
   - Alert on unexpected secret reads

3. **Backup secrets off-cluster**
   - k3s SQLite backups to S3 (daily)
   - Store credentials in password manager
   - Document all secret values in secure notes

## Reference Files

| File | Purpose |
|------|---------|
| `infrastructure/bootstrap/bootstrap.sh` | Creates all bootstrap-time secrets |
| `platform/authelia/BOOTSTRAP.md` | Authelia secret creation instructions |
| `DISASTER_RECOVERY.md` | etcd restore and secret recovery procedures |
| `.gitignore` | Excludes credential files from git |
| `.pre-commit-config.yaml` | Scans for accidentally committed secrets |

## Backup Schedule

| What | Frequency | Retention | S3 Bucket |
|------|-----------|-----------|-----------|
| k3s SQLite backups | Daily 3 AM | Manual retention | lvs-cloud-k3s-backups |
| PostgreSQL dumps | Daily 1 AM | 30 days | lvs-cloud-pg-backups |
| Longhorn volumes | Weekly Sunday 3 AM | 4 weeks | lvs-cloud-longhorn-backups |

## Future Improvements

**Declarative secrets management options:**

1. **SOPS with age encryption** (recommended)
   - Store encrypted secrets in git
   - Flux decrypts at apply-time
   - No manual bootstrap input required

2. **External Secrets Operator**
   - Sync secrets from external sources (1Password, Vault)
   - Automatic rotation support
   - More complex setup

3. **credstash-like approach**
   - S3-backed secret storage
   - Client-side decryption
   - No cluster dependencies

See end of this document for detailed comparison.
