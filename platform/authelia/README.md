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

This kustomization deploys the `authelia-forwardauth` Traefik Middleware CRD to multiple namespaces:

- **platform namespace** (`middleware-platform.yaml`): For platform services
- **applications namespace** (`middleware-applications.yaml`): For user applications

All middlewares point to the Authelia service at `http://authelia.platform.svc.cluster.local/api/authz/forward-auth`.

### Usage: Traefik IngressRoute

For services using Traefik IngressRoute CRDs, reference the middleware by name (must be in same namespace):

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-service
  namespace: platform
spec:
  routes:
    - match: Host(`service.lvs.me.uk`)
      kind: Rule
      middlewares:
        - name: authelia-forwardauth
      services:
        - name: my-service
          port: 80
```

### Usage: Kubernetes Ingress

For applications using standard Kubernetes Ingress, add the middleware annotation to the **HelmRelease** inline values:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-app
  namespace: applications
spec:
  values:
    ingress:
      annotations:
        traefik.ingress.kubernetes.io/router.middlewares: applications-authelia-forwardauth@kubernetescrd
```

**Annotation format**: `<namespace>-<middleware-name>@kubernetescrd`

**Important**: Add annotations to `spec.values.ingress.annotations` in the HelmRelease, not just the chart's values.yaml, as inline values override valuesFiles.
