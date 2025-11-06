# Authelia Bootstrap Guide

Complete setup instructions for Authelia SSO authentication server.

## Prerequisites

- kubectl access configured (`./scripts/connect-k8s.sh`)
- PostgreSQL running in cluster
- Redis will be deployed automatically

## Step 1: Create PostgreSQL Database

```bash
# Connect to cluster
./scripts/connect-k8s.sh

# Create database
kubectl exec -it postgresql-0 -- psql -U postgres -c "CREATE DATABASE authelia"

# Create user with secure password
kubectl exec -it postgresql-0 -- psql -U postgres -c "CREATE USER authelia WITH PASSWORD 'YOUR_SECURE_PASSWORD'"

# Grant permissions
kubectl exec -it postgresql-0 -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE authelia TO authelia"

# Grant schema permissions (PostgreSQL 15+)
kubectl exec -it postgresql-0 -- psql -U postgres -d authelia -c "GRANT ALL ON SCHEMA public TO authelia"
```

## Step 2: Generate Encryption Keys

Generate random 64+ character alphanumeric strings for encryption:

```bash
# Generate storage encryption key
openssl rand -base64 48

# Generate session encryption key
openssl rand -base64 48

# Generate OIDC HMAC secret
openssl rand -base64 48
```

## Step 3: Generate RSA Key for OIDC

Authelia requires an RSA private key for signing OIDC JWTs:

```bash
# Generate 2048-bit RSA private key
openssl genrsa -out oidc-rsa.key 2048

# View the key (you'll need to paste this into the secret)
cat oidc-rsa.key
```

## Step 4: Generate OIDC Client Secret for Grafana

```bash
# Generate random client secret
GRAFANA_CLIENT_SECRET=$(openssl rand -base64 32)
echo "Save this for Grafana configuration: $GRAFANA_CLIENT_SECRET"

# Hash it with pbkdf2 for Authelia
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate pbkdf2 --password "$GRAFANA_CLIENT_SECRET"

# Save the hash output (starts with $pbkdf2-sha512$...)
```

## Step 5: Create Kubernetes Secrets

Create the main Authelia secret with all required keys:

```bash
# Create secret file
cat > authelia-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: authelia
  namespace: default
type: Opaque
stringData:
  # Storage
  storage.encryption.key: "PASTE_STORAGE_ENCRYPTION_KEY_HERE"
  storage.postgres.password.txt: "YOUR_POSTGRES_PASSWORD"

  # Session
  session.encryption.key: "PASTE_SESSION_ENCRYPTION_KEY_HERE"

  # OIDC
  identity_providers.oidc.hmac.key: "PASTE_OIDC_HMAC_SECRET_HERE"
  identity_providers.oidc.clients.grafana.secret.txt: "PASTE_PBKDF2_HASH_HERE"
  oidc.rsa.key: |
    -----BEGIN RSA PRIVATE KEY-----
    PASTE_RSA_PRIVATE_KEY_HERE
    -----END RSA PRIVATE KEY-----
EOF

# Apply the secret
kubectl apply -f authelia-secret.yaml

# Clean up the file
rm authelia-secret.yaml
```

## Step 6: Create Users Database

Generate password hashes for users:

```bash
# Generate password hash for a user
docker run --rm -it authelia/authelia:latest \
  authelia crypto hash generate argon2 --password "YOUR_PASSWORD"

# Save the hash (starts with $argon2id$...)
```

Create the users ConfigMap:

```bash
cat > users-database.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: authelia-users
  namespace: default
data:
  users_database.yml: |
    users:
      admin:
        disabled: false
        displayname: "Administrator"
        password: "\$argon2id\$v=19\$m=65536,t=3,p=4\$PASTE_HASH_HERE"
        email: "admin@lvs.me.uk"
        groups:
          - admins

      # Add more users as needed
      # user1:
      #   disabled: false
      #   displayname: "User One"
      #   password: "\$argon2id\$v=19\$m=65536,t=3,p=4\$HASH"
      #   email: "user1@lvs.me.uk"
      #   groups:
      #     - users
EOF

# Apply the ConfigMap
kubectl apply -f users-database.yaml

# Clean up
rm users-database.yaml
```

## Step 7: Create Grafana OAuth Secret

```bash
# Using the plaintext client secret from Step 4
kubectl create secret generic grafana-oauth -n monitoring \
  --from-literal=oauth-client-secret="$GRAFANA_CLIENT_SECRET"
```

## Step 8: Add DNS Record

Add DNS A record pointing to your server IP:

```bash
# Get server IP
dig +short app.lvs.me.uk

# Add DNS record:
# auth.lvs.me.uk → <server-ip>
```

## Step 9: Deploy via Flux

The deployment happens automatically via Flux once secrets are created:

```bash
# Force reconciliation
flux reconcile source git monorepo
flux reconcile kustomization flux-system

# Monitor deployment
kubectl get pods -l app.kubernetes.io/name=authelia -w
```

## Step 10: Verify Deployment

```bash
# Check Authelia pod status
kubectl get pods -n default | grep authelia

# Check logs
kubectl logs -f -l app.kubernetes.io/name=authelia

# Check Redis connectivity
kubectl exec -it deployment/authelia -- sh -c 'redis-cli -h redis-master ping'

# Check PostgreSQL connectivity
kubectl exec -it deployment/authelia -- sh -c 'psql -h postgresql -U authelia -d authelia -c "SELECT 1"'
```

## Step 11: Test Authentication

1. Navigate to <https://auth.lvs.me.uk>
2. Login with the admin credentials you created
3. Complete 2FA setup (TOTP)
4. Navigate to <https://grafana.lvs.me.uk>
5. Click "Sign in with Authelia" (if OIDC configured)

## Troubleshooting

**Pod not starting:**

```bash
kubectl describe pod -l app.kubernetes.io/name=authelia
kubectl logs -l app.kubernetes.io/name=authelia
```

**Database connection errors:**

```bash
kubectl exec -it postgresql-0 -- psql -U authelia -d authelia -c "SELECT 1"
```

**Redis connection errors:**

```bash
kubectl exec -it deployment/redis -- redis-cli ping
```

**Secret issues:**

```bash
kubectl get secret authelia -n default -o yaml
kubectl get secret grafana-oauth -n monitoring -o yaml
```

**OIDC not working:**

- Verify client secret hash matches
- Check Grafana logs: `kubectl logs -l app.kubernetes.io/name=grafana -n monitoring`
- Verify redirect URI exactly matches: `https://grafana.lvs.me.uk/login/generic_oauth`

## Security Notes

1. **Store secrets securely**: Consider using a secret management tool for production
2. **Backup secrets**: Secrets are not backed up by Longhorn
3. **Password policy**: Argon2id uses 64MB RAM per login - ensure adequate resources
4. **2FA required**: Policy set to `two_factor` for all protected domains
5. **Rate limiting**: 3 attempts, 2-minute find time, 5-minute ban time

## Adding Protected Services

To protect any service with Authelia SSO:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`my-app.lvs.me.uk`)
      kind: Rule
      middlewares:
        - name: authelia-forwardauth  # Add this middleware
      services:
        - name: my-app
          port: 80
  tls:
    secretName: my-app-tls
```
