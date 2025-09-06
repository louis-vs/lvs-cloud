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
3. ✅ Complete monitoring stack (Grafana, Prometheus, Loki) - *deployed with intermittent routing issues*
4. ✅ Self-hosted container registry with authentication - *fully operational*
5. ✅ Ruby monitoring application with Prometheus metrics
6. ✅ Subdomain configuration and SSL certificates - *Let's Encrypt working*
7. ✅ GitHub Actions CI/CD pipeline - *with proper token separation*
8. ✅ GitOps deployment architecture - *automated deployment working*
9. ✅ Security hardening and credential management
10. ✅ Comprehensive documentation and cost analysis

## Current Status

**Infrastructure**: ✅ Fully deployed and operational
**Monitoring Stack**: ⚠️ Registry working perfectly, other services have intermittent timeout issues
**CI/CD**: ✅ GitHub Actions workflows operational with proper authentication
**SSL/DNS**: ✅ All certificates working, DNS resolution correct

## Structure

- Monorepo with projects in subfolders (no nesting)
- Modern DevOps practices
- Cost estimation for all resources
- Environment configuration via .env file
- Conventional commits (all lowercase) for commit messages

## High-level Architecture

```
lvs.me.uk domain
├── grafana.lvs.me.uk (Grafana dashboard)
├── registry.lvs.me.uk (Container registry)
└── app.lvs.me.uk (Demo application)
```
