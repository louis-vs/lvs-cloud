# Longhorn Dashboard

Provides HTTPS ingress to Longhorn web UI via Traefik.

## Service

- **Longhorn UI**: Access to the Longhorn storage management interface
- **URL**: longhorn.lvs.me.uk
- **Namespace**: longhorn-system

## Secrets

None (uses Longhorn instance from storage-install)

## Configuration

- Protected by authelia-forwardauth middleware
- TLS certificate via cert-manager (letsencrypt)
- Reference implementation for Traefik IngressRoute pattern
