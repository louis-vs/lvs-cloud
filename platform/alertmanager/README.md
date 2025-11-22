# Alertmanager Dashboard

Provides HTTPS ingress to Alertmanager web UI via Traefik.

## Service

- **Alertmanager UI**: Access to the Alertmanager deployed by kube-prometheus-stack
- **URL**: alertmanager.lvs.me.uk
- **Namespace**: platform

## Secrets

None (uses Alertmanager instance from monitoring stack)

## Configuration

- Protected by authelia-forwardauth middleware
- TLS certificate via cert-manager (letsencrypt)
- Standard Traefik IngressRoute pattern
