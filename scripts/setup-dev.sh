#!/bin/bash

# LVS Cloud - Development Environment Setup
# This script sets up the complete development environment

set -e

echo "🚀 LVS Cloud - Development Environment Setup"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
log_info "Checking prerequisites..."

# Check for required tools
MISSING_TOOLS=()

if ! command_exists python3; then
    MISSING_TOOLS+=("python3")
fi

if ! command_exists pip3; then
    MISSING_TOOLS+=("pip3")
fi

if ! command_exists node; then
    MISSING_TOOLS+=("node")
fi

if ! command_exists npm; then
    MISSING_TOOLS+=("npm")
fi

if ! command_exists terraform; then
    MISSING_TOOLS+=("terraform")
fi

if ! command_exists docker; then
    MISSING_TOOLS+=("docker")
fi

if ! command_exists ruby; then
    MISSING_TOOLS+=("ruby")
fi

if ! command_exists bundle; then
    MISSING_TOOLS+=("bundler")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    log_error "Missing required tools: ${MISSING_TOOLS[*]}"
    log_info "Please install missing tools and run this script again"
    exit 1
fi

log_success "All prerequisites found"

# Install pre-commit
log_info "Installing pre-commit..."
pip3 install pre-commit --user
log_success "Pre-commit installed"

# Install pre-commit hooks
log_info "Installing pre-commit hooks..."
pre-commit install
pre-commit install --hook-type commit-msg
log_success "Pre-commit hooks installed"

# Install Node.js dependencies globally
log_info "Installing Node.js formatting tools..."
npm install -g prettier markdownlint-cli
log_success "Node.js tools installed"

# Install Python linting tools
log_info "Installing Python tools..."
pip3 install yamllint detect-secrets --user
log_success "Python tools installed"

# Install Ruby dependencies
log_info "Installing Ruby dependencies..."
cd applications/ruby-monitor
bundle install
cd ../..
log_success "Ruby dependencies installed"

# Initialize Terraform
log_info "Initializing Terraform..."
cd infrastructure
terraform init
cd ..
log_success "Terraform initialized"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    log_info "Creating .env file template..."
    cat > .env << 'EOF'
#!/usr/bin/env bash

# Hetzner Cloud Environment Variables
# Usage: source .env

# Hetzner Cloud API Token
export HCLOUD_TOKEN="your-hetzner-api-token-here"

# Project Configuration
export PROJECT_NAME="lvs-cloud"
export DOMAIN="lvs.me.uk"

# Terraform Configuration
export TF_VAR_hcloud_token="${HCLOUD_TOKEN}"
export TF_VAR_project_name="${PROJECT_NAME}"
export TF_VAR_domain="${DOMAIN}"
export TF_VAR_registry_user="${REGISTRY_USER}"
export TF_VAR_registry_pass="${REGISTRY_PASS}"

# Docker Registry Configuration
export REGISTRY_URL="registry.lvs.me.uk"
export REGISTRY_USER="admin"
export REGISTRY_PASS="your-secure-password-here"

echo "Environment variables loaded for ${PROJECT_NAME}"
echo "Domain: ${DOMAIN}"
echo "Hetzner token: ${HCLOUD_TOKEN:0:8}..."
EOF
    log_warning ".env file created - please update with your values"
else
    log_info ".env file already exists"
fi

# Initialize secrets baseline
log_info "Initializing secrets detection..."
detect-secrets scan --baseline .secrets.baseline || true
log_success "Secrets baseline created"

# Run initial formatting
log_info "Running initial code formatting..."
pre-commit run --all-files || log_warning "Some formatting issues found - this is normal on first run"

echo
log_success "🎉 Development environment setup complete!"
echo
echo "Next steps:"
echo "1. Edit .env file with your Hetzner API token and registry password"
echo "2. Run 'make test' to verify everything works"
echo "3. Run 'make format' to format all code"
echo "4. Use 'make help' to see all available commands"
echo
echo "Happy coding! 🚀"
