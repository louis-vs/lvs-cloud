# Development Guide

## Quick Start

```bash
# Clone and setup
git clone <repo-url>
cd lvs-cloud

# Automated setup
./scripts/setup-dev.sh

# Manual setup alternative
make install
```

## Code Quality & Formatting

### Pre-commit Hooks

This project uses comprehensive pre-commit hooks to ensure code quality:

```bash
# Install hooks (done automatically by setup script)
pre-commit install
pre-commit install --hook-type commit-msg

# Run on all files
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt --all-files
```

### Supported File Types

| Type | Tools | Configuration |
|------|-------|---------------|
| **Markdown** | markdownlint | `.markdownlint.yaml` |
| **YAML** | prettier, yamllint | `.prettierrc` |
| **Ruby** | rubocop | `.rubocop.yml` |
| **Terraform** | terraform fmt, validate | Built-in |
| **Shell** | shellcheck | Built-in |
| **Dockerfile** | hadolint | Built-in |
| **JSON** | prettier | `.prettierrc` |

### Make Commands

```bash
make help       # Show all commands
make install    # Install dev dependencies
make format     # Format all files
make check      # Run quality checks
make test       # Run all tests
make commit     # Pre-commit check + ready to commit
```

## File Structure Standards

### Directory Layout

```
lvs-cloud/
├── .github/           # GitHub Actions workflows
├── applications/      # Application code
│   ├── monitoring-stack/
│   └── ruby-monitor/
├── infrastructure/    # Terraform code
├── scripts/          # Utility scripts
└── docs/            # Documentation
```

### Naming Conventions

- **Files**: `kebab-case.ext`
- **Directories**: `kebab-case`
- **Terraform**: `snake_case` for resources
- **Ruby**: `snake_case` for methods, `PascalCase` for classes
- **Environment vars**: `UPPER_SNAKE_CASE`

## Code Standards

### Terraform

```hcl
# Use consistent formatting
resource "hcloud_server" "main" {
  name        = "${var.project_name}-server"
  server_type = var.server_type

  # Always add labels
  labels = {
    project = var.project_name
    role    = "main"
  }
}
```

#### Remote State Backend

**Configuration:** S3-compatible backend using Hetzner Object Storage

```hcl
terraform {
  backend "s3" {
    bucket                      = "lvs-cloud-terraform-state"
    key                         = "terraform.tfstate"
    region                      = "us-east-1"                    # Dummy region (required but ignored)
    endpoint                    = "https://nbg1.your-objectstorage.com"
    skip_credentials_validation = true                          # Skip AWS-specific validations
    skip_metadata_api_check     = true                          # No EC2 metadata on Hetzner
    skip_region_validation      = true                          # Allow dummy region
    force_path_style           = true                           # Use path-style URLs
  }
}
```

**Key Configuration Details:**

- **`region = "us-east-1"`**: Required by Terraform but ignored (not AWS)
- **`endpoint`**: Points to Hetzner Object Storage (Nuremberg datacenter)
- **Skip validations**: Bypasses AWS-specific checks for S3-compatible storage
- **`force_path_style`**: Uses `endpoint/bucket/key` instead of `bucket.endpoint/key`

**Environment Setup:**

```bash
# Required for S3 backend authentication
export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}"
```

**Benefits:**

- ✅ **Multi-machine access** - shared state across team members
- ✅ **State locking** - prevents concurrent modifications
- ✅ **Version control** - state change history in Object Storage
- ✅ **Cost effective** - €1/month vs AWS S3 pricing

### Ruby

```ruby
# Use single quotes for strings
name = 'lvs-cloud'

# Method length max 30 lines
def health_check
  {
    status: 'healthy',
    uptime: Time.now - START_TIME
  }
end
```

### YAML

```yaml
# 2-space indentation
version: '3.8'

services:
  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
```

### Shell Scripts

```bash
#!/bin/bash
set -e  # Exit on error

# Use functions for reusability
log_info() {
    echo "ℹ️  $1"
}
```

## Git Workflow

### Commit Messages

Follow conventional commits:

```bash
feat: add monitoring dashboard
fix: resolve docker network issue
docs: update deployment guide
chore: update dependencies
```

### Branch Naming

```bash
feature/monitoring-alerts
fix/ssl-certificate-renewal
docs/api-documentation
```

### Pre-commit Process

```bash
# Automatic on git commit
git add .
git commit -m "feat: add new feature"

# Manual check before commit
make commit
```

## Development Tools Setup

### Required Tools

- **Python 3.8+** - For pre-commit hooks
- **Node.js 18+** - For prettier, markdownlint
- **Ruby 3.2+** - For Ruby applications
- **Terraform 1.6+** - For infrastructure
- **Docker** - For containerization
- **Git** - Version control

### Optional but Recommended

- **VS Code** with extensions:
  - Terraform
  - Ruby
  - YAML
  - markdownlint
  - Prettier
- **GitHub CLI** for repository management

### IDE Configuration

#### VS Code Settings

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform"
  },
  "[ruby]": {
    "editor.defaultFormatter": "misogi.ruby-rubocop"
  }
}
```

## Testing

### Run All Tests

```bash
make test
```

### Individual Test Types

```bash
# Terraform validation
cd infrastructure && terraform validate

# Ruby tests (when implemented)
cd applications/ruby-monitor && bundle exec rspec

# Security scans
pre-commit run detect-secrets --all-files
```

## CI/CD Integration

### GitHub Actions

Code quality is enforced in CI:

- **Pre-commit hooks** run on every PR
- **Security scanning** with Trivy
- **Terraform validation**
- **Ruby linting** with RuboCop

### Local Development

Match CI behavior locally:

```bash
# Run same checks as CI
pre-commit run --all-files
make check
make test
```

## Troubleshooting

### Common Issues

**Pre-commit hook failures:**

```bash
# Update hooks
pre-commit autoupdate

# Clear cache
pre-commit clean
```

**Terraform formatting:**

```bash
# Auto-fix formatting
terraform fmt -recursive
```

**Ruby linting issues:**

```bash
# Auto-fix Ruby issues
bundle exec rubocop --auto-correct-all
```

### Getting Help

1. **Check the logs** - Most tools provide detailed error messages
2. **Run individual tools** - Test specific formatters in isolation
3. **Update dependencies** - `pre-commit autoupdate`
4. **Clean state** - Remove caches and reinstall

---

*For infrastructure deployment, see [DEPLOYMENT.md](DEPLOYMENT.md)*
