# PostgreSQL

Shared PostgreSQL database server for all applications.

## Service

- **PostgreSQL**: Multi-tenant database server
- **Namespace**: platform
- **Chart**: Bitnami PostgreSQL
- **Storage**: 5Gi Longhorn persistent volume with snapshots

## Secrets

- `postgresql-backup-auth` (SOPS-encrypted): Backup user password for pgbackup

## Configuration

- Admin password set during bootstrap (not stored in Git)
- Applications create their own databases and users
- Daily pg_dumpall to S3 at 1 AM UTC (includes schema and data)
- S3 cleanup CronJob removes backups older than 30 days
- Backup bucket: lvs-cloud-postgresql-backups
