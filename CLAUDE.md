# LVS Cloud - Private Cloud Infrastructure

## Project Purpose

Personal private cloud for seamless application deployment with enterprise-grade monitoring. Focus: cost-effective, automated deployments, "set up once, reuse many times" approach for practicing DevOps skills and hosting projects for others.

## Current Architecture

**Infrastructure**: Hetzner Cloud cx22 (2 vCPU, 4GB RAM) - €9.89/month
**Services**: Traefik → SSL/routing, Registry → container images, Monitoring → Grafana/Prometheus/Loki
**Apps**: Ruby demo app at app.lvs.me.uk
**Deployment**: GitOps via GitHub Actions + Watchtower

## Critical Issues (High Priority)

### 1. Broken GitOps for Apps
**Problem**: Apps only deploy when `docker-compose.prod.yml` changes, not code changes
**Impact**: Breaks "seamless deployment" vision
**Location**: `.github/workflows/deploy-infrastructure.yml` handles everything monolithically

### 2. Incomplete Monitoring
**Problem**: No app metrics, basic dashboards only, missing enterprise-grade visibility
**Impact**: Can't debug issues or monitor app performance
**Missing**: Prometheus app scraping, custom Grafana dashboards, log aggregation

### 3. Insecure Grafana Access
**Problem**: Hardcoded admin/admin123 password, should use .env like registry
**Impact**: Security risk, not production-ready
**Fix**: Move to proper config files with environment credentials

### 4. Single App Limitation
**Problem**: Hardcoded ruby-demo-app, can't scale to multiple apps
**Location**: Deployment workflows, monitoring configs

### 5. Repository Structure Issues
**Problem**: `applications/` mixes platform services with user apps
**Impact**: Confusing structure, hard to scale
**Current**: applications/{monitoring-stack,registry,ruby-monitor}
**Should Be**: platform/{monitoring,registry} + applications/{ruby-demo-app}

## File Structure

**Current (Needs Restructuring)**:
```
├── infrastructure/        # Terraform for Hetzner Cloud
├── traefik/              # Should move to platform/
├── applications/         # Mixed: platform services + user apps (bad)
│   ├── monitoring-stack/ # Should move to platform/monitoring
│   ├── registry/         # Should move to platform/
│   └── ruby-monitor/     # User app (correct location, should rename)
└── .github/workflows/    # CI/CD automation
```

**Proposed Structure**:
```
├── README.md              # Status, quick commands, current issues
├── DEPLOY.md              # App deployment, infrastructure setup
├── OPS.md                 # Troubleshooting, monitoring, maintenance
├── infrastructure/        # Terraform for Hetzner Cloud
├── platform/             # Platform services
│   ├── traefik/          # SSL/routing
│   ├── monitoring/       # Grafana, Prometheus, Loki
│   └── registry/         # Container registry
├── applications/         # User applications only
│   └── ruby-demo-app/    # Demo app (renamed from ruby-monitor)
└── .github/workflows/    # CI/CD automation
```

## Development Commands

**Infrastructure** (requires approval):
```bash
gh workflow run "Deploy Infrastructure"  # Requires manual approval
```

**App Development** (automatic):
```bash
# Should work but currently broken - only triggers on compose changes
git add applications/your-app/
git commit -m "feat: update app"
git push origin master
```

**Debugging**:
```bash
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker ps'
```

## Credentials

**Grafana**: admin/admin123 (hardcoded in compose)
**Registry**: admin/password (from .env file)
**Server SSH**: GitHub Actions SSH key
**APIs**: Hetzner tokens, S3 credentials (GitHub secrets)

## Cost Tracking

- Hetzner cx22: €4.90/month
- Object Storage (Terraform state): €4.99/month
- **Total**: €9.89/month
- Domain costs excluded (separate expense)

## Next Priority Actions

1. **Fix GitOps**: Create per-app workflows that trigger on ANY file changes
2. **Secure Grafana**: Move to .env credentials + proper config files
3. **Restructure Repository**: Move platform services out of applications/
4. **Enhance Monitoring**: Configure Prometheus app scraping + Grafana dashboards
5. **Scale Apps**: Remove hardcoded ruby-monitor limitation

## Important Instructions

- **Infrastructure changes**: Always require approval (can destroy server)
- **App deployments**: Should be fully automatic (currently broken)
- **Documentation**: Keep minimal, essential information only
- **Costs**: Always include Object Storage in calculations
- **Focus**: Prioritize working deployment pipeline and monitoring visibility
