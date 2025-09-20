# Monitoring Stack - GitOps Deployment

Modern observability stack with LGTM (Loki, Grafana, Tempo, Mimir) architecture and automated CI/CD deployment.

## Architecture Overview

```plaintext
┌─────────────────────────────────────────────────────────────────┐
│                        External Access                          │
├─────────────────────────────────────────────────────────────────┤
│  Internet → Traefik → Grafana (grafana.lvs.me.uk)             │
│                          │                                      │
│                          ▼                                      │
├─────────────────────────────────────────────────────────────────┤
│                    Internal Monitoring Network                  │
├─────────────────────────────────────────────────────────────────┤
│  Applications  →  Alloy  → ┌─ Loki (logs)                      │
│  (stdout logs)              ├─ Mimir (metrics)                  │
│  (OpenTelemetry)            └─ Tempo (traces)                   │
│                                      │                          │
│                              Grafana queries all ↑             │
└─────────────────────────────────────────────────────────────────┘
```

## Services Deployed

### Externally Accessible

- **Grafana**: Unified monitoring dashboard at `grafana.lvs.me.uk`
- **Registry**: Container registry at `registry.lvs.me.uk`

### Internal Services (Docker Network Only)

- **Loki**: Log aggregation and storage
- **Tempo**: Distributed tracing storage
- **Mimir**: Metrics storage and querying
- **Alloy**: Universal observability collector
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

### External Access

- **Grafana**: <https://grafana.lvs.me.uk> (admin/[secure-password])
  - Unified interface for logs, metrics, and traces
  - Pre-configured dashboards for system and application monitoring
- **Registry**: <https://registry.lvs.me.uk> (admin/[secure-password])
  - Container image storage and distribution

### Internal Access (Docker Network Only)

- **Loki**: `http://loki:3100` - Log aggregation API
- **Tempo**: `http://tempo:3200` - Distributed tracing API
- **Mimir**: `http://mimir:8080` - Metrics storage API
- **Alloy**: `http://alloy:12345` - Observability collector

## Security

- **External services**: Behind Traefik with automatic HTTPS and Let's Encrypt
- **Internal services**: Isolated on Docker monitoring network
- **Authentication**: HTTP basic auth for registry, built-in auth for Grafana
- **Network isolation**: Applications and monitoring services on separate networks
- **Security updates**: Managed through automated GitHub Actions deployments

## Observability Data Flow

### Logs (12-Factor App Compliant)

```plaintext
Applications → stdout → Docker → Alloy → Loki → Grafana
```

### Metrics

```plaintext
System: Node Exporter → Alloy → Mimir → Grafana
Apps: OpenTelemetry → Tempo → span metrics → Mimir → Grafana
```

### Traces

```plaintext
Applications → OpenTelemetry → Tempo → Grafana
```

## Key Features

- **Unified observability**: Single Grafana interface for all telemetry data
- **Auto-discovery**: Alloy automatically discovers and monitors Docker containers
- **Structured logging**: JSON log parsing with metadata extraction
- **Trace correlation**: Request IDs link logs, metrics, and traces
- **12-factor compliance**: Applications log only to stdout
