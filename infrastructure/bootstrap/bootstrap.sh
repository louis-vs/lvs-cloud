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

    # Verify server is ready
    info "Verifying k3s is ready..."
    ssh ubuntu@$SERVER_IP "kubectl get nodes" >/dev/null 2>&1 || \
        error "k3s not ready. Wait a few minutes after Terraform completion."

    # Setup SSH tunnel (background)
    info "Setting up SSH tunnel for kubectl access..."
    ssh -N -L 6443:127.0.0.1:6443 ubuntu@$SERVER_IP &
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

    # Detect scenario: Fresh cluster vs Server recreation
    info "Detecting bootstrap scenario..."
    if kubectl get kustomization flux-system -n flux-system >/dev/null 2>&1; then
        # Flux kustomizations exist - this is server recreation
        success "Detected: Server Recreation (etcd persists)"
        echo
        info "Running verification checks..."

        # Verify Flux kustomizations exist
        info "Checking Flux kustomizations..."
        if ! kubectl get kustomization -n flux-system | grep -q flux-system; then
            error "Flux kustomizations missing. etcd may be corrupted."
        fi
        success "Flux kustomizations present"

        # Verify critical secrets exist
        info "Checking critical secrets..."
        kubectl get secret flux-git-ssh -n flux-system >/dev/null 2>&1 || warn "flux-git-ssh secret missing"
        kubectl get secret registry-credentials -n flux-system >/dev/null 2>&1 || warn "registry-credentials secret missing"
        kubectl get secret postgresql-auth -n platform >/dev/null 2>&1 || warn "postgresql-auth secret missing"
        success "Critical secrets present"

        # Check Flux reconciliation
        info "Verifying Flux reconciliation status..."
        echo "Run 'flux get all' to check reconciliation status"
        echo "All pods should restart and attach to persistent volumes within 5-10 minutes"
        echo
        success "Server recreation verification complete!"
        echo
        info "Next steps:"
        echo "  1. Monitor pods: kubectl get pods -A -w"
        echo "  2. Check Flux: flux get all"
        echo "  3. Test app: curl https://app.lvs.me.uk"
        exit 0
    fi

    # Fresh cluster - proceed with full bootstrap
    success "Detected: Fresh Cluster Bootstrap"
    echo
    info "Proceeding with full bootstrap..."

    # Check if Flux already partially bootstrapped
    if kubectl get namespace flux-system >/dev/null 2>&1; then
        warn "flux-system namespace exists but kustomizations missing (interrupted bootstrap)"
        warn "Proceeding with Flux bootstrap to recover..."
    fi

    # Collect passwords for fresh bootstrap
    info "Collecting credentials for fresh bootstrap..."
    prompt_password POSTGRES_ADMIN_PASSWORD "PostgreSQL admin password"
    prompt_password POSTGRES_RUBY_PASSWORD "PostgreSQL ruby_demo_user password"
    prompt_password GRAFANA_ADMIN_PASSWORD "Grafana admin password"
    prompt_password REGISTRY_PASSWORD "Registry password (from GitHub secret)"
    read -p "S3 Access Key: " S3_ACCESS_KEY
    prompt_password S3_SECRET_KEY "S3 Secret Key"

    # Check if Flux bootstrap needed
    if kubectl get namespace flux-system >/dev/null 2>&1 && \
       kubectl get kustomization flux-system -n flux-system >/dev/null 2>&1; then
        success "Flux already bootstrapped. Skipping Flux bootstrap."
    else
        # Generate Flux deploy key
        info "Generating Flux deploy key..."
        ssh-keygen -t ed25519 -C "flux-bot@lvs.me.uk" -f /tmp/flux-deploy-key -N ""

        echo
        warn "Add this deploy key to GitHub with WRITE access:"
        echo "  https://github.com/louis-vs/lvs-cloud/settings/keys/new"
        echo
        cat /tmp/flux-deploy-key.pub
        echo
        read -p "Press Enter after adding the deploy key to GitHub..."

        # Bootstrap Flux
        info "Bootstrapping Flux..."
        flux bootstrap git \
            --url=ssh://git@github.com/louis-vs/lvs-cloud.git \
            --branch=master \
            --path=clusters/prod \
            --private-key-file=/tmp/flux-deploy-key \
            --components-extra=image-reflector-controller,image-automation-controller || error "Flux bootstrap failed"

        success "Flux bootstrap completed"
    fi

    # Create secrets
    info "Creating Kubernetes secrets..."

    # Flux Git SSH
    if ! kubectl get secret flux-git-ssh -n flux-system >/dev/null 2>&1; then
        ssh-keyscan github.com > /tmp/known_hosts
        kubectl create secret generic flux-git-ssh \
            -n flux-system \
            --from-file=identity=/tmp/flux-deploy-key \
            --from-file=known_hosts=/tmp/known_hosts
        success "Created flux-git-ssh secret"
    else
        info "flux-git-ssh secret already exists"
    fi

    # PostgreSQL auth
    if ! kubectl get secret postgresql-auth -n platform >/dev/null 2>&1; then
        kubectl create secret generic postgresql-auth -n platform \
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
            --from-literal=AWS_ENDPOINTS='https://nbg1.your-objectstorage.com'
        success "Created longhorn-backup secret"
    else
        info "longhorn-backup secret already exists"
    fi

    # PostgreSQL S3 backup credentials
    if ! kubectl get secret pg-backup-s3 -n platform >/dev/null 2>&1; then
        kubectl create secret generic pg-backup-s3 -n platform \
            --from-literal=S3_ENDPOINT='https://nbg1.your-objectstorage.com' \
            --from-literal=S3_BUCKET='lvs-cloud-pg-backups' \
            --from-literal=S3_REGION='nbg1' \
            --from-literal=S3_ACCESS_KEY="$S3_ACCESS_KEY" \
            --from-literal=S3_SECRET_KEY="$S3_SECRET_KEY"
        success "Created pg-backup-s3 secret"
    else
        info "pg-backup-s3 secret already exists"
    fi

    # etcd S3 backup credentials
    if ! kubectl get secret etcd-backup-s3 -n kube-system >/dev/null 2>&1; then
        kubectl create secret generic etcd-backup-s3 -n kube-system \
            --from-literal=S3_ENDPOINT='https://nbg1.your-objectstorage.com' \
            --from-literal=S3_BUCKET='lvs-cloud-etcd-backups' \
            --from-literal=S3_REGION='nbg1' \
            --from-literal=S3_ACCESS_KEY="$S3_ACCESS_KEY" \
            --from-literal=S3_SECRET_KEY="$S3_SECRET_KEY"
        success "Created etcd-backup-s3 secret"
    else
        info "etcd-backup-s3 secret already exists"
    fi

    # Wait for platform namespace
    info "Waiting for platform namespace (this takes 5-10 minutes)..."
    for i in {1..60}; do
        if kubectl get namespace platform >/dev/null 2>&1; then
            success "Platform namespace ready"
            break
        fi
        echo -n "."
        sleep 10
    done
    echo

    # Grafana admin credentials
    if ! kubectl get secret grafana-admin -n platform >/dev/null 2>&1; then
        kubectl create secret generic grafana-admin -n platform \
            --from-literal=admin-user='admin' \
            --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD"
        success "Created grafana-admin secret"
    else
        info "grafana-admin secret already exists"
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
