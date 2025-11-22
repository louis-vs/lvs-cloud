# Secrets

SOPS-encrypted secrets for platform services.

## Service

- **Secret manifests**: Encrypted Kubernetes secrets
- **Namespace**: platform
- **Encryption**: SOPS with age

## Encrypted Secrets

All secrets are SOPS-encrypted with age recipient: `age18q37g469gr690ywae38e56ckk463u9kpynhqe8tpcn9m00vg85xqzs9epa`

- `authelia`: Multi-key secret (OIDC keys, session key, DB passwords, JWT key)
- `grafana-admin`: Admin username and password
- `grafana-oauth`: OAuth client secret for Authelia
- `postgresql-backup-auth`: Backup user password
- `registry-auth`: Registry htpasswd
- `registry-credentials`: Registry basic auth for Flux (username + password)
- `s3-backup`: S3 credentials for backup jobs

## Configuration

- Secrets are decrypted by Flux during deployment
- Source secrets are never committed unencrypted
- Age private key stored securely outside Git
