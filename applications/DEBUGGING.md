# Application Debugging Guide

Troubleshooting and debugging procedures for LVS Cloud applications.

## Access Points

- **Grafana**: <https://grafana.lvs.me.uk>
- **Registry**: <https://registry.lvs.me.uk>
- **SSH**: `ssh ubuntu@$(dig +short app.lvs.me.uk)`
- **PostgreSQL** (internal): `postgresql.platform.svc.cluster.local:5432`

## Quick Status Checks

```bash
# Cluster overview
kubectl get nodes
kubectl get pods -A

# App status
kubectl get pods -l app.kubernetes.io/name=my-app -n applications
kubectl logs -f -l app.kubernetes.io/name=my-app -n applications

# Flux status
flux get helmreleases -A
flux get images all

# Database
kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c '\l'
```

## Common Issues

### Pod not starting

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs -p <pod-name>  # Previous logs if crashed
```

### Flux not syncing

```bash
flux get sources git monorepo
flux reconcile source git monorepo
flux reconcile helmrelease my-app
```

### Image not updating

```bash
flux get images repository my-app
flux get images policy my-app
flux reconcile image repository my-app
kubectl get secret registry-credentials -n flux-system  # Should exist
```

### Database connection issues

```bash
kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c "\du"
kubectl exec -it postgresql-0 -n platform -- psql -U my_app_user -d my_app_db -c "SELECT 1"
```

### Certificate issues

```bash
kubectl get certificates
kubectl describe certificate my-app-tls
kubectl -n cert-manager logs deploy/cert-manager -f
```

## Force Reconciliation

```bash
# Force Flux to resync everything
flux reconcile source git monorepo --with-source
flux reconcile kustomization apps
flux reconcile helmrelease my-app -n applications

# Force image scan
flux reconcile image repository my-app

# Full reconciliation chain (git -> chart -> helmrelease)
flux reconcile source git monorepo -n flux-system
flux reconcile source chart applications-my-app -n flux-system
flux reconcile helmrelease my-app -n applications

# Restart pod
kubectl rollout restart deployment/my-app -n applications
```

## Updating Helm Charts

When modifying Helm chart templates (not just values), you must bump the chart version to force Flux to repackage:

**Important**: If you only change chart templates (`chart/templates/*`) without bumping the version in `Chart.yaml`, Flux will not repackage the chart and changes won't deploy.

```bash
# 1. Edit chart files in applications/my-app/chart/templates/
# 2. Bump version in applications/my-app/chart/Chart.yaml
#    version: 1.0.0 -> 1.0.1
# 3. Commit and push
# 4. Monitor deployment
flux reconcile source git monorepo -n flux-system
flux reconcile source chart applications-my-app -n flux-system
flux reconcile helmrelease my-app -n applications

# Verify new chart version deployed
kubectl get helmrelease my-app -n applications -o jsonpath='{.status.lastAttemptedRevision}'
```

## Resource Monitoring

```bash
# Node and pod resources
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Persistent volumes
kubectl get pv
kubectl -n longhorn-system get volumes

# Database sizes
kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c \
  "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC"
```

## Emergency Procedures

### Rollback deployment

```bash
git revert HEAD
git push
```

### Restart cluster

```bash
ssh ubuntu@$(dig +short app.lvs.me.uk)
sudo systemctl restart k3s
```

### Backup database

```bash
kubectl exec postgresql-0 -n platform -- pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql.gz
```
