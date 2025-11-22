# Platform Services

Core infrastructure services for LVS Cloud, deployed via Flux CD.

## Service Categories

### Authentication & Security

- **authelia**: SSO authentication server with OIDC support
- **cert-manager-install**: TLS certificate automation via Let's Encrypt
- **cert-manager-config**: ClusterIssuer configurations for cert-manager

### Storage & Databases

- **storage-install**: Longhorn distributed storage system
- **storage-config**: Longhorn recurring job configurations
- **postgresql**: Shared PostgreSQL database server
- **redis**: Redis in-memory database for sessions
- **registry**: Private Docker registry

### Monitoring & Observability

- **monitoring**: Complete PGL stack (Prometheus, Grafana, Loki)
- **alertmanager**: Alertmanager web UI access
- **longhorn-dashboard**: Longhorn web UI access
- **traefik-dashboard**: Traefik web UI access

### GitOps & Automation

- **flux-image-automation**: Flux Image Update Automation
- **helmrepositories**: HelmRepository CRDs for Flux

### Platform Foundation

- **namespaces**: Namespace definitions (platform, applications)
- **secrets**: SOPS-encrypted secrets repository
- **k3s-backup**: k3s SQLite database backup to S3

## Architecture Notes

All services use:

- Traefik for ingress with TLS via cert-manager
- Authelia for SSO authentication on dashboards
- Longhorn for persistent storage
- SOPS with age encryption for secrets
