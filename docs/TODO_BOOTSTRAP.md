# Remaining Bootstrap Documentation Work

## Context

This document outlines the remaining work after completing documentation updates for Flux Image Automation with the `spec.values` approach. The core documentation (README.md, DEPLOY.md, CLAUDE.md) has been updated and committed.

## Completed Work (commit db73616)

- ✅ Updated README.md deployment flow and architecture
- ✅ Updated DEPLOY.md with spec.values approach and DATABASE_URL fixes
- ✅ Updated CLAUDE.md with deployment patterns
- ✅ Deleted outdated MIGRATION_COMPLETE.md and DEPLOYMENT_REVIEW.md

---

## Task 1: Rewrite `docs/BOOTSTRAP.md`

### Current Issues

The existing BOOTSTRAP.md (378 lines) needs updates to reflect:

1. **registry-credentials secret** - Missing from secret creation steps
2. **spec.values approach** - Still references old valuesFiles pattern
3. **Flux Image Automation** - Doesn't mention it's pre-installed
4. **IMAGE_AUTOMATION** kustomization - Need to add to cluster/prod/

### Required Changes

#### Section 1: Prerequisites (Lines 6-27)

**Current state**: Lists 6 GitHub secrets
**Add**:

- `REGISTRY_PASSWORD` - for kubectl create secret (if not already there)
- Note that Flux CLI is required locally

**Keep**: Hetzner S3 bucket creation, Flux CLI installation

#### Section 2: Infrastructure Deployment (Lines 29-42)

**No changes needed** - Terraform workflow is correct

#### Section 3: Flux Bootstrap (Lines 54-94)

**Current state**: Covers SSH tunnel, kubeconfig, flux bootstrap
**Updates needed**:

- Clarify that flux deploy key should be in `infrastructure/flux-deploy-key` (not /tmp)
- Note that key is already in repo (infrastructure/flux-deploy-key.pub exists)
- Emphasize SSH tunnel must stay open for entire process

**Add note**: Flux Image Automation controllers are installed via cluster config (not manual)

#### Section 4: Create Initial Secrets (Lines 96-127)

**Critical additions**:

```bash
# AFTER flux bootstrap, create registry-credentials secret
kubectl create secret docker-registry registry-credentials \
  -n flux-system \
  --docker-server=registry.lvs.me.uk \
  --docker-username=robot_user \
  --docker-password='YOUR_REGISTRY_PASSWORD'
```

**Update**: PostgreSQL secret names match actual usage (check platform/postgresql-new/secret-auth.yaml)

#### Section 5: Monitor Initial Deployment (Lines 129-149)

**Add**: Reference to image-automation kustomization in dependency chain

**Current dependency order**:

```
1. flux-system
2. helmrepositories
3. storage-install (10-15m)
4. cert-manager-install
```

**Add to chain**:

```
5. image-automation (deploys ImageRepository, ImagePolicy, ImageUpdateAutomation)
```

#### Section 6: Create Longhorn Secret (Lines 151-169)

**No changes** - This is correct

#### Section 7: Monitor Full Deployment (Lines 171-208)

**Add** to deployment order:

```
10. image-automation (1m) - Flux Image Automation resources
```

#### Section 8: Verify Deployment (Lines 210-240)

**Add verification steps**:

```bash
# Verify Flux Image Automation
flux get images repository
flux get images policy
flux get image update

# Should show:
# - ruby-demo-app ImageRepository: READY True
# - ruby-demo-app ImagePolicy: latest tag detected
# - monorepo-auto ImageUpdateAutomation: READY True
```

#### New Section: Understanding Image Automation

**Add after Section 8**:

```markdown
## How Image Automation Works

Once deployed, the system automatically updates applications:

1. **Developer pushes code** → GitHub Actions builds image with tag `1.0.X`
2. **Flux ImageRepository** scans `registry.lvs.me.uk` every 1 minute
3. **Flux ImagePolicy** selects latest semver tag matching `>=1.0.0`
4. **Flux ImageUpdateAutomation** commits change to `helmrelease.yaml`:
   - Updates `spec.values.image.tag` from `1.0.5` → `1.0.6`
   - Commits with message "chore: update images"
   - Pushes to master branch
5. **Flux Kustomization** detects git change, applies updated HelmRelease
6. **Kubernetes** performs rolling update with health checks

**Key detail**: Image tag is in `helmrelease.yaml` `spec.values`, NOT in `values.yaml`. This ensures only changes to the specific app trigger reconciliation.

**Viewing automation in action**:

```bash
# Watch for new images
watch -n 5 'flux get images repository'

