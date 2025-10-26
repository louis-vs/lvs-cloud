# Operations & Troubleshooting (Kubernetes)

## Access Points

**Internet-accessible:**

- **Grafana**: <https://grafana.lvs.me.uk> (admin/password)
- **Registry**: <https://registry.lvs.me.uk> (robot_user/password)
- **SSH**: `ssh ubuntu@$(dig +short app.lvs.me.uk)`

**Cluster-internal:**

- **PostgreSQL**: `postgresql.default.svc.cluster.local:5432`
- **Longhorn UI**: `http://longhorn-frontend.longhorn-system`

## Common Commands

### Cluster Status

```bash
# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods -A

# Check specific namespace
kubectl get pods -n default

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

### Flux Status

```bash
# All Flux resources
flux get all

# GitRepository
flux get sources git

# Kustomizations
flux get kustomizations

# HelmReleases
flux get helmreleases

# Image automation
flux get images all
```

### Image Automation Status

```bash
# Check image repositories
flux get images repository

# Check image policies
flux get images policy

# Check image update automation
flux get image update

# View recent Flux commits
git log --oneline --author="flux-bot" -10
```

### Application Logs

```bash
# Tail logs
kubectl logs -f -l app.kubernetes.io/name=ruby-demo-app

# Previous pod logs (if crashed)
kubectl logs -p ruby-demo-app-<pod-id>

# All containers in pod
kubectl logs ruby-demo-app-<pod-id> --all-containers

# Follow logs from multiple pods
kubectl logs -f -l app=ruby-demo-app --max-log-requests=10
```

### Database Operations

```bash
# Connect to PostgreSQL
kubectl exec -it postgresql-0 -- psql -U postgres

# List databases
kubectl exec -it postgresql-0 -- psql -U postgres -c '\l'

# Check connections
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT datname, usename, client_addr FROM pg_stat_activity WHERE state = 'active';"

# Backup database
kubectl exec postgresql-0 -- pg_dumpall -U postgres > backup.sql

# Restore database
kubectl exec -i postgresql-0 -- psql -U postgres < backup.sql
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods

# Describe pod for events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check previous logs if crashed
kubectl logs -p <pod-name>

# Check resource constraints
kubectl top pod <pod-name>
kubectl describe node
```

### Flux Not Syncing

```bash
# Check GitRepository
flux get sources git monorepo

# Check for errors
flux logs --all-namespaces --level=error

# Force reconcile
flux reconcile source git monorepo
flux reconcile kustomization apps

# Check Git credentials
kubectl -n flux-system get secret flux-git-ssh

# Check Flux controllers
kubectl -n flux-system get pods
kubectl -n flux-system logs deploy/source-controller
```

### Image Not Updating Automatically

**Symptoms**: New image pushed but deployment not updating

**Check**:

```bash
# Verify ImageRepository can scan
flux get images repository <app-name>
# Should show: READY True, last scan time recent

# Check authentication
kubectl get secret registry-credentials -n flux-system
# Should exist

# Check ImagePolicy selected correct tag
flux get images policy <app-name>
# Should show latest tag

# Check ImageUpdateAutomation is running
flux get image update monorepo-auto
# Should show: READY True

# Force reconciliation
flux reconcile image repository <app-name>
flux reconcile image update monorepo-auto

# View automation logs
kubectl -n flux-system logs deploy/image-automation-controller -f

# Verify Flux can commit
git log --oneline --author="flux-bot" -5
```

**Common causes**:

- registry-credentials secret missing
- ImageRepository secretRef not set
- Image tag doesn't match semver policy range
- ImageUpdateAutomation can't push (deploy key permissions)

### HelmRelease Failing

```bash
# Check status
flux get helmrelease ruby-demo-app

# Describe for events
kubectl describe helmrelease ruby-demo-app

# Check Helm controller logs
kubectl -n flux-system logs deploy/helm-controller -f

# Manually render chart
helm template applications/ruby-demo-app/chart \
  -f applications/ruby-demo-app/values.yaml
```

### Ingress/TLS Issues

```bash
# Check ingresses
kubectl get ingresses

# Describe ingress
kubectl describe ingress ruby-demo-app

# Check cert-manager certificates
kubectl get certificates

# Describe certificate
kubectl describe certificate ruby-demo-app-tls

# Check cert-manager logs
kubectl -n cert-manager logs deploy/cert-manager -f

# Force certificate renewal
kubectl delete certificate ruby-demo-app-tls
```

### Longhorn Issues

```bash
# Check volumes
kubectl -n longhorn-system get volumes

# Check Longhorn manager logs
kubectl -n longhorn-system logs deploy/longhorn-manager -f

# Access Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080

