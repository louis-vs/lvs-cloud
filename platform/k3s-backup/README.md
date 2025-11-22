# k3s Backup

Daily backup of k3s SQLite database to S3.

## Service

- **CronJob**: Backs up k3s cluster state
- **Schedule**: Daily at 3 AM UTC
- **Namespace**: kube-system

## Secrets

- `s3-backup` (SOPS-encrypted):
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY
  - AWS_ENDPOINTS
  - AWS_DEFAULT_REGION

## Configuration

- Backs up /var/lib/rancher/k3s/server/db/state.db
- Backs up /var/lib/rancher/k3s/server/token
- Uploads to Hetzner S3 bucket: lvs-cloud-k3s-backup
- Organized by year/month folders
