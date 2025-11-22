# Monitoring Stack (PGL)

Complete observability stack: Prometheus, Grafana, Loki.

## Services

- **Grafana**: Metrics visualization and dashboards (grafana.lvs.me.uk)
- **Prometheus**: Metrics collection and storage (3-day retention)
- **Loki**: Log aggregation
- **Alertmanager**: Alert routing and notifications
- **Promtail**: Log collection agent
- **Pushgateway**: Batch job metrics
- **Namespace**: platform
- **Chart**: kube-prometheus-stack (Prometheus Community)

## Secrets

- `grafana-admin` (SOPS-encrypted): Admin username and password
- `grafana-oauth` (SOPS-encrypted): OAuth client secret for Authelia OIDC

## Configuration

- Grafana: Authelia OIDC authentication, persistent dashboards (8Gi Longhorn)
- Prometheus: 8Gi Longhorn storage, 3-day retention
- Alertmanager: Email notifications configured
- Custom alert rules for platform services
- S3 metrics collector for backup monitoring