# Check node disk status
kubectl -n longhorn-system get nodes.longhorn.io
```

### Registry Issues

```bash
# Test registry from cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
curl -u robot_user:<password> https://registry.lvs.me.uk/v2/_catalog

# Test registry from host
ssh ubuntu@$(dig +short app.lvs.me.uk) \
  'docker pull registry.lvs.me.uk/ruby-demo-app:latest'

# Check Caddy logs (registry frontend)
ssh ubuntu@$(dig +short app.lvs.me.uk) 'journalctl -u caddy -f'

# Check Docker registry container
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker logs registry'
```

## Maintenance

### Resource Monitoring

```bash
# Node resources
kubectl top node

# Pod resources
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Persistent volume usage
kubectl get pv

# Longhorn volume sizes
kubectl -n longhorn-system get volumes \
  -o custom-columns=NAME:.metadata.name,SIZE:.spec.size,ACTUAL:.status.actualSize
```

### Log Cleanup

```bash
# Old pods
kubectl delete pod --field-selector status.phase=Succeeded -A
kubectl delete pod --field-selector status.phase=Failed -A

# Docker logs (on host)
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker system prune -f'
```

### Certificate Renewal

Automatic via cert-manager. Certificates renew 30 days before expiry.

```bash
# Check certificate expiry
kubectl get certificates

# Force renewal
kubectl delete certificate <cert-name>
# cert-manager recreates automatically
```

### Backing Up

**Longhorn volumes**: Weekly backups to Hetzner S3 (automatic)

**PostgreSQL**: Daily pg_dump to S3 (CronJob)

**Manual backup:**

```bash
# Backup PostgreSQL
kubectl exec postgresql-0 -- pg_dumpall -U postgres | gzip > backup-$(date +%Y%m%d).sql.gz

# Download to local machine
scp ubuntu@$(dig +short app.lvs.me.uk):~/backup-*.sql.gz ./

# Backup Grafana dashboards (persisted to Longhorn PVC)
kubectl cp -n monitoring grafana-<pod-id>:/var/lib/grafana/grafana.db ./grafana.db
```

### Upgrading

**k3s**: Automatic weekly upgrades (Sundays 03:00 via systemd timer)

**Platform services**: Managed by Flux (update chart versions in HelmReleases)

**Applications**: Automatic via Flux Image Automation

**Manual k3s upgrade:**

```bash
ssh ubuntu@$(dig +short app.lvs.me.uk) 'sudo /usr/local/sbin/k3s-upgrade.sh'
```

## Debugging Workflows

### GitHub Actions Failing

```bash
# List recent workflow runs
gh run list

# View specific run
gh run view <run-id> --log

# Re-run failed workflow
gh run rerun <run-id>
```

### Network Issues

```bash
# Test pod-to-pod connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
wget -O- http://postgresql:5432

# Test pod-to-internet
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
curl https://example.com

# Check k3s networking
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Disk Space Issues

```bash
# Check host disk
ssh ubuntu@$(dig +short app.lvs.me.uk) 'df -h'

# Check /srv/data usage
ssh ubuntu@$(dig +short app.lvs.me.uk) 'du -sh /srv/data/*'

# Check container images
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker images'
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker system df'

# Cleanup unused images
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker image prune -a -f'
```

## Security

### Current Measures

- SSH key authentication only
- Firewall: ports 22, 80, 443 only
- Registry: Basic auth over HTTPS
- k3s API: Not exposed (localhost only)
- TLS everywhere via cert-manager
- Container isolation via k8s namespaces

### Regular Checks

```bash
# Check failed SSH attempts
ssh ubuntu@$(dig +short app.lvs.me.uk) "grep 'Failed password' /var/log/auth.log | tail -20"

# Check open ports
nmap app.lvs.me.uk

# Check for pods running as root
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.runAsUser}{"\n"}{end}'
```

## Cost Tracking

- **Hetzner cx22**: €4.90/month
- **Object Storage** (Terraform state + backups): €4.99/month
- **Total**: €9.89/month

**Monitor**: Hetzner Console for usage spikes

## Emergency Procedures

### Complete Cluster Restart

```bash
ssh ubuntu@$(dig +short app.lvs.me.uk)
sudo systemctl restart k3s
kubectl get pods -A -w
```

### Force Flux Resync

```bash
flux suspend kustomization --all
flux resume kustomization --all
flux reconcile source git monorepo --with-source
```

### Rollback Application

```bash
# Via Flux (revert Git commit)
git revert HEAD
git push

# Manual (emergency)
kubectl rollout undo deployment/ruby-demo-app
```

## Useful Links

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Flux Docs](https://fluxcd.io/docs/)
- [Longhorn Docs](https://longhorn.io/docs/)
- [cert-manager Docs](https://cert-manager.io/docs/)
