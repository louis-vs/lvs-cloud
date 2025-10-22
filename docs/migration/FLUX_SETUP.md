# Flux GitOps Setup

## Overview

Flux CD is a GitOps operator that keeps your Kubernetes cluster in sync with Git. It also automates image updates by watching your registry and committing tag bumps back to your repo.

## Architecture

```
GitHub (monorepo)
      ↓
GitRepository (Flux source)
      ↓
Kustomization (clusters/prod/)
      ├→ infrastructure/ (Longhorn)
      ├→ platform/ (cert-manager, PostgreSQL, LGTM)
      └→ applications/ (HelmReleases)
            ↓
ImageRepository (watches registry.lvs.me.uk/app)
      ↓
ImagePolicy (selects latest semver tag)
      ↓
ImageUpdateAutomation (commits tag to values.yaml)
      ↓
HelmRelease (reconciles updated chart)
```

## Bootstrap (via cloud-init)

The Terraform `cloud-init.yml` installs Flux automatically:

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | bash

# Apply Flux controllers
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

# Wait for controllers
kubectl -n flux-system rollout status deploy/source-controller
kubectl -n flux-system rollout status deploy/kustomize-controller
kubectl -n flux-system rollout status deploy/helm-controller
kubectl -n flux-system rollout status deploy/image-reflector-controller
kubectl -n flux-system rollout status deploy/image-automation-controller
```

## Git Authentication

Flux needs read/write access to your monorepo to commit image tag updates.

### SSH Deploy Key

Generate a read-write deploy key for GitHub:

```bash
ssh-keygen -t ed25519 -C "flux-bot@lvs.me.uk" -f flux-deploy-key
```

Add `flux-deploy-key.pub` to your GitHub repo as a **Deploy Key** with **write access**.

### Kubernetes Secret

Cloud-init creates this secret automatically:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: flux-git-ssh
  namespace: flux-system
type: kubernetes.io/ssh-auth
data:
  identity: <base64-encoded-private-key>
  known_hosts: <base64-encoded-github-known-hosts>
```

## GitRepository Source

Points Flux at your monorepo:

```yaml
# clusters/prod/sources.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: monorepo
  namespace: flux-system
spec:
  interval: 1m
  url: ssh://git@github.com/<your-org>/lvs-cloud.git
  ref:
    branch: main
  secretRef:
    name: flux-git-ssh
```

## Kustomizations (Deployment Overlays)

Kustomizations tell Flux **what** to deploy from the repo.

### Root Kustomization

```yaml
# clusters/prod/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: prod
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: monorepo
  path: ./clusters/prod
  prune: true
  wait: true
```

### Infrastructure Kustomization

```yaml
# clusters/prod/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: monorepo
  path: ./infrastructure
  prune: true
  wait: true
```

### Platform Kustomization

```yaml
# clusters/prod/platform.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: monorepo
  path: ./platform
  prune: true
  wait: true
  dependsOn:
    - name: infrastructure
```

### Applications Kustomization

```yaml
# clusters/prod/apps.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: monorepo
  path: ./applications
  prune: true
  wait: true
  dependsOn:
    - name: platform
```

## Image Automation

### ImageRepository

Watches your registry for new tags:

```yaml
# platform/flux-image-automation/ruby-demo-app.yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: ruby-demo-app
  namespace: flux-system
spec:
  image: registry.lvs.me.uk/ruby-demo-app
  interval: 1m
  secretRef:
    name: registry-credentials  # optional if registry needs auth for pulls
```

### ImagePolicy

Selects which tag to use (semver, regex, alphabetical):

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: ruby-demo-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: ruby-demo-app
  policy:
    semver:
      range: ">=1.0.0"  # Only tags matching semver >= 1.0.0
```

### ImageUpdateAutomation

Commits tag updates back to Git:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: monorepo-auto
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: monorepo
  git:
    checkout:
      ref:
        branch: main
    commit:
      authorName: flux-bot
      authorEmail: ci@lvs.me.uk
      messageTemplate: "chore: update images"
    push:
      branch: main
  update:
    strategy: Setters  # Uses marker comments in values files
```

## Image Setters in Values Files

Flux uses **marker comments** to know where to update image tags.

### Example: Helm Values

```yaml
# applications/ruby-demo-app/values.yaml
image:
  repository: registry.lvs.me.uk/ruby-demo-app   # {"$imagepolicy": "flux-system:ruby-demo-app:name"}
  tag: "1.0.0"                                    # {"$imagepolicy": "flux-system:ruby-demo-app:tag"}
  pullPolicy: IfNotPresent
```

