# Traefik Dashboard

Provides HTTPS ingress to Traefik web UI via IngressRoute.

## Service

- **Traefik UI**: Access to the Traefik dashboard
- **URL**: traefik.lvs.me.uk
- **Namespace**: kube-system

## Secrets

None (uses Traefik deployed by k3s)

## Configuration

- Protected by authelia-forwardauth middleware
- TLS certificate via cert-manager (letsencrypt)
- Standard Traefik IngressRoute pattern
