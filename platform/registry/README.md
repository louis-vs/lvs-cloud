# Private Docker Registry

In-cluster Docker image registry for GitOps deployments.

## Service

- **Docker Registry**: Private container image storage
- **URL**: registry.lvs.me.uk
- **Namespace**: platform
- **Chart**: Custom local Helm chart (./chart)

## Secrets

- `registry-auth` (SOPS-encrypted): htpasswd for HTTP basic authentication

## Configuration

- Longhorn persistent storage for image layers
- TLS certificate via cert-manager (letsencrypt)
- HTTP basic authentication
- Used by GitHub Actions for pushing built images
- Used by Flux Image Automation for scanning versions