# See what Flux will update
flux get images policy ruby-demo-app

# Check ImageUpdateAutomation status
flux get image update monorepo-auto

# View commits from Flux
git log --oneline --author="flux-bot"
```

```

### Files to Reference

- `applications/ruby-demo-app/helmrelease.yaml` - Example of spec.values with markers
- `platform/flux-image-automation/ruby-demo-app.yaml` - ImageRepository + ImagePolicy
- `platform/flux-image-automation/image-update.yaml` - ImageUpdateAutomation

### Testing Checklist

After rewriting, verify:

- [ ] All secret creation commands are accurate
- [ ] registry-credentials secret is documented
- [ ] Dependency order includes image-automation
- [ ] Verification steps include image automation checks
- [ ] Cross-references to other docs are valid
- [ ] No references to old valuesFiles approach for image automation

---

## Task 2: Create `bootstrap.sh` Script

### Requirements

**Location**: `/bootstrap.sh` (root of repository)

**Purpose**: Interactive script to automate Flux bootstrap + secret creation after Terraform provisions the server

**Key Features**:
- Secure password input (no bash history)
- Idempotent (can re-run)
- Clear progress indicators
- Validation at each step
- Cleanup of temporary files

### Script Structure

```bash
#!/usr/bin/env bash
# LVS Cloud Bootstrap Script
# Automates Flux bootstrap and initial secret creation
# Run this LOCALLY after Terraform provisions the server

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

prompt_password() {
    local var_name="$1"
    local prompt_text="$2"
    local password
    local password_confirm

    while true; do
        read -s -p "$prompt_text: " password
        echo
        read -s -p "Confirm password: " password_confirm
        echo

        if [ "$password" = "$password_confirm" ]; then
            eval "$var_name='$password'"
            break
        else
            warn "Passwords do not match. Try again."
        fi
    done
}

check_prerequisites() {
    info "Checking prerequisites..."

    command -v flux >/dev/null 2>&1 || error "flux CLI not found. Install: brew install fluxcd/tap/flux"
    command -v kubectl >/dev/null 2>&1 || error "kubectl not found"
    command -v ssh-keygen >/dev/null 2>&1 || error "ssh-keygen not found"
    command -v dig >/dev/null 2>&1 || error "dig not found"

    success "All prerequisites met"
}

# Main sections
main() {
    echo "==================================================="
    echo "    LVS Cloud Bootstrap Script"
    echo "==================================================="
    echo

    check_prerequisites

    # Get server IP
    info "Detecting server IP..."
    DEFAULT_IP=$(dig +short app.lvs.me.uk | head -1)
    read -p "Server IP [$DEFAULT_IP]: " SERVER_IP
    SERVER_IP=${SERVER_IP:-$DEFAULT_IP}
    info "Using server: $SERVER_IP"

    # Test SSH connection
    info "Testing SSH connection..."
    ssh -o ConnectTimeout=5 ubuntu@$SERVER_IP "echo connected" >/dev/null 2>&1 || \
        error "Cannot SSH to server. Check that Terraform has completed."

    # Collect passwords
    info "Collecting passwords (input hidden)..."
    prompt_password POSTGRES_ADMIN_PASSWORD "PostgreSQL admin password"
    prompt_password POSTGRES_RUBY_PASSWORD "PostgreSQL ruby_demo_user password"
    prompt_password REGISTRY_PASSWORD "Registry password (from GitHub secret)"

    read -p "S3 Access Key: " S3_ACCESS_KEY
    prompt_password S3_SECRET_KEY "S3 Secret Key"

    # Verify server is ready
    info "Verifying k3s is ready..."
    ssh ubuntu@$SERVER_IP "kubectl get nodes" >/dev/null 2>&1 || \
        error "k3s not ready. Wait a few minutes after Terraform completion."

    # Setup SSH tunnel (background)
    info "Setting up SSH tunnel for kubectl access..."
    ssh -f -N -L 6443:127.0.0.1:6443 ubuntu@$SERVER_IP
    TUNNEL_PID=$!
    trap "kill $TUNNEL_PID 2>/dev/null || true; rm -f /tmp/k3s-kubeconfig.yaml /tmp/flux-deploy-key* /tmp/known_hosts" EXIT

    sleep 2

    # Get kubeconfig
    info "Downloading kubeconfig..."
    ssh ubuntu@$SERVER_IP "cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-kubeconfig.yaml
    export KUBECONFIG=/tmp/k3s-kubeconfig.yaml

    # Test kubectl
    kubectl get nodes >/dev/null 2>&1 || error "kubectl connection failed"
    success "kubectl connected via SSH tunnel"

    # Check if Flux already bootstrapped
    if kubectl get namespace flux-system >/dev/null 2>&1; then
        warn "Flux already bootstrapped. Skipping Flux bootstrap."
    else
        # Generate Flux deploy key if needed
        if [ ! -f infrastructure/flux-deploy-key ]; then
            info "Generating Flux deploy key..."
            ssh-keygen -t ed25519 -C "flux-bot@lvs.me.uk" -f infrastructure/flux-deploy-key -N ""

            echo
            warn "Add this deploy key to GitHub with WRITE access:"
            echo "  https://github.com/louis-vs/lvs-cloud/settings/keys/new"
            echo
            cat infrastructure/flux-deploy-key.pub
            echo
            read -p "Press Enter after adding the deploy key to GitHub..."
        fi

        # Bootstrap Flux
        info "Bootstrapping Flux..."
        flux bootstrap git \
            --url=ssh://git@github.com/louis-vs/lvs-cloud.git \
            --branch=master \
            --path=clusters/prod \
            --private-key-file=infrastructure/flux-deploy-key || error "Flux bootstrap failed"

        success "Flux bootstrap completed"
    fi

    # Create secrets
    info "Creating Kubernetes secrets..."

    # Flux Git SSH
    if ! kubectl get secret flux-git-ssh -n flux-system >/dev/null 2>&1; then
        ssh-keyscan github.com > /tmp/known_hosts
        kubectl create secret generic flux-git-ssh \
            -n flux-system \
            --from-file=identity=infrastructure/flux-deploy-key \
            --from-file=known_hosts=/tmp/known_hosts
        success "Created flux-git-ssh secret"
    else
        info "flux-git-ssh secret already exists"
    fi

    # PostgreSQL auth
    if ! kubectl get secret postgresql-auth -n default >/dev/null 2>&1; then
        kubectl create secret generic postgresql-auth -n default \
            --from-literal=postgres-password="$POSTGRES_ADMIN_PASSWORD" \
            --from-literal=user-password="$POSTGRES_RUBY_PASSWORD" \
            --from-literal=ruby-password="$POSTGRES_RUBY_PASSWORD"
        success "Created postgresql-auth secret"
    else
        info "postgresql-auth secret already exists"
    fi

    # Registry credentials (for Flux Image Automation)
    if ! kubectl get secret registry-credentials -n flux-system >/dev/null 2>&1; then
        kubectl create secret docker-registry registry-credentials \
            -n flux-system \
            --docker-server=registry.lvs.me.uk \
            --docker-username=robot_user \
            --docker-password="$REGISTRY_PASSWORD"
        success "Created registry-credentials secret"
    else
        info "registry-credentials secret already exists"
    fi

    # Wait for longhorn-system namespace
    info "Waiting for Longhorn to be installed (this takes 10-15 minutes)..."
    for i in {1..60}; do
        if kubectl get namespace longhorn-system >/dev/null 2>&1; then
            success "Longhorn namespace ready"
            break
        fi
        echo -n "."
        sleep 10
    done
    echo

    # Longhorn S3 backup credentials
    if ! kubectl get secret longhorn-backup -n longhorn-system >/dev/null 2>&1; then
        kubectl create secret generic longhorn-backup -n longhorn-system \
            --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
            --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
            --from-literal=AWS_DEFAULT_REGION='nbg1' \
            --from-literal=AWS_ENDPOINTS='{"s3":"https://nbg1.your-objectstorage.com"}'
        success "Created longhorn-backup secret"
    else
        info "longhorn-backup secret already exists"
    fi

    # PostgreSQL S3 backup credentials
    if ! kubectl get secret pg-backup-s3 -n default >/dev/null 2>&1; then
        kubectl create secret generic pg-backup-s3 -n default \
            --from-literal=S3_ENDPOINT='https://nbg1.your-objectstorage.com' \
            --from-literal=S3_BUCKET='lvs-cloud-pg-backups' \
            --from-literal=S3_REGION='nbg1' \
            --from-literal=S3_ACCESS_KEY="$S3_ACCESS_KEY" \
            --from-literal=S3_SECRET_KEY="$S3_SECRET_KEY"
        success "Created pg-backup-s3 secret"
    else
        info "pg-backup-s3 secret already exists"
    fi

    # Monitor deployment
    echo
    info "Bootstrap complete! Monitoring deployment..."
    echo "  This will take 30-45 minutes for full deployment"
    echo "  Press Ctrl+C to exit monitoring (deployment continues in background)"
    echo

    sleep 5
    watch -n 10 "flux get kustomizations"
}

main "$@"
```

