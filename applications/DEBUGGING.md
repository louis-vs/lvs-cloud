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
flux get kustomizations -A
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
flux reconcile kustomization my-app --with-source
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
flux reconcile kustomization my-app --with-source

# Force image scan
flux reconcile image repository my-app

# Restart pod
kubectl rollout restart deployment/my-app -n applications
```

## Updating Manifests

Changes to Kubernetes manifests in `k8s/` directory are automatically applied by Flux:

```bash
# 1. Edit manifest files in applications/my-app/k8s/
# 2. Commit and push
# 3. Monitor deployment
flux reconcile source git monorepo --with-source
flux reconcile kustomization my-app --with-source

# Watch rollout status
kubectl rollout status deployment/my-app -n applications
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
