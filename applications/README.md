# Applications

User-facing applications deployed on LVS Cloud.

## Application Catalog

- **ruby-demo-app**: Example Rails application demonstrating deployment patterns
- **vsmp-royalties**: VSMP royalty calculation service

## Deployment Pattern

All applications follow a consistent GitOps workflow:

- **CI/CD**: GitHub Actions builds and tests on push to master
- **Registry**: Docker images pushed to `registry.lvs.me.uk`
- **Automation**: Flux ImageRepository + ImagePolicy scan for new images
- **Deployment**: HelmRelease-based with centralized chart templates
- **Storage**: PostgreSQL for persistence, Longhorn for volumes
- **Networking**: Traefik ingress with automatic TLS via cert-manager
- **Authentication**: Authelia SSO via Traefik forwardAuth middleware

## Architecture Notes

Applications use:

- Multi-stage Dockerfiles with dedicated test targets
- Semantic versioning (1.0.{RUN_NUMBER})
- Automated testing with PostgreSQL service containers
- Helm charts with production values overrides
- Database credentials from shared PostgreSQL instance
- Environment variables for configuration

## Authentication

All applications require authentication via Authelia SSO. To enable authentication on a new application, add the forwardAuth middleware annotation to the HelmRelease:

```yaml
# applications/my-app/helmrelease.yaml
spec:
  values:
    ingress:
      annotations:
        traefik.ingress.kubernetes.io/router.middlewares: applications-authelia-forwardauth@kubernetescrd
```

See `../platform/authelia/README.md` for full middleware documentation.

## Further Reading

- **DEPLOYMENT.md** — Step-by-step deployment guide and reference
- **DEBUGGING.md** — Troubleshooting and debugging procedures
- **../SECRETS.md** — Secrets management patterns
- **ruby-demo-app/** — Working reference implementation
