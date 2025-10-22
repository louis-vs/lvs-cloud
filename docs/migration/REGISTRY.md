# External Registry Setup

## Overview

The Docker Registry runs **outside the k3s cluster** on the host using Docker + Caddy. This avoids chicken-and-egg problems (registry needs to be up to pull images for the cluster).

## Architecture

```
Internet (HTTPS)
      ↓
Caddy (:443) - TLS via Let's Encrypt HTTP-01
      ↓
Docker Registry (localhost:5000)
      ↓
/srv/data/registry (persistent storage)
```

## Components

### Docker Registry

Standard Docker Registry v2 image running as a Docker container on the host.

**Configuration**:

- Listens on `127.0.0.1:5000` (localhost only)
- Data stored at `/srv/data/registry`
- No authentication (handled by Caddy frontend)

**Docker Compose** (for reference, cloud-init uses `docker run`):

```yaml
services:
  registry:
    image: registry:2
    restart: unless-stopped
    ports:
      - "127.0.0.1:5000:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
    volumes:
      - /srv/data/registry:/var/lib/registry
```

### Caddy (TLS Frontend)

Caddy provides HTTPS termination with automatic Let's Encrypt certificates and basic authentication.

**Caddyfile**: `/etc/caddy/Caddyfile`

```caddy
registry.lvs.me.uk {
  encode zstd gzip
  tls letsencrypt@lvs.me.uk

  @v2 {
    path_regexp v2 ^/v2/.*$
  }

  basicauth @v2 {
    robot_user <bcrypt-hash>
  }

  reverse_proxy localhost:5000
}
```

**Generate bcrypt hash**:

```bash
caddy hash-password --algorithm bcrypt
```

## k3s Integration

k3s needs to authenticate to the registry to pull images. Configure via `/etc/rancher/k3s/registries.yaml`:

```yaml
mirrors:
  "registry.lvs.me.uk":
    endpoint:
      - "https://registry.lvs.me.uk"
configs:
  "registry.lvs.me.uk":
    auth:
      username: robot_user
      password: "<plaintext-password>"
```

**Important**: This file must exist **before** k3s starts, or it won't trust the registry.

After creating/updating this file:

```bash
sudo systemctl restart k3s
```

### Test Registry Access from k3s

```bash
# On the k3s host
ctr images pull registry.lvs.me.uk/ruby-demo-app:latest

# Should succeed
```

## CI/CD Integration

### GitHub Actions Login

```yaml
- name: Login to registry
  run: |
    echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login registry.lvs.me.uk \
      -u robot_user --password-stdin
```

### Build and Push

```yaml
- name: Build and push image
  run: |
    docker build -t registry.lvs.me.uk/ruby-demo-app:${{ github.sha }} .
    docker tag registry.lvs.me.uk/ruby-demo-app:${{ github.sha }} \
               registry.lvs.me.uk/ruby-demo-app:1.2.3
    docker push registry.lvs.me.uk/ruby-demo-app:1.2.3
```

## Flux Integration

Flux needs read access to detect new tags. If your registry requires auth for tag listing, create a Kubernetes secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: flux-system
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "registry.lvs.me.uk": {
          "username": "robot_user",
          "password": "<password>",
          "auth": "<base64(username:password)>"
        }
      }
    }
```

Reference in ImageRepository:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: ruby-demo-app
  namespace: flux-system
spec:
  image: registry.lvs.me.uk/ruby-demo-app
  interval: 1m
  secretRef:
    name: registry-credentials  # Optional
```

## Operations

### Check Registry Status

```bash
# Docker container
docker ps | grep registry

# Caddy status
systemctl status caddy

# Test HTTPS
curl -I https://registry.lvs.me.uk/v2/
# Should return 401 Unauthorized (expected without auth)

# Test with auth
curl -u robot_user:<password> https://registry.lvs.me.uk/v2/_catalog
```

### List Images

```bash
# All repositories
curl -u robot_user:<password> https://registry.lvs.me.uk/v2/_catalog

# Tags for specific image
curl -u robot_user:<password> https://registry.lvs.me.uk/v2/ruby-demo-app/tags/list
```

### Delete Images

The Docker Registry API supports deletion, but it requires garbage collection afterward.

**1. Delete manifest**:

```bash
# Get digest
DIGEST=$(curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  -u robot_user:<password> \
  https://registry.lvs.me.uk/v2/ruby-demo-app/manifests/1.0.0 \
  | grep Docker-Content-Digest | awk '{print $2}')

# Delete
curl -X DELETE -u robot_user:<password> \
  https://registry.lvs.me.uk/v2/ruby-demo-app/manifests/$DIGEST
```

**2. Garbage collect** (run inside the registry container):

```bash
docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

### Registry Disk Usage

```bash
du -sh /srv/data/registry
```

### Backup Registry

The registry stores images as blobs in the filesystem. Back up the entire directory:

```bash
# On the host
tar -czf registry-backup-$(date +%Y%m%d).tar.gz -C /srv/data registry

# Download to local machine
scp ubuntu@app.lvs.me.uk:~/registry-backup-*.tar.gz ./
```

## Troubleshooting

### TLS Certificate Issues

```bash
# Check Caddy logs
journalctl -u caddy -f

# Verify certificate
openssl s_client -connect registry.lvs.me.uk:443 -servername registry.lvs.me.uk

# Manually trigger cert renewal
systemctl restart caddy
```

### Registry Not Responding

```bash
# Check Docker container
docker logs registry

# Restart registry
docker restart registry

# Check backend port
curl http://localhost:5000/v2/
```

### k3s Can't Pull Images

```bash
# Check registries.yaml
cat /etc/rancher/k3s/registries.yaml

# Test containerd pull
ctr images pull registry.lvs.me.uk/ruby-demo-app:latest

# Check k3s logs
journalctl -u k3s -f | grep registry
```

### Flux Can't List Tags

```bash
# Check ImageRepository status
kubectl -n flux-system get imagerepositories

# Describe for events
kubectl -n flux-system describe imagerepository ruby-demo-app

# Check image-reflector-controller logs
kubectl -n flux-system logs deploy/image-reflector-controller -f

# Test registry access from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
curl -u robot_user:<password> https://registry.lvs.me.uk/v2/_catalog
```

## Why External?

**Pros**:

- Avoids bootstrap chicken-and-egg (cluster needs registry to start, registry needs cluster to run)
- Simpler networking (no LoadBalancer or NodePort needed)
- Direct Docker push from CI (no Kubernetes involved)
- Persistent storage is just a directory (no PVC management)

**Cons**:

- Not managed by Flux (manual Caddy + Docker setup)
- Separate from cluster lifecycle

**Alternatives considered**:

- **Harbor**: Too heavy for single node
- **In-cluster Registry**: Chicken-and-egg problem
- **External service (Docker Hub, GHCR)**: Loses privacy, costs money

## Security Notes

- Basic auth over HTTPS (good enough for private cloud)
- Password stored in plain text in k3s registries.yaml (filesystem permissions protect it)
- Consider IP whitelisting in Caddy if you want to restrict access:

```caddy
registry.lvs.me.uk {
  @allowed {
    remote_ip 1.2.3.4  # Your CI runner IP
  }
  handle @allowed {
    # ... rest of config
  }
  handle {
    abort
  }
}
```

## Next Steps

- [Storage Setup](STORAGE.md) - Configure Longhorn for PVCs
- [Apps Migration](APPS.md) - Convert apps to Helm charts
