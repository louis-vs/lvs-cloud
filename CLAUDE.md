# LVS Cloud - Hetzner Infrastructure Monorepo

## Project Brief

Set up a complete IaaC cloud environment on Hetzner Cloud using Terraform for hosting applications with centralized logging and monitoring. This is a monorepo containing all infrastructure, applications, and deployment configurations.

## Requirements

- **Cloud Provider**: Hetzner Cloud
- **Infrastructure**: Terraform for IaaC
- **Main Service**: Grafana instance for logging and dashboards
- **Language Preferences**: Bash for scripting, Ruby for applications (Python only if necessary)
- **Architecture**: Container-based deployment with self-hosted container registry
- **Domain**: Subdomains of lvs.me.uk
- **API-first**: No manual UI configuration
- **DevOps Practices**: Modern CI/CD with GitOps principles

## DevOps Architecture

- **CI/CD**: GitHub Actions for build and deployment
- **GitOps**: Declarative deployments triggered by git commits
- **Container Registry**: Self-hosted registry with automated image builds
- **Deployment**: Pull-based deployments using webhooks or polling
- **Infrastructure**: Everything as code, no manual server configuration

## Deliverables Status

1. ✅ Hetzner Cloud account setup and API configuration
2. ✅ Terraform infrastructure definitions with cloud-init
3. ✅ Complete monitoring stack (Grafana, Prometheus, Loki) - *architecture improved with shared Traefik*
4. ✅ Self-hosted container registry with authentication - *fully operational*
5. ✅ Ruby monitoring application with Prometheus metrics
6. ✅ Subdomain configuration and SSL certificates - *Let's Encrypt working*
7. ✅ GitHub Actions CI/CD pipeline - *with proper token separation*
8. ✅ GitOps deployment architecture - *automated deployment working*
9. ✅ Security hardening and credential management
10. ✅ Comprehensive documentation and cost analysis

## Current Status

**Infrastructure**: ✅ Fully deployed and operational
**Monitoring Stack**: ✅ All services operational with proper container permissions
**CI/CD**: ✅ GitHub Actions workflows operational with proper authentication
**SSL/DNS**: ✅ Let's Encrypt certificates configured, deployment ready
**Traefik**: ✅ Extracted to shared infrastructure service

### Container User ID Requirements

Monitoring stack containers require specific user IDs for data directory access:

- **Grafana**: UID/GID 472 (`/var/lib/grafana`)
- **Prometheus**: UID/GID 65534 (`/var/lib/prometheus`)
- **Loki**: UID/GID 10001 (`/var/lib/loki` and `/loki`)

Cloud-init sets these permissions with `|| true` fallback to prevent provisioning failures if directories don't exist during initial setup. The `|| true` ensures the script continues even if chown fails, preventing total deployment failure.

## Structure

- Monorepo with projects in subfolders (no nesting)
- Modern DevOps practices
- Cost estimation for all resources
- Environment configuration via .env file
- Conventional commits (all lowercase) for commit messages

## High-level Architecture

```
lvs.me.uk domain
├── traefik.lvs.me.uk (Traefik dashboard)
├── grafana.lvs.me.uk (Grafana dashboard)
├── prometheus.lvs.me.uk (Prometheus metrics)
├── loki.lvs.me.uk (Loki logs)
├── registry.lvs.me.uk (Container registry)
└── app.lvs.me.uk (Demo application)
```

## Architecture Improvements

### Shared Traefik Infrastructure
- Traefik extracted from monitoring-stack to `/traefik/` directory
- Centralized SSL certificate management with Let's Encrypt
- Shared reverse proxy for all applications
- Consistent network configuration across all services
- Static configuration file (`traefik.yml`) for reliable setup

### SSL Certificate Resolution
- Fixed certificate resolver naming inconsistencies
- Standardized on `letsencrypt` resolver across all services
- HTTP-01 challenge configured for automatic certificate generation
- Secure ACME storage with proper file permissions

## Deployment Architecture

### GitOps Workflow
The deployment follows a structured GitOps approach with proper service dependencies:

1. **Infrastructure Provisioning** (`infrastructure/`)
   - Terraform provisions Hetzner Cloud server
   - Cloud-init sets up Docker, networks, and initial Traefik configuration
   - Creates directory structure for all services

2. **Shared Services Deployment** (`traefik/`)
   - Traefik deployed first as shared reverse proxy
   - Static configuration file deployed to `/etc/traefik/traefik.yml`
   - Let's Encrypt certificates automatically generated
   - External `web` network created for service discovery

3. **Application Deployment** (`applications/`)
   - Registry and monitoring stack deployed in parallel after Traefik
   - Registry provides container storage for custom applications
   - Services connect to external `web` network
   - Internal `monitoring` network for service communication

### Deployment Triggers
GitHub Actions workflows trigger on changes to:
- `infrastructure/**` - Full infrastructure rebuild
- `traefik/**` - Shared Traefik configuration updates
- `applications/monitoring-stack/**` - Monitoring services updates
- `applications/registry/**` - Container registry updates

### Service Dependencies
```
┌─────────────────┐
│   Terraform     │ (Infrastructure)
└─────────┬───────┘
          │
┌─────────▼───────┐
│    Traefik      │ (Reverse Proxy + SSL)
└─────┬───────────┘
      │
      ├─────────────────┐
      │                 │
┌─────▼──────┐    ┌─────▼───────────┐
│  Registry  │    │ Monitoring Stack│ (Parallel Deployment)
└─────┬──────┘    └─────────────────┘
      │
┌─────▼───────────┐
│  Applications   │ (Custom Apps)
└─────────────────┘
```

## Recent Updates (September 2025)

### Registry Architecture Separation
- **Registry extracted** from monitoring-stack to dedicated `applications/registry/`
- **Parallel deployment** with monitoring stack after Traefik is ready
- **Independent scaling** and management of registry vs monitoring services
- **Applications depend** on registry for custom image storage

### Code Quality Improvements
- **Centralized RuboCop** configuration at project root
- **Project-wide Ruby linting** across all applications
- **Simplified CI/CD** workflows with global gem installation
- **Removed deprecated** Docker Compose version keys and Terraform S3 parameters
