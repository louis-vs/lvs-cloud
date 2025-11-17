# Backup Strategy

## Overview

LVS Cloud uses a **two-tier backup strategy** combining application-level and block-level backups:

### Tier 1: Application-Level Backups (Custom CronJobs)

Logical exports that can be restored to different systems:

1. **etcd snapshots** - Daily cluster state backups (2 AM)
2. **PostgreSQL dumps** - Daily database exports (1 AM)

### Tier 2: Block-Level Backups (Longhorn Built-in)

Volume-level snapshots for exact state recovery:

1. **Grafana volume** - Weekly backups (Sunday 3 AM)

**Why both?**

- **Application backups** provide portable, version-independent exports
- **Longhorn backups** provide fast disaster recovery for critical stateful services
- This avoids duplication while ensuring comprehensive protection

## Current State

### Active Backup Jobs

| CronJob | Namespace | Schedule | Target | Secret | Status |
|---------|-----------|----------|--------|--------|--------|
| `etcd-backup-s3` | `kube-system` | Daily 2 AM | etcd cluster state | `s3-backup` | ✅ **Working** |
| `pgdump-s3` | `platform` | Daily 1 AM | All PostgreSQL databases | `s3-backup` | ✅ **Working** |
| `pgdump-s3-cleanup` | `platform` | Daily 4 AM | Delete backups >7 days | `s3-backup` | ✅ **Working** |
| `s3-metrics-collector` | `platform` | Every 6 hours | Collect S3 bucket metrics | `s3-backup` | ⚠️ **Optional** |
| `weekly-bak` | `longhorn-system` | Weekly Sunday 3 AM | Grafana volume | `longhorn-backup` | ✅ **Working** |

### Backup Secrets

Two S3 secrets provide credentials for all backup operations:

1. **`s3-backup`** (platform + kube-system namespaces) ✅
   - Keys: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINTS`, `AWS_DEFAULT_REGION`
   - Used by: PostgreSQL dumps, etcd snapshots, S3 metrics collector
   - Created during bootstrap from Hetzner S3 credentials

2. **`longhorn-backup`** (longhorn-system namespace) ✅
   - Keys: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS`
   - Used by: Longhorn BackupTarget for volume snapshots
   - Created during bootstrap (same S3 credentials as above)

### S3 Buckets

According to `SECRETS.md`, four S3 buckets exist:

| Bucket | Region | Purpose | Used By | Documented In |
|--------|--------|---------|---------|---------------|
| `lvs-cloud-terraform-state` | nbg1 | Terraform state | Terraform | SECRETS.md:69 |
| `lvs-cloud-longhorn-backups` | nbg1 | Longhorn volume backups | Longhorn recurring job | SECRETS.md:70 |
| `lvs-cloud-pg-backups` | nbg1 | PostgreSQL dumps | `pgdump-s3` cronjob | SECRETS.md:71 |
| `lvs-cloud-etcd-backups` | nbg1 | etcd snapshots | `etcd-backup-s3` cronjob | SECRETS.md:72 |

**Note:** Cannot verify bucket contents as S3 metrics collector is failing due to missing secret.

### Longhorn Volume Backups

The `weekly-bak` RecurringJob targets volumes in the "default" group:

**Backed up volumes:**

- `pvc-9c87da07-8e2f-4077-9f93-ca61b309caef` - 1GB - Grafana (`kube-prometheus-stack-grafana`)
  - Labeled with `recurring-job-group.longhorn.io/default: enabled`
  - Contains custom dashboards and Grafana configuration

**Excluded volumes (not backed up):**

- `pvc-17f62668-e0b2-4ac2-9153-fba526019b14` - 5GB - PostgreSQL (backed up via `pgdump-s3`)
- `pvc-24acca72-b75b-4cd8-8e24-22f75f313ed6` - 1GB - Alertmanager (ephemeral state)
- `pvc-311e1d98-a556-41b5-b02d-225f584338ea` - 16GB - Registry (rebuilds from source)
- `pvc-37271e38-2ebd-46a0-9a5f-577b07301cff` - 3GB - Loki (logs, not critical)
- `pvc-991d741d-bd44-49f7-bf60-b4a530c3187c` - 8GB - Prometheus (metrics, not critical)

## How Backup Jobs Work

### etcd Backup (`etcd-backup-s3`)

**Purpose:** Protect cluster state including all Kubernetes resources and secrets.

**Process:**

1. Init container creates etcd snapshot from k3s embedded etcd
2. Verifies snapshot integrity
3. Compresses with gzip
4. Upload container sends to S3 bucket organized by year/month
5. Runs on control plane node with privileged access to etcd data

**Retention:** Managed manually (no automated cleanup)

**Files:** `platform/etcd-backup/cronjob-etcd.yaml`

### PostgreSQL Backup (`pgdump-s3`)

**Purpose:** Protect all application databases (currently: Grafana, Authelia, future apps).

**Process:**

1. Init container runs `pg_dumpall` to dump all databases
2. Compresses with gzip (level 9)
3. Upload container sends to S3 bucket organized by year/month
4. Separate cleanup job (`pgdump-s3-cleanup`) deletes files older than 7 days

**Retention:** 7 days (automatic cleanup)

**Files:**

- `platform/postgresql-new/cronjob-pgdump.yaml`
- `platform/postgresql-new/cronjob-s3-cleanup.yaml`

### Longhorn Volume Backup (`weekly-bak`)

**Purpose:** Protect persistent volume data at the block level.

**Process:**

1. Longhorn RecurringJob controller scans for volumes matching group selector
2. For each matched volume, creates incremental snapshot
3. Uploads snapshot to S3 BackupTarget
4. Retains only the latest backup (retain: 1)

**Retention:** 1 backup (latest only)

**Files:** `platform/storage-config/recurring-jobs.yaml`

**Current Status:** Not backing up any volumes (no volumes in "default" group).

## Backup Configuration Summary

### What Gets Backed Up

**Application-level (portable backups):**

- PostgreSQL databases → S3 daily dumps (7 day retention)
- etcd cluster state → S3 daily snapshots (manual retention)

**Block-level (fast disaster recovery):**

- Grafana volume → Longhorn weekly snapshots (1 backup retained)

### What Doesn't Get Backed Up

Intentionally excluded to save costs and complexity:

- **Registry** (16GB) - Images rebuild from source via CI/CD
- **Prometheus** (8GB) - Metrics data, not critical for recovery
- **Loki** (3GB) - Logs data, not critical for recovery
- **Alertmanager** (1GB) - Ephemeral alert state
- **PostgreSQL volume** - Redundant (logical dumps via `pgdump-s3` are sufficient)

### Why This Strategy?

1. **Application backups** (PostgreSQL, etcd) provide version-independent, portable exports
2. **Longhorn backups** (Grafana) provide fast recovery for custom configurations
3. **No duplication** - PostgreSQL uses logical dumps, not volume backups
4. **Cost-effective** - Only backs up what can't be rebuilt (19GB total vs 41GB all volumes)
