# cert-manager Installation

TLS certificate automation via Let's Encrypt.

## Service

- **cert-manager**: Kubernetes certificate management controller
- **Namespace**: cert-manager
- **Chart**: Jetstack Helm repository

## Secrets

None

## Configuration

- Installs CRDs automatically
- Provides Certificate, ClusterIssuer, and Issuer resources
- Integrates with Let's Encrypt for automated TLS
- Used by all platform ingresses for HTTPS
