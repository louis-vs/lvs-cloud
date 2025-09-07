# Monitoring Stack - GitOps Deployment

Modern DevOps monitoring stack with automated CI/CD deployment.

## Architecture

```
GitHub → Actions → Container Registry → Watchtower → Production
   ↓         ↓           ↓                  ↓            ↓
  Code    Build &      Push Image     Auto-update    Running
        Test Image                    Containers     Services
```

## Services Deployed

- **Traefik**: Reverse proxy with automatic SSL certificates
- **Docker Registry**: Self-hosted container registry at `registry.lvs.me.uk`
- **Grafana**: Monitoring dashboards at `grafana.lvs.me.uk`
- **Prometheus**: Metrics collection at `prometheus.lvs.me.uk`
- **Loki**: Log aggregation at `loki.lvs.me.uk`
- **Direct Deployment**: Container updates triggered by GitHub Actions via SSH
- **Node Exporter**: System metrics collection

## GitOps Workflow

1. **Infrastructure Changes**: Push to `infrastructure/` → Terraform apply via GitHub Actions (requires approval)
2. **Platform Updates**: Push to `platform/monitoring/` → Direct deployment via SSH in GitHub Actions
3. **App Deployments**: Push to `applications/*/` → Build image → Push to registry → Direct deployment via SSH

## Deployment Process

### Initial Setup

```bash
# Apply infrastructure (creates server with cloud-init)
terraform apply

# GitHub Actions will handle the rest automatically
```

### Automatic Updates

- **Code changes** trigger builds and direct deployments via GitHub Actions
- **Platform changes** are deployed directly via SSH when files change
- **Infrastructure changes** are applied via Terraform (with approval)
- **SSL certificates** are automatically renewed by Traefik

## Access Points

- **Grafana**: <https://grafana.lvs.me.uk> (admin/[secure-password])
- **Registry**: <https://registry.lvs.me.uk> (admin/[secure-password])
- **Prometheus**: <https://prometheus.lvs.me.uk>
- **Loki**: <https://loki.lvs.me.uk>

## Security

- All services behind Traefik with automatic HTTPS
- Container registry with HTTP basic auth
- Docker networks for service isolation
- Security updates managed through GitHub Actions deployments

## Monitoring

- **System metrics**: Node Exporter → Prometheus → Grafana
- **Application logs**: Docker → Loki → Grafana
- **Service health**: Prometheus health checks
- **Uptime monitoring**: Ruby app sends metrics to Prometheus
