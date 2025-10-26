# Disaster Recovery Guide

Comprehensive recovery procedures for LVS Cloud infrastructure failures.

## Overview

LVS Cloud uses a **persistent etcd + S3 backup** strategy for resilience:

- **Primary**: Block storage with persistent etcd survives server recreation
- **Secondary**: S3 backups for catastrophic block storage loss
- **Accepted Risks**:
  - Total Hetzner loss results in data loss
  - Block storage loss results in partial data loss
    - Mitigation: backup frequency
  - Total GitHub loss might result in code loss

## Backup Frequencies

### Longhorn Volume Backups

- **Daily Snapshots**: 2 AM daily, retain 7 days (local to block storage)
- **Weekly S3 Backups**: 3 AM Sunday, retain 4 weeks
- **Target**: `s3://lvs-cloud-longhorn-backups@nbg1` (Hetzner Object Storage)

### PostgreSQL Backups

- **Daily Dumps**: 1 AM daily
- **Format**: Full cluster dump (`pg_dumpall`)
- **Target**: `s3://lvs-cloud-pg-backups@nbg1` organized by `YYYY/MM/`

### Docker Registry

- Registry images stored on Longhorn volumes
- Included in weekly Longhorn S3 backups
- Additional resilience: images can be rebuilt from source via GitHub Actions

### Monitoring Data (PGL Stack)

**Prometheus Metrics:**

- Stored on Longhorn PVC (10Gi, 7-day retention)
- Backed up via weekly Longhorn S3 backups
- Data loss acceptable: historical metrics can be regenerated

**Loki Logs:**

- Stored on Longhorn PVC (10Gi, 7-day retention)
- Backed up via weekly Longhorn S3 backups
- Data loss acceptable: logs are ephemeral by nature

**Grafana Dashboards:**

- Dashboards persist to Longhorn PVC (5Gi)
- Backed up via weekly Longhorn S3 backups
- Critical for custom dashboards; restore from S3 if lost

## Disaster Scenarios

### Scenario 1: Server Recreation (Common)

**Situation**: Terraform recreates server, block storage intact

**Impact**: 5-10 minute downtime, zero data loss

