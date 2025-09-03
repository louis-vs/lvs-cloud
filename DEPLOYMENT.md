# LVS Cloud - Deployment Guide

## Overview

Complete GitOps deployment pipeline for a monitoring stack on Hetzner Cloud with automated CI/CD, SSL certificates, and container orchestration.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  GitHub Actions  │───▶│  Hetzner Cloud  │
│                 │    │                  │    │                 │
│ - Terraform     │    │ - Build & Test   │    │ - cx22 Server   │
│ - Docker Compose│    │ - Deploy Infra   │    │ - Auto SSL      │
│ - Ruby Apps     │    │ - Push to Reg    │    │ - Monitoring    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                │                        │
                       ┌────────▼────────┐    ┌─────────▼────────┐
                       │  Docker Registry │    │   Watchtower     │
                       │  registry.lvs.uk │    │  Auto Updates    │
                       └─────────────────┘    └──────────────────┘
```

## Services Deployed

| Service | URL | Purpose | Port |
|---------|-----|---------|------|
| **Grafana** | https://grafana.lvs.me.uk | Monitoring dashboards | 3000 |
| **Prometheus** | https://prometheus.lvs.me.uk | Metrics collection | 9090 |
| **Loki** | https://loki.lvs.me.uk | Log aggregation | 3100 |
| **Registry** | https://registry.lvs.me.uk | Container registry | 5000 |
| **Traefik** | - | Reverse proxy & SSL | 80/443 |

## Prerequisites

1. **Hetzner Cloud Account** with API token
2. **Domain** with DNS management (lvs.me.uk)
3. **GitHub Repository** with Actions enabled
4. **Local Development** environment with:
   - Terraform >= 1.0
   - Docker & Docker Compose
   - Git
   - SSH key pair

## Initial Setup

### 1. Environment Configuration

```bash
# Clone repository
git clone <your-repo-url>
cd lvs-cloud

# Copy environment template
cp .env.example .env

# Edit .env with your values:
export HCLOUD_TOKEN="your-hetzner-api-token"
export REGISTRY_PASS="your-secure-registry-password"
```

### 2. Infrastructure Deployment

```bash
# Source environment
source .env

# Initialize and deploy infrastructure
cd infrastructure
terraform init
terraform apply
```

**What happens:**
- Creates Hetzner Cloud server (cx22)
- Sets up networking and firewall
- Runs cloud-init bootstrap
- Installs Docker and creates directories
- Configures monitoring service configs

### 3. DNS Configuration

Set up these A records pointing to your server IP:

```dns
grafana.lvs.me.uk    A    <server-ip>
prometheus.lvs.me.uk A    <server-ip>
loki.lvs.me.uk       A    <server-ip>
registry.lvs.me.uk   A    <server-ip>
```

### 4. GitHub Actions Setup

Add these secrets to your GitHub repository:

```yaml
# Repository Settings → Secrets and Variables → Actions
HCLOUD_TOKEN: "your-hetzner-api-token"
REGISTRY_USER: "admin"
REGISTRY_PASS: "your-secure-registry-password"
```

## GitOps Workflow

### Infrastructure Changes

```bash
# Edit Terraform files
vim infrastructure/main.tf

# Commit and push
git add .
git commit -m "feat: update server configuration"
git push origin main
```

**→ Triggers:** `.github/workflows/deploy-infrastructure.yml`
**→ Actions:** Terraform plan & apply via GitHub Actions

### Application Updates

```bash
# Edit monitoring stack
vim applications/monitoring-stack/docker-compose.prod.yml

# Or edit Ruby application
vim applications/ruby-monitor/app.rb

# Commit and push
git add .
git commit -m "feat: add new monitoring endpoint"
git push origin main
```

**→ Triggers:** `.github/workflows/build-and-deploy-app.yml`
**→ Actions:** 
1. Build Docker images
2. Push to self-hosted registry
3. Watchtower detects changes
4. Auto-deploys updated containers

### Automatic Updates

- **Watchtower** checks registry every 5 minutes
- **SSL certificates** auto-renewed by Traefik
- **Container updates** pulled automatically
- **Service discovery** via Docker labels

## Monitoring & Operations

### Service Health

```bash
# SSH into server
ssh -i ~/.ssh/lvs-cloud ubuntu@<server-ip>

# Check service status
docker compose -f /opt/monitoring-stack/docker-compose.yml ps

# View logs
docker logs grafana
docker logs prometheus
docker logs traefik
```

### Accessing Services

- **Grafana**: https://grafana.lvs.me.uk (admin/admin123)
- **Prometheus**: https://prometheus.lvs.me.uk
- **Registry**: https://registry.lvs.me.uk (admin/your-password)

### Metrics & Alerts

- **System metrics**: Node Exporter → Prometheus → Grafana
- **Application logs**: Docker → Loki → Grafana
- **Service health**: Prometheus health checks
- **Uptime monitoring**: Ruby app metrics

## Deployment Process Summary

1. **Code Push** → GitHub repository
2. **GitHub Actions** → Build, test, deploy
3. **Container Registry** → Store images
4. **Watchtower** → Detect updates
5. **Auto-Deploy** → Pull and restart containers
6. **SSL Certificates** → Automatic renewal
7. **Service Discovery** → Traefik routing

## Troubleshooting

### Common Issues

**Services not accessible:**
```bash
# Check DNS resolution
nslookup grafana.lvs.me.uk

# Check Traefik logs
docker logs traefik | grep -i error

# Verify networks
docker network ls
```

**SSL Certificate issues:**
```bash
# Check ACME logs
docker logs traefik | grep -i acme

# Verify domain points to server
dig grafana.lvs.me.uk
```

**Container deployment failures:**
```bash
# Check Watchtower logs  
docker logs watchtower

# Manual image pull
docker pull registry.lvs.me.uk/ruby-monitor:latest
```

### Recovery Procedures

**Complete infrastructure rebuild:**
```bash
terraform destroy -auto-approve
terraform apply -auto-approve
# DNS propagation: ~5-60 minutes
```

**Service-specific restart:**
```bash
docker compose restart <service-name>
```

**Certificate renewal:**
```bash
docker restart traefik
# Certificates auto-renew on next request
```

## Security Considerations

- ✅ **Environment variables** for all secrets
- ✅ **No hardcoded credentials** in code
- ✅ **SSH key authentication** only
- ✅ **HTTPS everywhere** via Traefik
- ✅ **Registry authentication** with htpasswd
- ✅ **Firewall rules** restrict access
- ✅ **Container isolation** via networks
- ✅ **Regular updates** via Watchtower

---

*Generated: 2025-09-03 | Architecture: GitOps + Hetzner Cloud*