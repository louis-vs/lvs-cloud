# LVS Cloud — Personal Kubernetes Private Cloud

LVS Cloud is a **Kubernetes-native private cloud** running on a single k3s node and fully managed through GitOps. Push code → GitHub Actions builds → Flux deploys → Grafana monitors.

This README provides a basic overview. For detailed internal instructions, see the documentation referenced at the end, and the documentation within the different subfolders.

---

## **High-Level Architecture**

### Deployment Flow (GitOps)

```
Developer → Git Push
         ↓
   GitHub Actions builds & pushes image
         ↓
   registry.lvs.me.uk/app:1.0.X
         ↓
   Flux ImageRepository scans registry
   Flux ImagePolicy selects latest tag
   Flux ImageUpdateAutomation commits tag update
         ↓
   HelmRelease updated in Git
         ↓
   Flux applies changes to cluster
         ↓
   k3s performs rolling update
```

### Core Stack

* **k3s** — Lightweight Kubernetes with automated upgrades
* **Flux CD** — GitOps engine + image automation
* **Longhorn** — Persistent storage with S3 backups
* **cert-manager** — Automatic TLS
* **PostgreSQL** — Stateful DB with Longhorn PVCs
* **PGL** — Prometheus, Grafana, Loki (metrics, dashboards, logs)
* **External Registry** — Docker + Caddy for private images

---

## **Essential Commands**

```bash
# Authenticate kubectl (per session)
./scripts/connect-k8s.sh

# Cluster health
kubectl get nodes
kubectl get pods -A

# Flux status and logs
flux get all
flux logs --all-namespaces --follow

# Trigger reconciliation
flux reconcile source git monorepo
flux reconcile kustomization apps

# App logs (example)
kubectl logs -f -l app.kubernetes.io/name=ruby-demo-app
```

For service access via port-forward:

```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

---

## **Deployment Workflow**

### **Application changes**

1. Update code in `applications/<app>/`
2. Push to `master`
3. GitHub Actions builds an image and tags with `1.0.X`
4. Flux automation updates the HelmRelease
5. k3s rolls out the update automatically

### **Infrastructure changes**

1. Update Terraform files in `infrastructure/`
2. Push to `master`
3. GitHub Actions runs `terraform plan`
4. Approve by replying **LGTM** to the GitHub issue
5. Server may be recreated; k3s state persists on block storage

---

## **Repository Structure**

```
lvs-cloud/
├── clusters/prod/              # Flux entry point
├── infrastructure/             # Terraform + bootstrap
├── platform/                   # Core platform services
├── applications/               # User applications
└── docs/                       # Documentation set
```

---

## Local secret management

```bash
brew install age sops

age-keygen -o age.agekey
mkdir -p ~/.config/sops/age
cp age.agekey ~/.config/sops/age/keys.txt
```

Store `age.agekey` securely — it decrypts all secrets in the repo.

---

## **Further Documentation**

* **APPS.md** — Deploying apps, debugging, database usage
* **SECRETS.md** — Secrets management, SOPS, encryption
* **BOOTSTRAP.md** — Fresh cluster provisioning
* **DISASTER_RECOVERY.md** — Backup and restoration procedures
