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

### Registry Architecture & Code Quality (September 2025)
- [x] Extract registry from monitoring-stack to dedicated service
- [x] Create separate applications/registry/ with own docker-compose.yml
- [x] Update deployment workflow for parallel registry/monitoring deployment
- [x] Remove deprecated Docker Compose version keys from all files
- [x] Fix deprecated Terraform S3 backend parameters (endpoint → endpoints.s3, force_path_style → use_path_style)
- [x] Centralize RuboCop configuration at project root
- [x] Update code-quality workflow to run RuboCop project-wide
- [x] Document container user ID requirements for monitoring services

## Current Issues 🔧

### High Priority
- [ ] **Deploy and test registry separation** with new parallel deployment architecture
- [ ] Verify all services work correctly after registry extraction
- [ ] Test complete GitOps workflow with updated deployment dependencies

### Medium Priority
- [ ] Add ruby-monitor application to GitOps deployment
- [ ] Create comprehensive deployment documentation
- [ ] Investigate Docker Hub timeout issues in monitoring stack deployment

## Service Status 📊

| Service | Status | URL | Notes |
|---------|--------|-----|-------|
| Traefik | ✅ Working | https://traefik.lvs.me.uk | Shared infrastructure service |
| Registry | 🔄 Updated | https://registry.lvs.me.uk | Extracted to separate service |
| Grafana | ✅ Working | https://grafana.lvs.me.uk | Container permissions fixed |
| Prometheus | ✅ Working | https://prometheus.lvs.me.uk | Container permissions fixed |
| Loki | ✅ Working | https://loki.lvs.me.uk | Container permissions fixed |
| Node Exporter | ✅ Working | - | Internal metrics collection |
| Watchtower | ✅ Working | - | Automatic container updates |

### Architecture Status
- **Registry**: Extracted to dedicated `applications/registry/` service
- **Parallel Deployment**: Registry and monitoring stack deploy simultaneously
- **Code Quality**: Centralized RuboCop configuration across project
- **Dependencies**: Applications now wait for registry before deployment
- **Deprecation Cleanup**: Removed deprecated Docker/Terraform configurations

---
*Last updated: 2025-09-06*
