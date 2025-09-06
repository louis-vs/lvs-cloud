# Project TODOs

## Completed ✅

### Infrastructure & Core Setup
- [x] Set up project structure and environment files
- [x] Install Hetzner CLI and configure Terraform
- [x] Create Terraform project structure for Hetzner Cloud
- [x] Initialize Terraform and test configuration
- [x] Apply Terraform to provision infrastructure
- [x] Fix cloud-init SSH key configuration
- [x] Test SSH connection to server
- [x] Set up DNS configuration for lvs.me.uk subdomains

### CI/CD & Deployment
- [x] Design GitOps deployment architecture
- [x] Create GitHub Actions workflows for CI/CD
- [x] Fix S3 backend authentication for Terraform
- [x] Implement token separation (read-only vs read-write)
- [x] Update Terraform to deploy stack via cloud-init
- [x] Apply updated Terraform to test GitOps architecture
- [x] Extract cloud-init script to separate file for cleaner Terraform
- [x] Generate dedicated SSH keys for GitHub Actions deployment
- [x] Enable manual workflow dispatch for terraform apply

### Development Tools
- [x] Set up global formatter and pre-commit hooks for all file formats
- [x] Configure comprehensive pre-commit hooks (markdown, YAML, Terraform, Ruby, shell)
- [x] Fix pre-commit hook issues (detect-secrets, markdownlint, shellcheck)
- [x] Update RuboCop configuration for proper plugin usage

### Applications & Services
- [x] Create Ruby dummy application with uptime monitoring
- [x] Deploy complete monitoring stack (Grafana, Prometheus, Loki, Traefik)
- [x] Fix Docker network naming issues preventing Traefik routing
- [x] Configure SSL certificates with Let's Encrypt
- [x] Self-hosted container registry with authentication

## Current Issues 🔧

### High Priority
- [ ] **Resolve intermittent timeout issues** with Grafana, Prometheus, and Loki services
- [ ] Debug Traefik routing stability for monitoring services

### Medium Priority
- [ ] Fix Grafana static asset loading issues (frontend build/reverse proxy config)
- [ ] Optimize Docker Compose service startup sequence
- [ ] Document deployment process and provide cost estimates

## Service Status 📊

| Service | Status | URL | Notes |
|---------|--------|-----|-------|
| Registry | ✅ Working | https://registry.lvs.me.uk | Fully operational |
| Traefik | ✅ Working | - | SSL termination & routing |
| Grafana | ⚠️ Issues | https://grafana.lvs.me.uk | Intermittent timeouts |
| Prometheus | ⚠️ Issues | https://prometheus.lvs.me.uk | Intermittent timeouts |
| Loki | ⚠️ Issues | https://loki.lvs.me.uk | Intermittent timeouts |
| Node Exporter | ✅ Working | - | Internal metrics collection |
| Watchtower | ✅ Working | - | Automatic container updates |

---
*Last updated: 2025-09-04*
