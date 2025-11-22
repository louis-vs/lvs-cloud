# Platform development

## Platform Services with Traefik IngressRoute

When exposing platform services with Traefik IngressRoute and Authelia:

- **TLS Certificates**: Cert-manager doesn't auto-create certificates from IngressRoute annotations. Always create an explicit Certificate resource.
- **Middleware Namespaces**: Traefik requires middlewares to be in the same namespace as the IngressRoute. Create namespace-local copies of the authelia-forwardauth middleware.
- **Pattern**: See `platform/longhorn-dashboard/` for reference implementation

## Documentation

- Update [README](./README.md) when adding or removing platform services.
- All subfolders should have a README.md file.
