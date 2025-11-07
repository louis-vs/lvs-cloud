# Authelia Bootstrap Guide

SSO authentication server with OIDC support for Grafana.

## Prerequisites

- kubectl access configured (`./scripts/connect-k8s.sh`)
- PostgreSQL and Redis running in cluster
- Grafana deployed

## 1. Create PostgreSQL Database

```bash
./scripts/connect-k8s.sh

kubectl exec -it postgresql-0 -- psql -U postgres -c "CREATE DATABASE authelia"
kubectl exec -it postgresql-0 -- psql -U postgres -c "CREATE USER authelia WITH PASSWORD 'YOUR_SECURE_PASSWORD'"
kubectl exec -it postgresql-0 -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE authelia TO authelia"
kubectl exec -it postgresql-0 -- psql -U postgres -d authelia -c "GRANT ALL ON SCHEMA public TO authelia"
```

## 2. Generate Secrets

```bash
# Encryption keys (64+ chars)
openssl rand -base64 48  # storage.encryption.key
openssl rand -base64 48  # session.encryption.key
openssl rand -base64 48  # identity_providers.oidc.hmac.key

# RSA key for OIDC JWT signing
openssl genrsa -out oidc-rsa.key 2048

# Grafana OIDC client secret
GRAFANA_CLIENT_SECRET=$(openssl rand -base64 32)
echo "Plaintext (for Grafana): $GRAFANA_CLIENT_SECRET"

# Hash for Authelia
kubectl run -it --rm authelia-hash --image=ghcr.io/authelia/authelia:latest --restart=Never -- \
  authelia crypto hash generate pbkdf2 --password "$GRAFANA_CLIENT_SECRET"
```

## 3. Create Kubernetes Secrets

```bash
cat > authelia-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: authelia
  namespace: default
type: Opaque
stringData:
  storage.encryption.key: "PASTE_KEY_HERE"
  storage.postgres.password.txt: "YOUR_POSTGRES_PASSWORD"
  session.encryption.key: "PASTE_KEY_HERE"
  identity_providers.oidc.hmac.key: "PASTE_KEY_HERE"
  identity_providers.oidc.clients.grafana.secret.txt: "PASTE_PBKDF2_HASH_HERE"
  oidc.rsa.key: |
    -----BEGIN RSA PRIVATE KEY-----
    PASTE_RSA_KEY_HERE
    -----END RSA PRIVATE KEY-----
EOF

kubectl apply -f authelia-secret.yaml
rm authelia-secret.yaml

kubectl create secret generic grafana-oauth -n monitoring \
  --from-literal=oauth-client-secret="$GRAFANA_CLIENT_SECRET"
```

## 4. Create Users

```bash
# Generate password hash
docker run --rm -it authelia/authelia:latest \
  authelia crypto hash generate argon2 --password "YOUR_PASSWORD"

cat > users-database.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: authelia-users
  namespace: default
data:
  users_database.yml: |
    users:
      lvs:
        disabled: false
        displayname: "Louis"
        password: "\$argon2id\$v=19\$m=65536,t=3,p=4\$PASTE_HASH_HERE"
        email: "louis@lvs.me.uk"
        groups:
          - admins
EOF

kubectl apply -f users-database.yaml
rm users-database.yaml
```

## 5. Add DNS Record

```bash
# Add DNS A record: auth.lvs.me.uk → $(dig +short app.lvs.me.uk)
```

## 6. Deploy and Verify

```bash
flux reconcile source git monorepo
flux reconcile kustomization authelia

kubectl get pods -l app.kubernetes.io/name=authelia -w

# Test
# 1. Navigate to https://auth.lvs.me.uk
# 2. Login and complete 2FA setup (TOTP)
# 3. Navigate to https://grafana.lvs.me.uk
# 4. Click "Sign in with Authelia"
```

## Troubleshooting

```bash
# Pod issues
kubectl describe pod -l app.kubernetes.io/name=authelia
kubectl logs -l app.kubernetes.io/name=authelia

# Database connectivity
kubectl exec -it postgresql-0 -- psql -U authelia -d authelia -c "SELECT 1"

# Redis connectivity
kubectl exec -it deployment/redis -- redis-cli ping

# OIDC issues
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring
# Verify redirect URI: https://grafana.lvs.me.uk/login/generic_oauth
```

## Security Notes

- Secrets are not backed up by Longhorn
- Argon2id uses 64MB RAM per login
- 2FA required for all protected domains
- Rate limiting: 3 attempts, 2-minute find time, 5-minute ban time

## Managing Users

### Adding New Users

**Automated Script (Recommended):**

```bash
./scripts/add-authelia-user.sh
```

**Manual Process:**

```bash
# 1. Generate password hash
kubectl run -it --rm authelia-hash --image=ghcr.io/authelia/authelia:latest --restart=Never -- \
  authelia crypto hash generate argon2 --password "user_password"

# 2. Edit ConfigMap
kubectl edit configmap authelia-users -n default

# Add new user to users_database.yml:
#   newuser:
#     disabled: false
#     displayname: "New User"
#     password: "$argon2id$v=19$m=65536,t=3,p=4$..."
#     email: "user@example.com"
#     groups:
#       - developers

# 3. Changes auto-reload within 5 minutes
# Or force immediate reload:
kubectl rollout restart deployment/authelia
```

### Removing Users

```bash
kubectl edit configmap authelia-users -n default
# Remove user entry or set disabled: true
```

### Resetting Passwords

```bash
# Generate new hash
kubectl run -it --rm authelia-hash --image=ghcr.io/authelia/authelia:latest --restart=Never -- \
  authelia crypto hash generate argon2 --password "new_password"

# Update user's password field in ConfigMap
kubectl edit configmap authelia-users -n default
```

### User Self-Registration

File-based authentication **does not support self-registration**. For self-registration, you would need:

- **LDAP backend** with registration features (e.g., FreeIPA, OpenLDAP with self-service)
- **External user portal** that writes to LDAP
- **Database backend** (not currently supported by Authelia)

For a personal cloud with few users, file-based management is simpler and more secure than implementing self-registration.
