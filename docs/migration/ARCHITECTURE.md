# New Architecture Overview

## Vision

LVS Cloud v2 is a **Kubernetes-native private cloud** running on a single k3s node with enterprise GitOps patterns. The system eliminates manual deployments entirely—push code with a semver tag, and Flux automatically updates manifests and deploys.

## Core Stack

**Infrastructure**

- **k3s**: Lightweight Kubernetes (single node, weekly auto-upgrades)
- **Longhorn**: Distributed storage with S3 backups to Hetzner Object Storage
- **Hetzner Cloud**: cx22 server (2 vCPU, 4GB RAM) + 50GB block volume

**GitOps & Registry**

- **Flux CD**: GitOps operator with Image Automation
- **External Registry**: Docker Registry + Caddy (TLS via Let's Encrypt HTTP-01)
- **GitHub Actions**: Build images, push with semver tags

**Platform Services**

- **cert-manager**: Automated TLS for all apps (HTTP-01 challenge)
- **PostgreSQL**: Bitnami Helm chart with Longhorn PVCs
- **LGTM Stack**: Loki + Grafana + Tempo + Mimir (full observability)
- **Traefik**: Ingress controller (bundled with k3s)

## Deployment Flow

```
Developer → Git Push (code change)
                ↓
         GitHub Actions
            (build image)
                ↓
    registry.lvs.me.uk/app:1.2.3
                ↓
         Flux ImageRepository
          (detects new tag)
                ↓
        Flux ImagePolicy
         (selects latest semver)
                ↓
    ImageUpdateAutomation
    (commits tag to values.yaml)
                ↓
         Flux HelmRelease
         (reconciles Helm chart)
                ↓
        Kubernetes Deployment
         (rolling update with probes)
                ↓
            Live App
    (accessible via Ingress + TLS)
```

## Storage Architecture

### Longhorn (Distributed Block Storage)

- **Path**: `/srv/data/longhorn` on host
- **PVCs**: Apps request storage via `storageClassName: longhorn`
- **Backups**: Weekly volume backups to Hetzner S3 (automated)
- **Snapshots**: Daily snapshots (7 day retention)

### External Registry

- **Path**: `/srv/data/registry` on host (outside k3s)
- **Frontend**: Caddy with HTTP-01 Let's Encrypt
- **Backend**: Docker Registry on localhost:5000
- **Auth**: Basic auth (robot_user)

## Key Differences from v1

| Aspect | v1 (Docker Compose) | v2 (Kubernetes) |
|--------|---------------------|-----------------|
| **Orchestration** | docker-compose | k3s (Kubernetes) |
| **Deployments** | SSH + deploy.sh scripts | Flux GitOps (automated) |
| **Updates** | Watchtower polling | Flux Image Automation + commit |
| **Storage** | Docker volumes at `/mnt/data` | Longhorn PVCs at `/srv/data` |
| **Registry** | docker-compose + Traefik | Docker + Caddy (external) |
| **TLS** | Traefik cert resolver | cert-manager ClusterIssuer |
| **App Packaging** | docker-compose.yml | Helm charts with values |
| **CI/CD Complexity** | SSH, SCP, deploy.sh | Build + push (Flux does rest) |

## Repository Structure

```
lvs-cloud/
├── clusters/
│   └── prod/
│       ├── kustomization.yaml       # Root Flux entry point
│       ├── sources.yaml             # GitRepository, HelmRepositories
│       ├── infrastructure.yaml      # Longhorn, storage
│       ├── platform.yaml            # cert-manager, PostgreSQL, LGTM
│       └── apps.yaml                # Application HelmReleases
│
├── infrastructure/
│   ├── main.tf                      # Hetzner + k3s via cloud-init
│   ├── cloud-init.yml               # k3s + Flux bootstrap + Caddy
│   └── longhorn/
│       ├── helmrelease.yaml
│       ├── backup-secret.yaml
│       └── recurring-jobs.yaml
│
├── platform/
│   ├── helmrepositories/
│   │   ├── bitnami.yaml
│   │   ├── jetstack.yaml
│   │   └── longhorn.yaml
│   ├── cert-manager/
│   │   ├── helmrelease.yaml
│   │   └── clusterissuers.yaml
│   ├── postgresql/
│   │   ├── helmrelease.yaml
│   │   ├── secret-auth.yaml
│   │   └── cronjob-pgdump.yaml
│   ├── monitoring/
│   │   └── [LGTM stack manifests]
│   └── flux-image-automation/
│       └── [Per-app ImageRepository, ImagePolicy, ImageUpdateAutomation]
│
└── applications/
    └── ruby-demo-app/
        ├── chart/
        │   ├── Chart.yaml
        │   ├── values.yaml
        │   └── templates/
        │       ├── deployment.yaml
        │       ├── service.yaml
        │       └── ingress.yaml
        ├── values.yaml              # With Flux image setters
        └── helmrelease.yaml
```

## Operational Patterns

### Adding a New App

1. Create Helm chart in `applications/my-app/chart/`
2. Add `values.yaml` with Flux image setter comments
3. Create `helmrelease.yaml` pointing to chart
4. Add `ImageRepository` + `ImagePolicy` + `ImageUpdateAutomation` in `platform/flux-image-automation/`
5. Push to GitHub → Flux deploys

### Updating an App

1. Change code
2. Push to GitHub → CI builds + tags image (e.g., v1.2.3)
3. Flux detects new tag → updates values.yaml → commits
4. HelmRelease reconciles → rolling update

### Infrastructure Changes

1. Edit Terraform in `infrastructure/`
2. Push to GitHub → Actions runs plan
3. Reply "LGTM" to approval issue
4. Terraform applies → server recreated with k3s + Flux
5. Flux auto-deploys everything from Git

## Observability

**Grafana** (<https://grafana.lvs.me.uk>)

- Dashboards for all services (persisted to Longhorn PVC)
- Metrics via Mimir (scraped by Alloy)
- Logs via Loki (collected by Alloy)
- Traces via Tempo (OTLP endpoint)

**Kubernetes-Native Monitoring**

- `kubectl top nodes` / `kubectl top pods`
- `kubectl describe pod <name>`
- `kubectl logs <pod> -f`

## Security

- SSH key authentication only
- Registry: Basic auth over HTTPS
- Apps: TLS via cert-manager (automatic renewal)
- k3s: Ingress firewall (80, 443, 22 only)
- Secrets: Kubernetes Secrets (managed by Flux from GitHub Secrets via Terraform)

## Cost

- **Hetzner cx22**: €4.90/month
- **Object Storage**: €4.99/month (Terraform state + Longhorn backups)
- **Total**: €9.89/month