### Script Features

1. **Secure Password Input**:
   - Uses `read -s` (no echo)
   - Confirms passwords
   - Never writes passwords to files

2. **Idempotent**:
   - Checks if secrets exist before creating
   - Checks if Flux bootstrapped
   - Can re-run safely

3. **Error Handling**:
   - Exits on error (`set -e`)
   - Validates each step
   - Cleanup on exit (trap)

4. **User Experience**:
   - Color-coded output
   - Progress indicators
   - Clear instructions
   - Auto-detection of server IP

5. **Security**:
   - SSH tunnel for kubectl
   - Temporary files cleaned up
   - No passwords in bash history

### Testing

```bash
# Make executable
chmod +x bootstrap.sh

# Test prerequisite checks
./bootstrap.sh
# Should validate flux, kubectl, ssh-keygen available

# Dry run (comment out actual kubectl/flux commands)
# Verify flow and prompts
```

---

## Task 3: Update `OPS.md`

### Quick Verification

Review OPS.md for:

1. **Deployment monitoring** - Add Flux Image Automation commands
2. **Troubleshooting** - Add common image automation issues
3. **Secrets management** - Mention registry-credentials secret

### Additions Needed

#### Section: Monitoring Deployments

**Add**:

```markdown
### Image Automation Status

```bash
# Check image repositories
flux get images repository