**Recovery**: Automatic (see [BOOTSTRAP.md](infrastructure/bootstrap/BOOTSTRAP.md#server-recreation-verification))

```bash
# Verify etcd persisted
ssh ubuntu@$(dig +short app.lvs.me.uk) kubectl get kustomization -n flux-system

# If kustomizations exist, verify resources
./scripts/connect-k8s.sh
flux get all
kubectl get pods -A
```

**Note**: Block storage has `lifecycle { prevent_destroy = true }` in Terraform to prevent accidental deletion.

### Scenario 2: Block Storage Deletion (Rare)

**Situation**: Incorrect Terraform run deletes persistent volume

**Impact**: Complete etcd and volume data loss

**Recovery Time**: 3-4 hours (full bootstrap + S3 restore)

**Recovery Steps**:

#### 1. Recreate Infrastructure

Use GitHub action or local Terraform.

#### 2. Bootstrap Fresh Cluster

Follow [BOOTSTRAP.md Fresh Cluster Bootstrap](infrastructure/bootstrap/BOOTSTRAP.md#fresh-cluster-bootstrap)

Create all secrets:

- `flux-git-ssh` (Flux deploy key)
- `postgresql-auth` (database passwords)
- `pg-backup-s3` (PostgreSQL S3 credentials)
- `registry-credentials` (Flux image scanning)
- `longhorn-backup` (Longhorn S3 credentials)

Wait for platform deployment (~30-45 min).

#### 3. Restore PostgreSQL from S3

```bash
# List available backups
kubectl run mc-client --rm -it --image=quay.io/minio/mc:latest -- /bin/sh
mc alias set hetzner https://nbg1.your-objectstorage.com <ACCESS_KEY> <SECRET_KEY>
mc ls hetzner/lvs-cloud-pg-backups/

# Download latest backup (local machine)
mc cp hetzner/lvs-cloud-pg-backups/2025/10/pgdumpall-20251026T010000Z.sql.gz /tmp/

# Restore to PostgreSQL
gunzip /tmp/pgdumpall-20251026T010000Z.sql.gz
kubectl exec -i postgresql-0 -- psql -U postgres < /tmp/pgdumpall-20251026T010000Z.sql
```

#### 4. Restore Longhorn Volumes from S3

Access Longhorn UI:

```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
```

**For each backed-up volume**:

1. Navigate to **Backup** → Select S3 backup target
2. Select latest backup for each volume (e.g., `pvc-registry-data`, `pvc-postgresql-data`)
3. Click **Restore** → Create new volume with original name
4. Wait for restore to complete

**Relink volumes to PVCs**:

```bash
# Get PVC details
kubectl get pvc -A

# For each PVC stuck "Pending", manually bind to restored volume
# Edit PV and PVC to match volume names
# This step requires manual intervention - exact commands TBD (needs wargame validation)
```

**Limitations**: Volume relinking is complex and not fully documented. This procedure needs validation via DR wargames.

### Scenario 3: S3 Bucket Loss (Critical)

**Situation**: Hetzner S3 bucket deleted or corrupted

**Impact**: No off-site backups available

**Recovery**: Depends on block storage status:

- If block storage intact → No impact (see Scenario 1)
- If block storage lost → **Permanent data loss** (no recovery possible)

**Mitigation**:

- S3 buckets created manually outside Terraform
- Regular DR wargames ensure backup integrity

### Scenario 4: Complete Infrastructure Loss

**Situation**: Hetzner account compromise, all resources deleted

**Impact**: Total data loss if S3 backups also lost

**Recovery**:

- **S3 intact**: Follow Scenario 2 recovery
- **S3 lost**: Start from scratch, accept data loss

## S3 Bucket Configuration

**NB**: S3 buckets are created **outside of Terraform** because Terraform support for these is dodgy (and the state bucket would have to be created manually anyway).

### Existing Buckets

- `lvs-cloud-terraform-state` (Terraform state)
- `lvs-cloud-longhorn-backups` (Longhorn volume backups)
- `lvs-cloud-pg-backups` (PostgreSQL dumps)

All buckets in **Nuremberg (nbg1)** region.

### Creating New Buckets

Via Hetzner Cloud Console:

1. Storage → Object Storage → Create Bucket
2. Region: Nuremberg (nbg1)
3. Enable versioning for backup buckets

## DR Wargames

### Purpose

Regular testing validates recovery procedures and identifies gaps in documentation.

### Wargame Levels

**Level 1: Basic Server Recreation**

- Trigger: `terraform taint hcloud_server.main`
- Expected: Automatic recovery via persistent etcd
- Duration: 15 minutes
- Validates: Scenario 1 procedures

**Level 2: Volume Snapshot Restore**

- Trigger: Delete test PVC, restore from Longhorn snapshot
- Expected: Manual volume restore via Longhorn UI
- Duration: 30 minutes
- Validates: Longhorn backup/restore mechanisms

**Level 3: Full Block Storage Loss Simulation**

- Trigger: Create parallel test cluster, simulate volume loss
- Expected: Full S3 restore of PostgreSQL and registry
- Duration: 4 hours
- Validates: Scenario 2 procedures, S3 backup integrity

### Wargame Process

1. **Schedule**: At least yearly
2. **Pre-wargame**: Review this document, ensure S3 backups are recent
3. **Execute**: Follow checklist for chosen level
4. **Document**: Create `infrastructure/dr-wargames/DR_YYYY-MM-DD.md` with results
5. **Update**: Revise this document based on lessons learned

### Checklist Template

Create `infrastructure/dr-wargames/DR_YYYY-MM-DD.md`:

```markdown
# DR Wargame - YYYY-MM-DD

**Level**: [1/2/3]
**Duration**: [actual time]
**Status**: [SUCCESS/PARTIAL/FAILURE]

## Pre-Wargame Checklist

- [ ] Latest S3 backups verified (within 24h)
- [ ] Recovery documentation reviewed
- [ ] Local environment ready (kubectl, flux, mc)

## Execution Notes

[Document steps taken, deviations from documented procedures]

## Issues Encountered

[Any problems, unexpected behavior]

## Recovery Time

- Expected: [from documentation]
- Actual: [measured time]

## Lessons Learned

[What worked well, what needs improvement]

## Action Items

- [ ] Update DISASTER_RECOVERY.md with [specific changes]
- [ ] Fix issue: [description]
```

### Initial Wargame Setup

```bash
# Create wargame directory
mkdir -p infrastructure/dr-wargames
```

## Known Limitations

### 1. Volume Relinking

**Issue**: After restoring Longhorn volumes from S3, manually relinking to PVCs is not fully documented.

**Workaround**: Longhorn UI provides restore functionality, but PV/PVC rebinding may require manual YAML editing.

**Resolution**: Needs validation through Level 3 wargame.

### 2. Backup Verification

**Issue**: S3 backups are not automatically tested for integrity.

**Workaround**: Regular wargames provide manual verification.

**Future**: Automated backup verification jobs (not yet implemented).

### 3. etcd Corruption

**Issue**: If etcd on block storage becomes corrupted, the corruption persists across server recreation.

**Workaround**: etcd snapshots not currently configured.

**Future**: Implement etcd snapshot backups to S3 (not yet implemented).

## Recovery Decision Tree

```
Infrastructure failure detected
    ↓
Can you SSH to server?
    ├─ NO → Server recreation scenario (Scenario 1)
    │      → Verify: terraform plan shows server needs recreation
    │      → Recovery: terraform apply + automatic verification
    │
    └─ YES → kubectl working?
           ├─ NO → kubectl tunnel/config issue (not DR)
           │      → Fix: ./scripts/connect-k8s.sh
           │
           └─ YES → Application issue
                  └─ Check: kubectl get pods -A
                     ├─ Pods stuck "Pending" → Longhorn issue
                     │  → Check: kubectl get pv, kubectl get volumes.longhorn.io -n longhorn-system
                     │  → Possible volume loss (Scenario 2)
                     │
                     └─ Pods "CrashLoopBackOff" → Application issue (see APPS.md)
```

## Data Loss Acceptance

The following data loss scenarios are **accepted risks** for this single-developer, non-critical infrastructure:

- **S3 bucket deletion**: Would result in complete data loss if block storage also lost
- **Simultaneous block storage + S3 failure**: No recovery possible
- **Backup age window**: Up to 24 hours of data loss (PostgreSQL) or 7 days (Longhorn volumes) depending on backup frequency

These risks are acceptable given:

- Non-production environment
- Cost constraints (€9.89/month)
- Applications can be rebuilt from source
- Database contents are not business-critical

## Next Steps

1. **Immediate**: Create `infrastructure/dr-wargames/` directory
2. **Within 1 month**: Execute Level 1 wargame (basic server recreation)
3. **Within 3 months**: Execute Level 2 wargame (volume restore)
4. **Within 6 months**: Execute Level 3 wargame (full S3 restore)
5. **Ongoing**: Update this document after each wargame

## Related Documentation

- [BOOTSTRAP.md](infrastructure/bootstrap/BOOTSTRAP.md) - Fresh cluster setup and server recreation
- [APPS.md](APPS.md) - Application debugging (non-DR issues)
- [README.md](README.md) - Architecture overview
