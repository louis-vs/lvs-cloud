# Flux Image Automation

Automatic image version updates via GitOps.

## Service

- **Flux Image Update Automation**: Scans registry and commits version updates
- **Namespace**: flux-system
- **Scan Interval**: 1 minute

## Secrets

- `registry-credentials`: For scanning private registry (created in secrets/)

## Configuration

- ImageUpdateAutomation: Auto-commits to applications/**/helmrelease.yaml
- ImageRepository: Per-application registry scanning
- ImagePolicy: Semver version selection (e.g., `>=1.0.0 <2.0.0`)
- Currently configured for ruby-demo-app
