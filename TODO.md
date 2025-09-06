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

### SSL & Traefik Architecture (September 2025)
- [x] Identify SSL certificate resolver configuration inconsistencies
- [x] Create shared Traefik configuration at repository root level
- [x] Extract Traefik service from monitoring-stack to shared infrastructure
- [x] Standardize Docker networks across all configurations
- [x] Update cloud-init with proper Traefik static configuration
- [x] Fix Let's Encrypt certificate resolver naming

## Current Issues 🔧

### High Priority
- [ ] **Deploy and test updated infrastructure** with new Traefik architecture
- [ ] Verify SSL certificate generation works with Let's Encrypt
- [ ] Test site accessibility after infrastructure deployment

### Medium Priority
- [ ] Create deployment documentation for shared Traefik architecture
- [ ] Add ruby-monitor application to GitOps deployment
- [ ] Optimize monitoring stack service dependencies

## Service Status 📊

| Service | Status | URL | Notes |
|---------|--------|-----|-------|
| Traefik | 🔄 Updated | https://traefik.lvs.me.uk | Extracted to shared infrastructure |
| Registry | ✅ Working | https://registry.lvs.me.uk | Fully operational |
| Grafana | 🔄 Updated | https://grafana.lvs.me.uk | Architecture improved |
| Prometheus | 🔄 Updated | https://prometheus.lvs.me.uk | Architecture improved |
| Loki | 🔄 Updated | https://loki.lvs.me.uk | Architecture improved |
| Node Exporter | ✅ Working | - | Internal metrics collection |
| Watchtower | ✅ Working | - | Automatic container updates |

### Architecture Status
- **Traefik**: Moved to shared `/traefik/` directory with static configuration
- **SSL Certificates**: Let's Encrypt resolver standardized across all services
- **Networks**: Consistent `web` (external) and `monitoring` (internal) networks
- **Deployment**: Ready for infrastructure update and testing

---
*Last updated: 2025-09-06*
