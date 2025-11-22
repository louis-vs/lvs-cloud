# Authelia

SSO authentication server with OIDC support for platform services.

## Service

- **Authelia**: Single sign-on and authentication
- **URL**: auth.lvs.me.uk
- **Namespace**: platform
- **Chart**: Authelia Helm repository

## Secrets

- `authelia` (SOPS-encrypted):
  - OIDC client secrets (Grafana)
  - OIDC HMAC key and RSA key
  - Session encryption key
  - PostgreSQL password
  - Redis password (empty - auth disabled)
  - JWT HMAC key for password reset

## Configuration

- File-based user authentication
- PostgreSQL for persistent storage
- Redis for session management
- OIDC provider for Grafana OAuth
- Requires authelia-users ConfigMap (managed separately)
