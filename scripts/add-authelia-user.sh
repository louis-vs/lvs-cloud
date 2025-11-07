#!/bin/bash
set -e

# Authelia User Management Script
# Adds a new user to the file-based authentication backend

echo "=== Authelia User Management ==="
echo

# Check kubectl connection
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: kubectl not connected. Run ./scripts/connect-k8s.sh first."
    exit 1
fi

# Get user details
read -p "Username (e.g., 'alice'): " USERNAME
read -p "Display Name (e.g., 'Alice Smith'): " DISPLAYNAME
read -p "Email: " EMAIL
read -s -p "Password: " PASSWORD
echo
read -s -p "Confirm Password: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "Error: Passwords don't match"
    exit 1
fi

read -p "Groups (comma-separated, e.g., 'admins,developers'): " GROUPS_INPUT
echo

# Convert comma-separated groups to YAML array format
IFS=',' read -ra GROUPS_ARRAY <<< "$GROUPS_INPUT"
GROUPS_YAML=""
for group in "${GROUPS_ARRAY[@]}"; do
    group=$(echo "$group" | xargs) # trim whitespace
    GROUPS_YAML="${GROUPS_YAML}          - ${group}\n"
done

echo "Generating Argon2id password hash..."
PASSWORD_HASH=$(kubectl run authelia-hash-temp --rm -i --restart=Never --image=ghcr.io/authelia/authelia:latest -- \
    authelia crypto hash generate argon2 --random.length=0 --config=/dev/null --password "$PASSWORD" 2>/dev/null | grep '^\$argon2' || true)

if [ -z "$PASSWORD_HASH" ]; then
    echo "Error: Failed to generate password hash"
    # Cleanup any leftover pod
    kubectl delete pod authelia-hash-temp --ignore-not-found=true
    exit 1
fi

echo "Hash generated successfully"
echo

# Escape special characters for YAML
PASSWORD_HASH_ESCAPED=$(echo "$PASSWORD_HASH" | sed 's/\$/\\$/g')

# Get current ConfigMap
echo "Fetching current users ConfigMap..."
CURRENT_USERS=$(kubectl get configmap authelia-users -n default -o jsonpath='{.data.users_database\.yml}')

# Check if user already exists
if echo "$CURRENT_USERS" | grep -q "^  ${USERNAME}:"; then
    echo "Error: User '${USERNAME}' already exists"
    exit 1
fi

# Create new user entry
NEW_USER="  ${USERNAME}:
    disabled: false
    displayname: \"${DISPLAYNAME}\"
    password: \"${PASSWORD_HASH_ESCAPED}\"
    email: \"${EMAIL}\"
    groups:
${GROUPS_YAML%\\n}"

# Append new user to existing users
UPDATED_USERS="${CURRENT_USERS}
${NEW_USER}"

# Create temporary YAML file
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: authelia-users
  namespace: default
data:
  users_database.yml: |
${UPDATED_USERS}
EOF

echo "Applying updated ConfigMap..."
kubectl apply -f "$TEMP_FILE"
rm "$TEMP_FILE"

echo
echo "=== User Added Successfully ==="
echo "Username: $USERNAME"
echo "Display Name: $DISPLAYNAME"
echo "Email: $EMAIL"
echo "Groups: ${GROUPS_INPUT}"
echo
echo "Authelia will reload the users file within 5 minutes (refresh_interval)."
echo "To force immediate reload: kubectl rollout restart deployment/authelia"
echo
echo "The user can now:"
echo "  1. Visit https://auth.lvs.me.uk"
echo "  2. Login with username and password"
echo "  3. Set up 2FA (TOTP)"
