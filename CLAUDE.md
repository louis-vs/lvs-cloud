# LVS Cloud - Private Cloud Infrastructure

## Project Purpose

Personal private cloud for seamless application deployment with enterprise-grade monitoring. Focus: cost-effective, automated deployments, "set up once, reuse many times" approach for practicing DevOps skills and hosting projects for others.

## Current Architecture

**Infrastructure**: Hetzner Cloud cx22 (2 vCPU, 4GB RAM) - €9.89/month
**Services**: Traefik → SSL/routing, Registry → container images, Monitoring → Grafana/Prometheus/Loki
**Apps**: Ruby demo app at app.lvs.me.uk
**Deployment**: GitOps via unified GitHub Actions workflow with direct SSH deployment

## Platform Status (All Core Issues Resolved ✅)

### 1. ✅ Fixed - GitOps for Apps
**Was**: Apps only deployed on compose file changes, monolithic workflow
**Now**: Unified workflow deploys on ANY file changes with dynamic app detection
**Result**: Seamless development experience, zero-downtime deployments

### 2. ✅ Fixed - Security & Credentials
**Was**: Hardcoded admin/admin123 Grafana password
**Now**: All services use secure GitHub secrets (GRAFANA_ADMIN_PASS, REGISTRY_*)
**Result**: Production-ready security across all platform services

### 3. ✅ Fixed - Scalable App Support
**Was**: Hardcoded ruby-demo-app limitation
**Now**: Dynamic matrix strategy supports unlimited apps automatically
**Result**: Any app in applications/ folder deploys automatically

### 4. ✅ Fixed - Repository Structure
**Was**: Platform services mixed with user apps in applications/
**Now**: Clean separation - platform/ for services, applications/ for user apps
**Result**: Scalable structure, clear service boundaries

### 5. Remaining - Enhanced Monitoring
**Current**: Basic system metrics, missing app-level visibility
**Needed**: Prometheus app scraping, custom Grafana dashboards, log aggregation
**Priority**: Medium (platform is fully functional without this)

## File Structure

**✅ Clean Structure Implemented**:
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
│   └── ruby-demo-app/    # Demo app
└── .github/workflows/    # CI/CD automation
```

## Development Commands

**Full Deployment** (requires approval for infrastructure changes):
```bash
gh workflow run "Deploy Infrastructure & Applications"
```

**App-Only Deployment** (automatic):
```bash
# Works perfectly - triggers on ANY file changes in applications/
git add applications/your-app/
git commit -m "feat: update app"
git push origin master  # Auto-deploys in ~5 minutes
```

**Targeted Deployment**:
```bash
# Deploy specific app only
gh workflow run "Deploy Infrastructure & Applications" -f app_name=your-app

# Deploy everything (infrastructure + platform + all apps)
gh workflow run "Deploy Infrastructure & Applications" -f deploy_everything=true
```

**Debugging**:
```bash
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker ps'
```

## Credentials

**Grafana**: admin/[GRAFANA_ADMIN_PASS] (secure GitHub secret)
**Registry**: admin/[REGISTRY_PASSWORD] (secure GitHub secret)
**Server SSH**: GitHub Actions SSH key
**APIs**: Hetzner tokens, S3 credentials (GitHub secrets)

## Cost Tracking

- Hetzner cx22: €4.90/month
- Object Storage (Terraform state): €4.99/month
- **Total**: €9.89/month
- Domain costs excluded (separate expense)

## Current Workflow Architecture

**Single Unified Pipeline** (`.github/workflows/deploy.yml`):
- **Infrastructure Job**: Terraform with manual approval for changes
- **Platform Jobs**: Traefik → Registry → Monitoring (cascade dependencies)
- **Applications Job**: Dynamic matrix strategy, auto-detects changed apps
- **Deployment Method**: Direct SSH deployment with health checks
- **Triggers**: Path-based (infrastructure/, platform/, applications/) + manual dispatch

## Next Priority Actions

1. ✅ **Fix GitOps**: Unified workflow with dynamic app detection ✅
2. ✅ **Secure Credentials**: All services use GitHub secrets ✅
3. ✅ **Repository Structure**: Clean platform/applications separation ✅
4. ✅ **Scale Apps**: Matrix strategy supports unlimited apps ✅
5. **Enhance Monitoring**: App-level metrics collection (only remaining task)

## Important Instructions

- **Infrastructure changes**: Always require approval (can destroy server)
- **App deployments**: Fully automatic on ANY file changes ✅
- **Documentation**: Keep minimal, essential information only
- **Costs**: Always include Object Storage in calculations (€9.89/month total)
- **Focus**: Platform is production-ready; monitoring enhancement is optional
- All commits should be GPG signed.
