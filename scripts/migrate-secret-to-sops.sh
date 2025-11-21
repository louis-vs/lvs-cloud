#!/usr/bin/env bash
set -euo pipefail

# Script to migrate a Kubernetes secret to SOPS encryption
# Usage: ./scripts/migrate-secret-to-sops.sh <secret-name> <namespace>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SECRET_NAME="${1:-}"
NAMESPACE="${2:-}"

if [[ -z "$SECRET_NAME" ]] || [[ -z "$NAMESPACE" ]]; then
  echo "Usage: $0 <secret-name> <namespace>"
  echo ""
  echo "Examples:"
  echo "  $0 grafana-admin platform"
  echo "  $0 flux-git-ssh flux-system"
  exit 1
fi

# Determine secrets directory based on namespace
case "$NAMESPACE" in
  "platform")
    SECRETS_DIR="$REPO_ROOT/platform/secrets"
    ;;
  "flux-system")
    SECRETS_DIR="$REPO_ROOT/clusters/prod/flux-system/secrets"
    ;;
  "applications")
    SECRETS_DIR="$REPO_ROOT/applications/secrets"
    ;;
  "longhorn-system"|"kube-system")
    SECRETS_DIR="$REPO_ROOT/infrastructure/secrets"
    ;;
  *)
    echo "Error: Unknown namespace '$NAMESPACE'"
    echo "Supported namespaces: platform, flux-system, applications, longhorn-system, kube-system"
    exit 1
    ;;
esac

BACKUP_DIR="$HOME/sops-migration-backups"
mkdir -p "$BACKUP_DIR"

echo "Migrating secret: $SECRET_NAME (namespace: $NAMESPACE)"
echo "---"

# Step 1: Backup original secret
echo "1. Backing up original secret..."
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/${SECRET_NAME}.yaml"
echo "   ✓ Backup saved to: $BACKUP_DIR/${SECRET_NAME}.yaml"

# Step 2: Extract and clean secret
echo "2. Extracting and cleaning secret..."
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml | \
  grep -v '^\s*creationTimestamp:\|^\s*resourceVersion:\|^\s*uid:' | \
  sed '/^  managedFields:/,/^[a-z]/{ /^[a-z]/!d; }' | \
  sed '/^  managedFields:/d' > "/tmp/${SECRET_NAME}-clean.yaml"
echo "   ✓ Cleaned secret prepared"

# Step 3: Copy to secrets directory
echo "3. Copying to secrets directory..."
cp "/tmp/${SECRET_NAME}-clean.yaml" "$SECRETS_DIR/${SECRET_NAME}.yaml"
echo "   ✓ Copied to: $SECRETS_DIR/${SECRET_NAME}.yaml"

# Step 4: Encrypt with SOPS
echo "4. Encrypting with SOPS..."
sops --encrypt --in-place "$SECRETS_DIR/${SECRET_NAME}.yaml"
echo "   ✓ Encrypted with age"

# Step 5: Add to kustomization.yaml if not already present
echo "5. Adding to kustomization.yaml..."
KUSTOMIZATION_FILE="$SECRETS_DIR/kustomization.yaml"
if ! grep -q "  - ${SECRET_NAME}.yaml" "$KUSTOMIZATION_FILE"; then
  # Use awk to insert before the last line if resources is empty, or append to resources
  if grep -q "^resources: \[\]" "$KUSTOMIZATION_FILE"; then
    # Replace empty array with list
    sed -i '' "s/^resources: \[\]/resources:\\
  - ${SECRET_NAME}.yaml/" "$KUSTOMIZATION_FILE"
  else
    # Append to existing resources list
    awk "/^resources:/ { print; print \"  - ${SECRET_NAME}.yaml\"; next } 1" "$KUSTOMIZATION_FILE" > "/tmp/kustomization-temp.yaml"
    mv "/tmp/kustomization-temp.yaml" "$KUSTOMIZATION_FILE"
  fi
  echo "   ✓ Added to kustomization.yaml"
else
  echo "   - Already in kustomization.yaml"
fi

echo "---"
echo "✓ Migration complete!"
echo ""
echo "Next steps:"
echo "  1. Review the encrypted file: $SECRETS_DIR/${SECRET_NAME}.yaml"
echo "  2. Commit: git add $SECRETS_DIR/ && git commit -m 'feat: migrate $SECRET_NAME secret to SOPS'"
echo "  3. Push: git push"
echo "  4. Reconcile: flux reconcile kustomization ${NAMESPACE}-secrets"
echo "  5. Verify: kubectl get secret $SECRET_NAME -n $NAMESPACE"