**How it works**:

1. CI pushes `registry.lvs.me.uk/ruby-demo-app:1.2.3`
2. ImageRepository detects new tag
3. ImagePolicy selects `1.2.3` (matches semver range)
4. ImageUpdateAutomation finds marker comments
5. Updates `tag: "1.2.3"` in `values.yaml`
6. Commits to `main` with message "chore: update images"
7. GitRepository pulls latest commit
8. HelmRelease reconciles with new tag
9. Kubernetes rolls out new pod

## HelmRelease

Tells Flux to deploy a Helm chart:

```yaml
# applications/ruby-demo-app/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ruby-demo-app
  namespace: default
spec:
  interval: 2m
  chart:
    spec:
      chart: ./applications/ruby-demo-app/chart  # Path in Git
      sourceRef:
        kind: GitRepository
        name: monorepo
        namespace: flux-system
  values:
    # Inline values or reference external values.yaml
    replicaCount: 2
    image:
      repository: registry.lvs.me.uk/ruby-demo-app
      tag: "1.0.0"
```

Or use a separate values file:

```yaml
  valuesFrom:
    - kind: ConfigMap
      name: ruby-demo-app-values
```

## Monitoring Flux

### Check Reconciliation Status

```bash
# All Flux resources
flux get all

# Specific types
flux get sources git
flux get kustomizations
flux get helmreleases
flux get images all
```

### Watch for Errors

```bash
# Logs from controllers
flux logs --all-namespaces --follow

# Specific controller
kubectl -n flux-system logs deploy/source-controller -f
kubectl -n flux-system logs deploy/image-automation-controller -f
```

### Force Reconciliation

```bash
# Force Flux to check Git now
flux reconcile source git monorepo

# Force kustomization
flux reconcile kustomization apps

# Force HelmRelease
flux reconcile helmrelease ruby-demo-app -n default
```

### Suspend/Resume

```bash
# Suspend automation (useful for testing)
flux suspend image update monorepo-auto

# Resume
flux resume image update monorepo-auto
```

## Troubleshooting

### Flux Not Detecting New Images

```bash
# Check ImageRepository
flux get images repository

# Check logs
kubectl -n flux-system logs deploy/image-reflector-controller -f

# Verify registry is accessible from cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
apk add curl
curl -u robot_user:<password> https://registry.lvs.me.uk/v2/ruby-demo-app/tags/list
```

### Flux Not Committing Updates

```bash
# Check ImageUpdateAutomation status
flux get images update

# Check logs
kubectl -n flux-system logs deploy/image-automation-controller -f

# Verify SSH key has write access on GitHub
kubectl -n flux-system get secret flux-git-ssh -o yaml
```

### HelmRelease Failing

```bash
# Check HelmRelease status
flux get helmreleases -A

# Describe for events
kubectl describe helmrelease ruby-demo-app -n default

# Check helm-controller logs
kubectl -n flux-system logs deploy/helm-controller -f

# Manually render chart to test
helm template ./applications/ruby-demo-app/chart -f applications/ruby-demo-app/values.yaml
```

### Git Authentication Failed

```bash
# Test SSH key manually
kubectl -n flux-system get secret flux-git-ssh -o jsonpath='{.data.identity}' | base64 -d > /tmp/flux-key
chmod 600 /tmp/flux-key
ssh -i /tmp/flux-key git@github.com
# Should see: "Hi <org>/<repo>! You've successfully authenticated"
```

## Common Patterns

### Multiple Apps

Create one `ImageRepository`, `ImagePolicy`, and `ImageUpdateAutomation` per app:

```yaml
# platform/flux-image-automation/python-api.yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: python-api
  namespace: flux-system
spec:
  image: registry.lvs.me.uk/python-api
  interval: 1m
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: python-api
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: python-api
  policy:
    semver:
      range: ">=1.0.0"
```

Use the **same** `ImageUpdateAutomation` for all apps (it scans the whole repo for setter markers).

### Staging vs Production

Use separate namespaces and separate Flux Kustomizations:

```yaml
# clusters/staging/apps.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-staging
  namespace: flux-system
spec:
  targetNamespace: staging
  path: ./applications
  ...
```

## Next Steps

- [Storage Setup](STORAGE.md) - Configure Longhorn for PVCs
- [Apps Migration](APPS.md) - Convert apps to Helm charts
