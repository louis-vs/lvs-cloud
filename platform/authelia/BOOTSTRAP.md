# Authelia Bootstrap Guide

This guide covers the one-time setup required for Authelia to function.

## Prerequisites

- kubectl access configured (`./scripts/connect-k8s.sh`)
- PostgreSQL running in cluster

## Step 1: Create PostgreSQL Database and User

```bash
# Connect to cluster
./scripts/connect-k8s.sh

# Create database
kubectl exec -it postgresql-0 -- psql -U postgres -c "CREATE DATABASE authelia"

# Create user (replace with secure password)
kubectl exec -it postgresql-0 -- psql -U postgres -c "CREATE USER authelia WITH PASSWORD 'YOUR_SECURE_PASSWORD'"

# Grant permissions
kubectl exec -it postgresql-0 -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE authelia TO authelia"

# Grant schema permissions (PostgreSQL 15+)
kubectl exec -it postgresql-0 -- psql -U postgres -d authelia -c "GRANT ALL ON SCHEMA public TO authelia"
```

## Step 2: Generate Secrets

Generate random secrets for JWT, session encryption, and storage encryption:

```bash
# Generate three random 64-character strings
openssl rand -base64 48
openssl rand -base64 48
openssl rand -base64 48
```

Create the secrets in Kubernetes:

```bash
kubectl create secret generic authelia-secrets -n default \
  --from-literal=jwt-secret='FIRST_RANDOM_STRING' \
  --from-literal=session-secret='SECOND_RANDOM_STRING' \
  --from-literal=storage-encryption-key='THIRD_RANDOM_STRING'

kubectl create secret generic authelia-db -n default \
  --from-literal=password='YOUR_POSTGRES_PASSWORD'
```

## Step 3: Create OIDC Client Secret for Grafana

Generate a hashed password for the Grafana OIDC client:

```bash
# Generate random client secret
CLIENT_SECRET=$(openssl rand -base64 32)
echo "Save this for later: $CLIENT_SECRET"

# Hash it with Argon2 (using authelia container)
kubectl run -it --rm authelia-hash --image=ghcr.io/authelia/authelia:latest --restart=Never -- \
  authelia crypto hash generate argon2 --password "$CLIENT_SECRET"
```

Copy the Argon2 hash output and update the Grafana client_secret in `helmrelease.yaml`:

```yaml
identity_providers:
  oidc:
    clients:
      - client_id: grafana
        client_secret: "$argon2id$v=19$m=65536,t=3,p=4$YOUR_HASH_HERE"
```

Save the plaintext `$CLIENT_SECRET` - you'll need it for Grafana configuration.

Create the Grafana OAuth secret:

```bash
kubectl create secret generic grafana-oauth -n monitoring \
  --from-literal=oauth-client-secret="$CLIENT_SECRET"
```

## Step 4: Create Users Database

Create a ConfigMap with user definitions:

```bash
# Generate password hash for your user
kubectl run -it --rm authelia-hash --image=ghcr.io/authelia/authelia:latest --restart=Never -- \
  authelia crypto hash generate argon2 --password "YOUR_PASSWORD"
```

Create `users_database.yml`:

```yaml
users:
  admin:
    displayname: "Admin User"
    password: "$argon2id$v=19$m=65536,t=3,p=4$YOUR_HASH_HERE"
    email: admin@lvs.me.uk
    groups:
      - admins
```

Create the ConfigMap:

```bash
kubectl create configmap authelia-users -n default \
  --from-file=users_database.yml=users_database.yml
```

## Step 5: Deploy Authelia

Push the changes to trigger Flux deployment:

```bash
git add platform/authelia platform/helmrepositories/authelia.yaml platform/kustomization.yaml platform/helmrepositories/kustomization.yaml
git commit -m "feat(platform): add Authelia SSO authentication server"
git push
```

Monitor deployment:

```bash
flux reconcile source git monorepo
flux reconcile kustomization platform
kubectl get pods -l app.kubernetes.io/name=authelia -w
```

## Step 6: Add DNS Record

Add DNS A record: `auth.lvs.me.uk → server-ip`

```bash
# Get server IP
dig +short app.lvs.me.uk
```

## Verification

Check Authelia is running:

```bash
kubectl get pods -l app.kubernetes.io/name=authelia
kubectl logs -l app.kubernetes.io/name=authelia
```

Access Authelia: <https://auth.lvs.me.uk>

Try logging in with the user credentials you created.

## Troubleshooting

**Database connection errors:**

```bash
kubectl exec -it postgresql-0 -- psql -U authelia -d authelia -c "SELECT 1"
```

**Secret issues:**

```bash
kubectl get secret authelia-secrets -n default -o yaml
kubectl get secret authelia-db -n default -o yaml
```

**Pod logs:**

```bash
kubectl logs -l app.kubernetes.io/name=authelia --tail=100 -f
```
