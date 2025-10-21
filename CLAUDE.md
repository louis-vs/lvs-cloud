# LVS Cloud - Private Cloud Infrastructure

## Vision

LVS Cloud is a **personal private cloud platform** that scales while being maintainable by a single developer. The system uses modern DevOps practices to seamlessly deploy and monitor applications with enterprise-grade observability at startup costs.

**Core Principles:**

- **Consolidated DevOps**: GitHub for CI/CD, Grafana for monitoring - everything in one place
- **Persistent Dashboards**: All Grafana dashboards persist to block storage for custom development
- **Maximum Reproducibility**: Infrastructure as code, minimal persistent state
- **Automatic Operations**: Push code → auto-build → auto-deploy → auto-monitor

## Current Architecture

**Infrastructure**: Hetzner Cloud (€9.89/month total)
**Stack**: LGTM (Loki + Grafana + Tempo + Mimir) + Traefik + Docker Registry
**Deployment**: GitHub Actions → Registry → Watchtower → Live Applications

## File Structure

```plaintext
├── README.md             # Status, quick commands, current state
├── DEPLOY.md             # App deployment, infrastructure setup
├── OPS.md                # Troubleshooting, monitoring, maintenance
├── infrastructure/       # Terraform for Hetzner Cloud
├── platform/             # Platform services (LGTM, Traefik, Registry)
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

### Database Development

- **Shared PostgreSQL**: All apps use the shared PostgreSQL server with per-app databases
- **Connection Pattern**: Use `DATABASE_URL=postgresql://app_user:${POSTGRES_APP_PASSWORD}@postgresql:5432/app_db`
- **Migrations**: Include migration commands in app startup for GitOps compatibility
- **Monitoring**: Database metrics automatically collected via Grafana Alloy
- **Documentation**: See POSTGRES.md for detailed database management procedures

### GitHub

Infrastructure deployments require approval. Provide approval by replying "LGTM" to the open GitHub issue. IMPORTANT: verify that Terraform plans will not destroy persistent block storage by inspecting the workflow first.

## Important Instructions

Keep documentation concise and to the point. NEVER worry about backwards compatibility. Be frugal with tokens.
