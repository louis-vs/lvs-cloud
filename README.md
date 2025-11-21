# LVS Cloud - Kubernetes Private Cloud

**Kubernetes-native private cloud** running on a single k3s node with enterprise GitOps patterns. Push code → Flux automatically deploys.

## Quick Status

| Service | URL | Status |
|---------|-----|--------|
| **Grafana** | <https://grafana.lvs.me.uk> | ✅ (admin/secure-pass) |
| **Authelia** | <https://auth.lvs.me.uk> | ✅ (SSO) |
| **Registry** | <https://registry.lvs.me.uk> | ✅ (robot_user) |
| **Ruby Demo** | <https://app.lvs.me.uk> | ✅ |

**Infrastructure:** Hetzner cx33 (4 vCPU, 8GB RAM) + 50GB block storage
**Total Cost:** ~€9.60/month (cx33 server + block storage)

## Architecture

```
Developer → Git Push
         ↓
   GitHub Actions (build + push image)
         ↓
   registry.lvs.me.uk/app:1.0.X
         ↓
   Flux ImageRepository (scans registry)
         ↓
   Flux ImagePolicy (selects latest tag)
         ↓
   Flux ImageUpdateAutomation (commits update)
         ↓
   Updates helmrelease.yaml spec.values.image.tag
         ↓
   Flux applies updated HelmRelease
         ↓
   k3s performs rolling update
         ↓
   Live app with TLS cert
```

**Stack:**

- **k3s**: Lightweight Kubernetes (weekly auto-upgrades)
- **Flux CD**: GitOps operator with image automation
- **Longhorn**: Distributed storage with S3 backups (Hetzner)
- **cert-manager**: Automated TLS certificates
- **PostgreSQL**: Bitnami Helm chart (Longhorn PVCs)
- **PGL Observability**: Prometheus + Grafana + Loki (metrics, dashboards, logs)
- **External Registry**: Docker + Caddy (outside cluster)

## Quick Commands

```bash
# Setup kubectl access (run once per session)
./scripts/connect-k8s.sh

# SSH to server
ssh ubuntu@$(dig +short app.lvs.me.uk)

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Monitor Flux
flux get all
flux logs --all-namespaces --follow

# Force reconciliation
flux reconcile source git monorepo
flux reconcile kustomization apps

# View application logs
kubectl logs -f -l app.kubernetes.io/name=ruby-demo-app

# Port-forward to services
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Kill kubectl tunnel if needed
pkill -f 'ssh.*6443:127.0.0.1:6443'
```

## Deployment Flow

**Code changes:**

1. Edit code in `applications/ruby-demo-app/`
2. Push to `master`
3. GitHub Actions builds image → pushes as `1.0.X`
4. Flux ImageRepository scans registry (every 1m)
5. Flux ImagePolicy selects latest semver tag
6. Flux ImageUpdateAutomation commits update to `helmrelease.yaml` spec.values.image.tag
7. Flux applies updated HelmRelease to cluster
8. K8s performs rolling update with health probes

**Infrastructure changes:**

1. Edit Terraform in `infrastructure/`
2. Push to `master`
3. GitHub Actions runs `terraform plan`
4. Reply "LGTM" to approval issue
5. If needed, Terraform recreates server with k3s
6. k3s SQLite datastore persists on block storage so the cluster state persists
7. Pods restart and reattach to persistent volumes

## Documentation

- **[infrastructure/bootstrap/BOOTSTRAP.md](infrastructure/bootstrap/BOOTSTRAP.md)**: Bootstrap guide (fresh cluster & server recreation)
- **[APPS.md](APPS.md)**: Adding apps, database setup, debugging
- **[DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)**: DR procedures and backup strategy

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <description>

Examples:
feat(platform): add new monitoring dashboard
fix(ruby-demo-app): resolve database connection issue
chore(infrastructure): upgrade k3s version
docs: update deployment guide
```

## Repository Structure

```
lvs-cloud/
├── clusters/prod/              # Flux entry point
├── infrastructure/
│   ├── main.tf                 # Hetzner + k3s
│   └── longhorn/               # Storage setup
├── platform/
│   ├── cert-manager/           # TLS automation
│   ├── postgresql-new/         # Database server
│   ├── flux-image-automation/  # Image policies
│   └── helmrepositories/       # Helm chart sources
├── applications/
│   └── ruby-demo-app/
│       ├── chart/              # Helm chart templates
│       ├── values.yaml         # App configuration
│       └── helmrelease.yaml    # Flux deployment + image automation
└── docs/                       # Documentation
```

## Local Development Requirements

**Required tools:**

```bash
# Install age (encryption) and sops (secret management)
brew install age sops

# Verify installations
age --version      # Should show 1.x.x
sops --version     # Should show 3.x.x
```

**Setup:**

1. Generate age keypair (one-time):

   ```bash
   age-keygen -o age.agekey
   mkdir -p ~/.config/sops/age
   cp age.agekey ~/.config/sops/age/keys.txt
   ```

2. **Important**: Backup `age.agekey` to your password manager - this key decrypts all secrets in the repository

3. The public key from `age.agekey` is already configured in `.sops.yaml`

## Getting Started

**After Terraform provisions:**

- Run `infrastructure/bootstrap/bootstrap.sh` - auto-detects fresh cluster vs server recreation
- Fresh cluster: full bootstrap (~30-45 min)
- Server recreation: verification only (~2-5 min)
