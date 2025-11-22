# Longhorn Storage Configuration

Recurring job configurations for Longhorn backups.

## Service

- **RecurringJob resources**: Automated backup scheduling
- **Namespace**: longhorn-system

## Secrets

None

## Configuration

- `weekly-bak`: Runs weekly on Sundays at 3 AM UTC
- Retention: 1 backup
- Target: S3 backup store (configured in storage-install)
- Type: Backup (full volume backup)
