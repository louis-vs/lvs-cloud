# Longhorn Storage System

Distributed block storage for Kubernetes persistent volumes.

## Service

- **Longhorn**: Cloud-native distributed storage
- **Namespace**: longhorn-system
- **Chart**: Longhorn Helm repository

## Secrets

- `longhorn-backup` (referenced): S3 credentials for backup target (managed by Longhorn)

## Configuration

- S3 backup target: s3://lvs-cloud-longhorn-backups@nbg1
- Single replica (1-node cluster)
- Data path: /srv/data/longhorn
- Provides ReadWriteOnce (RWO) persistent volumes
- Used by: PostgreSQL, Registry, Grafana, Prometheus
- Security patches for nginx UI deployment
