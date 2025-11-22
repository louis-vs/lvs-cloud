# cert-manager Configuration

ClusterIssuer configurations for cert-manager TLS certificate automation.

## Service

- **ClusterIssuers**: letsencrypt (production) and letsencrypt-staging
- **Challenge Type**: HTTP-01 via Traefik
- **Email**: <letsencrypt@lvs.me.uk>

## Secrets

None (ClusterIssuer creates its own ACME account secrets)

## Configuration

- Production issuer for live certificates
- Staging issuer for testing
- Both use Traefik ingress class for HTTP-01 challenge solver
