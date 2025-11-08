# LVS Cloud - Private Cloud Infrastructure

## Vision

LVS Cloud is a **personal private cloud platform** that scales while being maintainable by a single developer. The system uses modern DevOps practices to seamlessly deploy and monitor applications with enterprise-grade observability at startup costs.

**Core Principles:**

- **Consolidated DevOps**: GitHub for CI/CD, Grafana for monitoring - everything in one place
- **Persistent Dashboards**: All Grafana dashboards persist to block storage for custom development
- **Maximum Reproducibility**: Infrastructure as code, minimal persistent state
- **Automatic Operations**: Push code → auto-build → auto-deploy → auto-monitor

## Current Architecture

**Infrastructure**: Hetzner Cloud cx22 (€9.89/month total) + 50GB block storage
**Stack**: k3s + Flux CD + PGL (Prometheus + Grafana + Loki) + Longhorn + PostgreSQL + In-cluster Registry
**Deployment**: GitHub Actions (build → push) → Flux Image Automation (scan → commit) → HelmRelease update → k3s rolling deployment

## File Structure

```plaintext
├── README.md             # Status, quick commands, current state
├── APPS.md               # App deployment and debugging
├── infrastructure/       # Terraform for Hetzner Cloud
├── platform/             # Platform services (PGL monitoring, Traefik, Registry)
├── applications/         # User applications
└── .github/workflows/    # CI/CD automation
```

## Future Development

- **Example apps:**
  - **Go App**: Builtin server with Go templates
  - **Python App**: FastAPI application template
- **Authentication server**:
  - Authelia authentication server that is used to authenticate to all platform services and applications

## Development Process

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <description>`

- **Types**: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`
- **Scopes**: Optional - use for component-specific changes (`platform`, `ruby-demo-app`, `infrastructure`)
- **Examples**: `feat(platform): add new service`, `fix(ruby-demo-app): resolve crash`, `docs: update README`

We are using pre-commit hooks with auto-fix in this repo. If the hook fails, re-add files and re-run *the exact same commit command*. DO NOT AMEND COMMITS.

### Database Development

- **Shared PostgreSQL**: All apps use the shared PostgreSQL server with per-app databases
- **Connection Pattern**: Pass individual env vars (DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME), construct DATABASE_URL in app code
  - **IMPORTANT**: Kubernetes doesn't support `$(VAR)` substitution in env values
  - See APPS.md for examples in Ruby/Python
- **Migrations**: Include migration commands in app startup for GitOps compatibility

### Application Deployment

- **Image Automation**: Use `spec.values.image` in HelmRelease (not `values.yaml`) for Flux Image Automation markers
  - This ensures only changes to the specific app's helmrelease.yaml trigger reconciliation
  - Prevents unnecessary reconciliation of all apps when one app updates
- **Secrets**: registry-credentials secret required for Flux to scan private registry
- **Versioning**: GitHub Actions uses clean semver tags (`1.0.X`), no git hash suffixes

### Platform Services with Traefik IngressRoute

When exposing platform services with Traefik IngressRoute and Authelia:

- **TLS Certificates**: Cert-manager doesn't auto-create certificates from IngressRoute annotations. Always create an explicit Certificate resource.
- **Middleware Namespaces**: Traefik requires middlewares to be in the same namespace as the IngressRoute. Create namespace-local copies of the authelia-forwardauth middleware.
- **Pattern**: See `platform/longhorn-dashboard/` for reference implementation

### GitHub

Infrastructure deployments require approval. Provide approval by replying "LGTM" to the open GitHub issue. IMPORTANT: verify that Terraform plans will not destroy persistent block storage by inspecting the workflow first.

## Important Instructions

- Keep documentation concise and to the point.
- NEVER worry about backwards compatibility or deleting old pods.
- Be frugal with tokens.
- Run `flux reconcile` commands with a timeout so you aren't blocked by their completion. Then, check the logs.
