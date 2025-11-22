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

## ForwardAuth Middleware

This kustomization deploys the `authelia-forwardauth` middleware to multiple namespaces:

- **platform namespace** (`middleware-platform.yaml`): For platform services
- **applications namespace** (`middleware-applications.yaml`): For user applications

Applications and services reference the middleware using:

```yaml
middlewares:
  - name: authelia-forwardauth
    namespace: <same-namespace-as-ingressroute>
```

Both middlewares point to the Authelia service at `http://authelia.platform.svc.cluster.local/api/authz/forward-auth`.
