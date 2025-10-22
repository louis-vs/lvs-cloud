# Longhorn Storage Setup

## Overview

Longhorn provides distributed block storage for Kubernetes with snapshots, backups, and replication. On a single node, it provides **PVC abstraction** + **S3 backups** to Hetzner Object Storage.

## Architecture

```
Application Pod
      ↓
PersistentVolumeClaim (PVC)
      ↓
PersistentVolume (PV) - Longhorn StorageClass
      ↓
Longhorn Volume (single replica on node)
      ↓
/srv/data/longhorn (host path)
      ↓
Hetzner S3 (weekly backups)
```

## Installation

Longhorn is installed via Helm with the following configuration:

### HelmRepository

```yaml
# platform/helmrepositories/longhorn.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: longhorn
  namespace: flux-system
spec:
  interval: 30m
  url: https://charts.longhorn.io
```

### HelmRelease

```yaml
# infrastructure/longhorn/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: longhorn
  namespace: longhorn-system
spec:
  interval: 5m
  chart:
    spec:
      chart: longhorn
      version: ">=1.6.0"
      sourceRef:
        kind: HelmRepository
        name: longhorn
        namespace: flux-system
  values:
    persistence:
      defaultClass: true
      defaultClassReplicaCount: 1
    defaultSettings:
      defaultReplicaCount: 1
      defaultDataPath: /srv/data/longhorn
      backupTarget: s3://<bucket>@nbg1
      backupTargetCredentialSecret: longhorn-backup
      concurrentReplicaRebuildPerNodeLimit: 1
```

### S3 Backup Credentials

```yaml
# infrastructure/longhorn/backup-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: longhorn-backup
  namespace: longhorn-system
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "<hetzner_access_key>"
  AWS_SECRET_ACCESS_KEY: "<hetzner_secret_key>"
  AWS_DEFAULT_REGION: "nbg1"
  AWS_ENDPOINTS: |
    [{"s3":"https://nbg1.your-objectstorage.com"}]
```

**Important**: Create a bucket in Hetzner Object Storage first, then set the credentials in Terraform to inject this secret.

## Recurring Jobs (Snapshots + Backups)

Longhorn supports automated snapshots (local) and backups (to S3).

### Cluster-Wide Recurring Jobs

```yaml
# infrastructure/longhorn/recurring-jobs.yaml
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: daily-snap
  namespace: longhorn-system
spec:
  task: snapshot
  cron: "0 2 * * *"     # Daily at 02:00
  retain: 7
  concurrency: 1
  groups: ["default"]
  labels:
    purpose: "daily-snapshots"
---
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: weekly-bak
  namespace: longhorn-system
spec:
  task: backup
  cron: "0 3 * * 0"     # Sundays at 03:00
  retain: 4
  concurrency: 1
  groups: ["default"]
  labels:
    purpose: "weekly-backups"
```

### Attach Jobs to PVCs

You can attach recurring jobs via PVC annotations or via Longhorn Volume labels.

**Option 1: PVC Annotation** (recommended for Helm charts):

```yaml
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  annotations:
    longhorn.io/recurring-jobs: |
      [
        {"name":"daily-snap","task":"snapshot","cron":"0 2 * * *","retain":7},
        {"name":"weekly-bak","task":"backup","cron":"0 3 * * 0","retain":4}
      ]
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: longhorn
  resources:
    requests:
      storage: 50Gi
```

**Option 2: Longhorn Volume Labels** (via Longhorn UI or kubectl):

```bash
kubectl -n longhorn-system label volume pvc-<uuid> recurring-job.longhorn.io/daily-snap=enabled
kubectl -n longhorn-system label volume pvc-<uuid> recurring-job.longhorn.io/weekly-bak=enabled
```

## Using Longhorn PVCs

### Basic PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

### In a StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
spec:
  serviceName: postgresql
  replicas: 1
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: longhorn
        resources:
          requests:
            storage: 50Gi
  template:
    spec:
      containers:
        - name: postgres
          image: postgres:16
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
```

## Operations

### Longhorn UI

Longhorn provides a web UI for managing volumes, snapshots, and backups.

**Access via port-forward**:

```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
```

**Or create an Ingress**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn
  namespace: longhorn-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  ingressClassName: traefik
  tls:
    - hosts: ["longhorn.lvs.me.uk"]
      secretName: longhorn-tls
  rules:
    - host: longhorn.lvs.me.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: longhorn-frontend
                port:
                  number: 80
```

### List Volumes

```bash
kubectl -n longhorn-system get volumes
```

### List Snapshots

```bash
# Via kubectl
kubectl -n longhorn-system get snapshots

# Or use Longhorn UI
```

### Manual Snapshot

