# Backup Strategy

## Overview

LVS Cloud uses a multi-layered backup approach to protect critical data:

1. **etcd backups** - Daily cluster state snapshots
2. **PostgreSQL backups** - Daily database dumps
3. **Longhorn volume backups** - Currently disabled (weekly recurring job exists but no volumes assigned)

## Current State

### Active Backup Jobs

| CronJob | Namespace | Schedule | Target | Secret | Status |
|---------|-----------|----------|--------|--------|--------|
| `etcd-backup-s3` | `kube-system` | Daily 2 AM | etcd cluster state | `etcd-backup-s3` | ❌ **FAILING - secret missing** |
| `pgdump-s3` | `platform` | Daily 1 AM | All PostgreSQL databases | `pg-backup-s3` | ❌ **FAILING - secret missing** |
| `pgdump-s3-cleanup` | `platform` | Daily 4 AM | Delete backups >7 days | `pg-backup-s3` | ❌ **FAILING - secret missing** |
| `s3-metrics-collector` | `platform` | Every 6 hours | Collect S3 bucket metrics | `s3-credentials` | ❌ **FAILING - secret missing** |
| `weekly-bak` | `longhorn-system` | Weekly Sunday 3 AM | Longhorn volumes in "default" group | `longhorn-backup` | ⚠️ **Not backing up any volumes** |

### Missing Secrets

Three critical secrets referenced in backup jobs **do not exist**:

1. **`pg-backup-s3`** (platform namespace)
   - Required by: `pgdump-s3`, `pgdump-s3-cleanup`
   - Keys needed: `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`
   - Referenced in: `platform/postgresql-new/cronjob-pgdump.yaml`, `platform/postgresql-new/cronjob-s3-cleanup.yaml`

2. **`etcd-backup-s3`** (kube-system namespace)
   - Required by: `etcd-backup-s3`
   - Keys needed: `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`
   - Referenced in: `platform/etcd-backup/cronjob-etcd.yaml`

3. **`s3-credentials`** (platform namespace)
   - Required by: `s3-metrics-collector`
   - Keys needed: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINTS`
   - Referenced in: `platform/monitoring/s3-metrics-collector.yaml`

### Existing Secrets

Only **one** backup-related secret exists:

- **`longhorn-backup`** (longhorn-system namespace) ✅
  - Keys: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_ENDPOINTS`
  - Used by: Longhorn BackupTarget for S3 storage
  - Created during bootstrap (see `SECRETS.md:24`)

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

The `weekly-bak` RecurringJob targets volumes in the "default" group, but **no volumes are assigned to this group**:

**All volumes (6 total):**

- `pvc-17f62668-e0b2-4ac2-9153-fba526019b14` - 5GB - PostgreSQL data (`data-postgresql-0`)
- `pvc-24acca72-b75b-4cd8-8e24-22f75f313ed6` - 1GB - Alertmanager
- `pvc-311e1d98-a556-41b5-b02d-225f584338ea` - 16GB - Registry
- `pvc-37271e38-2ebd-46a0-9a5f-577b07301cff` - 3GB - Loki
- `pvc-991d741d-bd44-49f7-bf60-b4a530c3187c` - 8GB - Prometheus
- `pvc-9c87da07-8e2f-4077-9f93-ca61b309caef` - 1GB - Grafana

**None of these volumes have `recurringJobSelector` set.**

**Result:** The weekly Longhorn backup job executes successfully but backs up **zero volumes**.

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

## Critical Volumes Requiring Backup

Per the TODO item, only critical volumes should be backed up:

1. **PostgreSQL** (`pvc-17f62668-e0b2-4ac2-9153-fba526019b14`) - 5GB
   - Contains all application databases
   - Already protected by `pgdump-s3` daily dumps ✅
   - Longhorn backup would be redundant

2. **Authelia** - No dedicated volume found
   - Authelia stores user database in ConfigMap (`authelia-users`)
   - Sessions/state stored in PostgreSQL
   - No separate volume backup needed

3. **Grafana** (`pvc-9c87da07-8e2f-4077-9f93-ca61b309caef`) - 1GB
   - Contains dashboards and Grafana state
   - According to CLAUDE.md, dashboards should persist to block storage
   - **Should be backed up** ⚠️

## Volumes That Should NOT Be Backed Up

Per the TODO item, the registry should NOT be backed up:

- **Registry** (`pvc-311e1d98-a556-41b5-b02d-225f584338ea`) - 16GB ❌
  - Contains built container images
  - Can be rebuilt from source
  - Wastes S3 storage/egress costs
  - **Must not be included in backups**

Other non-critical volumes (can be rebuilt):

- **Prometheus** (8GB) - Metrics data, not critical for recovery
- **Loki** (3GB) - Logs data, not critical for recovery
- **Alertmanager** (1GB) - Alert state, not critical for recovery

## Recommended Backup Strategy

### Tier 1: Critical (Daily)

- **etcd snapshots** - Full cluster state
- **PostgreSQL dumps** - All application data

### Tier 2: Important (Weekly)

- **Grafana volume** - Custom dashboards

### Tier 3: Not Backed Up

- Registry, Prometheus, Loki, Alertmanager - Can be rebuilt

## Issues to Fix

1. **Create missing secrets:**
   - `pg-backup-s3` in platform namespace
   - `etcd-backup-s3` in kube-system namespace
   - `s3-credentials` in platform namespace (or remove the metrics collector)

2. **Update SECRETS.md:**
   - Document that `pg-backup-s3`, `etcd-backup-s3`, and `s3-credentials` should be created during bootstrap
   - Update `infrastructure/bootstrap/bootstrap.sh` accordingly

3. **Configure Grafana volume backup:**
   - Add `recurringJobSelector` to Grafana PVC or volume
   - OR create a new RecurringJob specifically for Grafana

4. **Verify registry is NOT being backed up:**
   - Ensure registry volume never gets assigned to a backup group
   - Document this explicitly to prevent future mistakes

5. **Clean up s3-metrics-collector:**
   - Either create the `s3-credentials` secret
   - OR remove the CronJob if metrics aren't critical

6. **Test backup restoration:**
   - Document and test etcd restore procedure
   - Document and test PostgreSQL restore procedure
   - Document and test Longhorn volume restore procedure

## Current Bucket Usage

Cannot determine current S3 bucket contents because:

- `s3-metrics-collector` is failing (missing secret)
- No direct access to S3 from this context

**Recommended:** Fix secrets and check if registry backups exist in `lvs-cloud-longhorn-backups` bucket. If so, delete them.