# Check image policies
flux get images policy

# Check image update automation
flux get image update

# View recent Flux commits
git log --oneline --author="flux-bot" -10
```

```

#### Section: Troubleshooting

**Add**:

```markdown
### Image Not Updating Automatically

**Symptoms**: New image pushed but deployment not updating

**Check**:

```bash
# Verify ImageRepository can scan
flux get images repository <app-name>
# Should show: READY True, last scan time recent

# Check authentication
kubectl get secret registry-credentials -n flux-system
# Should exist

# Check ImagePolicy selected correct tag
flux get images policy <app-name>
# Should show latest tag

# Check ImageUpdateAutomation is running
flux get image update monorepo-auto
# Should show: READY True

# Force reconciliation
flux reconcile image repository <app-name>
flux reconcile image update monorepo-auto
```

**Common causes**:

- registry-credentials secret missing
- ImageRepository secretRef not set
- Image tag doesn't match semver policy range
- ImageUpdateAutomation can't push (deploy key permissions)

```

---

## Task 4: Final Validation

### Documentation Cross-Check

After completing all changes:

1. **Verify examples match reality**:
   - [ ] HelmRelease examples use spec.values.image
   - [ ] All secrets documented in BOOTSTRAP.md exist in bootstrap.sh
   - [ ] registry-credentials secret mentioned in DEPLOY.md and BOOTSTRAP.md

2. **Test links**:
   - [ ] All cross-references valid (no broken links to deleted files)
   - [ ] References to example code point to actual files

3. **Validate bootstrap.sh**:
   - [ ] Shellcheck passes: `shellcheck bootstrap.sh`
   - [ ] Executable: `chmod +x bootstrap.sh`
   - [ ] Test on test cluster (if available)

### Success Criteria

- [ ] docs/BOOTSTRAP.md reflects actual working process with all secrets
- [ ] bootstrap.sh handles passwords securely and is idempotent
- [ ] OPS.md has Flux Image Automation troubleshooting
- [ ] No references to outdated patterns
- [ ] User can run bootstrap.sh and deploy cluster without manual intervention

---

## Estimated Effort

- **BOOTSTRAP.md rewrite**: 1-2 hours (comprehensive, 400+ line file)
- **bootstrap.sh creation**: 1-2 hours (testing, validation)
- **OPS.md updates**: 30 minutes (additions only)
- **Final validation**: 30 minutes

**Total**: 3-4 hours of focused work

---

## Notes for Next Session

1. The working Flux Image Automation system uses:
   - `spec.values.image` in HelmRelease (NOT values.yaml)
   - registry-credentials secret in flux-system namespace
   - Clean semver tags (1.0.X) from GitHub Actions
   - ImageUpdateAutomation commits to helmrelease.yaml

2. Key learnings documented:
   - DATABASE_URL must be constructed in app code (no $(VAR) substitution)
   - spec.values approach prevents cross-app reconciliation
   - registry-credentials secret required for private registry scanning

3. Files to preserve for reference:
   - `applications/ruby-demo-app/helmrelease.yaml` - Working example
   - `platform/flux-image-automation/ruby-demo-app.yaml` - ImageRepository + Policy
   - This TODO file can be deleted after work is complete