```bash
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Snapshot
metadata:
  name: manual-$(date +%Y%m%d-%H%M%S)
  namespace: longhorn-system
spec:
  volumeName: pvc-<uuid>
  labels:
    type: manual
EOF
```

### Manual Backup (to S3)

```bash
# Via Longhorn CLI (in longhorn-manager pod)
kubectl -n longhorn-system exec -it deploy/longhorn-manager -- \
  longhornctl backup create --volume-name pvc-<uuid>

# Or use Longhorn UI: Volume → Create Backup
```

### Restore from Backup

**1. List backups**:

```bash
kubectl -n longhorn-system get backups
```

**2. Create new volume from backup**:

```yaml
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: restored-volume
  namespace: longhorn-system
spec:
  fromBackup: s3://<bucket>@nbg1/backups/<volume-name>/backup-<id>
  numberOfReplicas: 1
  size: "50Gi"
```

**3. Create PVC pointing to the restored volume** (or use Longhorn UI).

## Disaster Recovery

### Backup Strategy

**Volume-level** (Longhorn):

- Weekly backups to Hetzner S3
- Restores entire block device (filesystem + data)

**Logical** (Application-specific):

- PostgreSQL: `pg_dump` CronJob → S3
- Grafana: Dashboards persisted to Longhorn PVC (included in volume backups)

**Recommended**: Use both. Volume backups are fast; logical backups are portable.

### Complete Rebuild Scenario

If you destroy the server:

1. **Terraform apply** → Creates new server with k3s + Flux
2. **Flux syncs** → Installs Longhorn with S3 credentials
3. **Manually restore PVCs** from Longhorn backups (via UI or kubectl)
4. **Apps redeploy** → Use restored data

**Note**: This is **semi-automatic**. You must manually trigger PVC restores from S3 backups.

## Monitoring

### Longhorn Metrics

Longhorn exposes Prometheus metrics on port `9500`.

**Grafana Alloy scrape config**:

```yaml
prometheus.scrape "longhorn" {
  targets = [
    {"__address__" = "longhorn-backend.longhorn-system:9500"},
  ]
  forward_to = [prometheus.remote_write.mimir.receiver]
}
```

### Check Longhorn Health

```bash
# Node status
kubectl -n longhorn-system get nodes.longhorn.io

# Volume status
kubectl -n longhorn-system get volumes.longhorn.io

# Pod status
kubectl -n longhorn-system get pods
```

## Troubleshooting

### PVC Stuck in Pending

```bash
# Describe PVC for events
kubectl describe pvc <pvc-name>

# Check Longhorn volume
kubectl -n longhorn-system get volumes

# Check Longhorn manager logs
kubectl -n longhorn-system logs deploy/longhorn-manager -f
```

### Backup Failing

```bash
# Check backup target config
kubectl -n longhorn-system get settings.longhorn.io backup-target -o yaml

# Test S3 connectivity from longhorn-manager pod
kubectl -n longhorn-system exec -it deploy/longhorn-manager -- sh
apk add aws-cli
aws s3 ls s3://<bucket> --endpoint-url https://nbg1.your-objectstorage.com
```

### Volume Degraded

On a single node, volumes can't replicate, so "degraded" may appear if the node restarts. This is expected.

```bash
# Check volume health
kubectl -n longhorn-system get volumes.longhorn.io
```

### Disk Space Full

```bash
# Check node disk usage
df -h /srv/data/longhorn

# Check Longhorn volume sizes
kubectl -n longhorn-system get volumes -o custom-columns=NAME:.metadata.name,SIZE:.spec.size,ACTUAL:.status.actualSize
```

## Performance Considerations

### Single Node Limitations

- **No HA**: If the node dies, volumes are unavailable until it recovers
- **No replication**: `defaultReplicaCount: 1` (can't do more on one node)
- **Disk I/O**: All storage is on one disk (50GB Hetzner volume)

### Typical Performance

- **Sequential read/write**: ~100 MB/s (limited by Hetzner volume)
- **Random IOPS**: ~3000 IOPS (limited by Hetzner volume)
- **Latency**: ~2-5ms (local disk)

### Right-Sizing PVCs

- **PostgreSQL**: 50Gi (allows growth)
- **Grafana**: 5Gi (dashboards + config)
- **App ephemeral state**: 1-5Gi
- **Logs**: Consider external logging (Loki) instead of PVCs

## Cost

- **Longhorn itself**: Free (open source)
- **Host storage**: Included in Hetzner volume (50GB, €~5/month)
- **S3 backups**: €0.01 per GB/month (minimal, ~1-2GB compressed)

## Next Steps

- [Apps Migration](APPS.md) - Convert apps to use Longhorn PVCs
- [Flux Setup](FLUX_SETUP.md) - Deploy Longhorn via Flux
