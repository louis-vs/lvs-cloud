# k3s Setup Guide

## Overview

k3s is a lightweight Kubernetes distribution designed for resource-constrained environments. Our setup runs on a single Hetzner cx22 node with automatic weekly upgrades.

## Installation (via cloud-init)

The Terraform `cloud-init.yml` handles k3s installation automatically. This section documents what happens for reference.

### 1. k3s Installation

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server' sh -
```

### 2. Registry Authentication

k3s needs credentials to pull from `registry.lvs.me.uk`. This is configured via `/etc/rancher/k3s/registries.yaml`:

```yaml
mirrors:
  "registry.lvs.me.uk":
    endpoint:
      - "https://registry.lvs.me.uk"
configs:
  "registry.lvs.me.uk":
    auth:
      username: robot_user
      password: "<plain-password>"
```

**Important**: This file must exist **before** k3s starts, or it won't trust the registry.

### 3. Traefik Ingress Controller

k3s ships with Traefik v2 as the default ingress controller. It listens on ports 80 and 443.

**Ingress Class**: `traefik`

**Example Ingress**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  ingressClassName: traefik
  tls:
    - hosts: ["app.lvs.me.uk"]
      secretName: app-tls
  rules:
    - host: app.lvs.me.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Weekly k3s Upgrades

### Systemd Timer Setup

Upgrades run every Sunday at 03:00 via systemd timer.

**Script**: `/usr/local/sbin/k3s-upgrade.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

NODE="$(hostname)"
kubectl cordon "$NODE" || true

INSTALL_K3S_CHANNEL="stable" \
curl -sfL https://get.k3s.io | sh -s - --force-reinstall

sleep 10
kubectl uncordon "$NODE" || true
```

**Service**: `/etc/systemd/system/k3s-upgrade.service`

```ini
[Unit]
Description=Weekly k3s upgrade

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/k3s-upgrade.sh
```

**Timer**: `/etc/systemd/system/k3s-upgrade.timer`

```ini
[Unit]
Description=Run k3s-upgrade weekly (Sun 03:00)

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Enable**:

```bash
systemctl enable --now k3s-upgrade.timer
```

## Accessing the Cluster

### From the Host

```bash
# kubectl is automatically available
kubectl get nodes
kubectl get pods -A
```

### From Your Local Machine

```bash
# Copy kubeconfig from server
scp ubuntu@app.lvs.me.uk:/etc/rancher/k3s/k3s.yaml ~/.kube/lvs-cloud.yaml

# Edit the file: replace 127.0.0.1 with app.lvs.me.uk
sed -i '' 's/127.0.0.1/app.lvs.me.uk/g' ~/.kube/lvs-cloud.yaml

# Use it
export KUBECONFIG=~/.kube/lvs-cloud.yaml
kubectl get nodes
```

**Note**: Port 6443 (Kubernetes API) is **not** exposed through the firewall for security. Use SSH tunnel if needed:

```bash
ssh -L 6443:localhost:6443 ubuntu@app.lvs.me.uk
# Then use kubeconfig with 127.0.0.1:6443
```

## Troubleshooting

### k3s Service Not Starting

```bash
# Check status
sudo systemctl status k3s

# View logs
sudo journalctl -u k3s -f

# Restart
sudo systemctl restart k3s
```

### Registry Pull Failures

```bash
# Test registry auth on host
ctr images pull registry.lvs.me.uk/ruby-demo-app:latest

# If fails, check registries.yaml
cat /etc/rancher/k3s/registries.yaml

# Verify registry is accessible
curl -u robot_user:<password> https://registry.lvs.me.uk/v2/_catalog
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -A

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace> -f

# Check node resources
kubectl top node
kubectl describe node
```

### Upgrade Failed

```bash
# Check timer status
systemctl status k3s-upgrade.timer

# View last upgrade logs
journalctl -u k3s-upgrade.service -n 100

# Manual upgrade
sudo /usr/local/sbin/k3s-upgrade.sh
```

## Configuration Files

### k3s Config Location

All k3s configuration lives in `/etc/rancher/k3s/`:

- `k3s.yaml`: Kubeconfig (admin credentials)
- `registries.yaml`: Private registry auth
- `config.yaml`: k3s server config (if needed)

### k3s Data Location

k3s stores cluster state in `/var/lib/rancher/k3s/`:

- `server/`: API server data, certificates
- `agent/`: Kubelet data, container runtime

**Important**: This is **ephemeral**. Only Longhorn PVCs and external registry are persistent.

## Resource Limits

### Single Node Capacity

- **CPU**: 2 vCPUs (cx22)
- **Memory**: 4GB RAM
- **Storage**: 50GB block volume (`/srv/data`)

### Typical Resource Allocation

```yaml
# Reserve for k3s system components
System:     ~500MB RAM, ~0.5 CPU

# Available for apps
Available:  ~3.5GB RAM, ~1.5 CPU

# Longhorn overhead
Longhorn:   ~200MB RAM, ~0.2 CPU
```

### Right-Sizing Apps

**Small app** (API, web server):

```yaml
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "1"
    memory: "1Gi"
```

**Database** (PostgreSQL):

```yaml
resources:
  requests:
    cpu: "300m"
    memory: "512Mi"
  limits:
    cpu: "1"
    memory: "2Gi"
```

## Next Steps

- [Flux Setup](FLUX_SETUP.md) - Bootstrap Flux GitOps
- [Storage Setup](STORAGE.md) - Configure Longhorn
- [Registry Setup](REGISTRY.md) - External registry with Caddy
