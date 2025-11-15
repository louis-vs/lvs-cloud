# Email Alerting Setup

## Prerequisites

### 1. AWS SES Configuration

1. **Create AWS SES SMTP credentials**:
   - Go to AWS SES Console → SMTP Settings
   - Create SMTP credentials (note username and password)
   - Region: `eu-west-1` (configured in helmrelease)

2. **Verify sender email**:
   - Verify the domain `lvs.me.uk` or specific email `alerts@lvs.me.uk`
   - Without verification, SES stays in sandbox mode (can only send to verified addresses)

3. **Request production access** (optional):
   - If in sandbox, request production access to send to any email
   - Or verify recipient email addresses for testing

### 2. Update Configuration

1. **Update email and credentials** in `alertmanager-config.yaml`:
   - Replace `YOUR_EMAIL@example.com` with your actual email
   - Replace `YOUR_SES_SMTP_USERNAME` with your AWS SES SMTP username (appears twice)

2. **Create Kubernetes Secret** for the password only:

```bash
kubectl create secret generic alertmanager-ses-credentials \
  -n monitoring \
  --from-literal=SMTP_PASSWORD='your-ses-smtp-password'
```

**Note**: The SMTP username must be configured inline in `alertmanager-config.yaml` as v1alpha1 doesn't support secret references for usernames.

### 3. Deploy

```bash
flux reconcile source git flux-system
flux reconcile kustomization platform-monitoring --timeout 5m
```

## Alert Rules

The following alerts are configured in `alert-rules.yaml`:

**Critical Alerts**:

- Node down (5min)
- Disk space < 10% (5min)
- Pod in CrashLoopBackOff (5min)
- Longhorn volume faulted (1min)

**Warning Alerts**:

- CPU > 80% (10min)
- Memory > 85% (10min)
- Disk space < 20% (5min)
- Pod restarting frequently (15min)
- Pod not ready (15min)
- Deployment replicas mismatch (15min)
- Longhorn volume degraded (5min)

## Testing

Access Alertmanager at: `https://grafana.lvs.me.uk/alertmanager`

To trigger a test alert:

```bash
kubectl run test-crash --image=busybox --restart=Never -- sh -c "exit 1"
```

This will trigger `PodCrashLoop` alert after 5 minutes.

## Configuration

- **Alert grouping**: By alertname, cluster, service
- **Repeat interval**: 24 hours (one email per alert per day)
- **SMTP endpoint**: AWS SES eu-west-1 (port 587)
