# Deployment Review - Ruby Demo App Issues

## Summary

**Date**: 2025-10-25
**Status**: Resolved - App deployed successfully
**Root Cause**: Multiple configuration issues + documentation mismatch

## What Went Wrong

### 1. DATABASE_URL Environment Variable (Critical)

**Problem**: Used shell variable substitution in Kubernetes env value

```yaml
env:
  - name: DATABASE_URL
    value: postgresql://user:$(POSTGRES_PASSWORD)@host/db
```

**Why it failed**: Kubernetes doesn't support `$(VAR)` substitution in plain `value` fields. This syntax only works in pod `command`/`args` fields.

**Fix**: Modified application to construct DATABASE_URL at runtime from individual env vars

```ruby
DB_PASSWORD = ENV.fetch('POSTGRES_PASSWORD', 'changeme')
DATABASE_URL = "postgresql://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}/#{DB_NAME}"
```

**Lesson**: Don't use shell-style substitution in Kubernetes env values. Either:

- Construct URLs in application code
- Use initContainers with envsubst
- Use Helm template functions in chart templates

### 2. Flux Image Automation Not Configured (Major)

**Problem**: Documentation promised automatic deployments on image push, but Flux Image Automation controllers were never installed.

**Evidence**:

- `flux check` shows only core controllers (helm, kustomize, source, notification)
- Image automation CRDs don't exist (`imagerepository`, `imagepolicy`, etc.)
- `platform/flux-image-automation/` directory exists but not referenced in any kustomization

**Impact**: Manual intervention required for every deployment

**Documentation mismatch**:

- DEPLOY.md line 2: "Flux image setters will update these values automatically"
- DEPLOY.md lines 112-157: Detailed Flux Image Automation setup instructions
- Reality: Feature not installed

### 3. HelmRelease Value Updates Not Applied (Major)

**Problem**: After committing changes to `values.yaml`, Flux reconciliation didn't apply them

**Steps tried**:

1. `flux reconcile kustomization apps` - Applied new git SHA ✓
2. `flux reconcile helmrelease ruby-demo-app` - Said "applied" but didn't update deployment ✗
3. Checked deployment - still had old env vars ✗

**Root cause**: Helm/Flux caching behavior when using GitRepository sources with local charts

**Fix**: Had to delete and recreate entire HelmRelease

```bash
kubectl delete helmrelease ruby-demo-app -n default
kubectl apply -f applications/ruby-demo-app/helmrelease.yaml
```

**Lesson**: HelmRelease value updates from git may require full recreation. Needs investigation.

### 4. HelmRelease Was Suspended (Minor)

**Problem**: Initial reconcile attempt failed with "resource is suspended"

**Fix**: `flux resume helmrelease ruby-demo-app`

**Root cause**: Unknown - possibly from previous troubleshooting session

## What Worked

1. **PostgreSQL user creation** - Manual SQL commands worked perfectly
2. **Secret injection** - `POSTGRES_PASSWORD` from `postgresql-auth` secret injected correctly
3. **Image building** - GitHub Actions workflow built and pushed image successfully
4. **TLS certificates** - cert-manager + Let's Encrypt worked automatically
5. **Application startup** - Once env vars fixed, app started cleanly on first try

## Current State

**All services healthy**:

```
postgresql-0:  2/2 Running (admin + ruby_demo_user configured)
registry:      1/1 Running (in-cluster with valid TLS)
ruby-demo-app: 2/2 Running (both replicas, no restarts)
```

**Verified working**:

- <https://app.lvs.me.uk/> responds with JSON
- /db/test endpoint successfully connects to PostgreSQL
- Database queries working (visits table created, data inserted)

## Remaining Issues

### 1. Automatic Deployments Not Working

**Current process** (manual):

1. Push code changes → GitHub Actions builds image as `latest` tag
2. Image pushed to registry successfully
3. **STOPS HERE** - No automatic deployment
4. Manual steps required:
   - Delete pods: `kubectl delete pods -l app=ruby-demo-app`
   - Or restart deployment: `kubectl rollout restart deployment/ruby-demo-app`

**Why**: Flux Image Automation not installed/configured

**Options**:

**Option A: Install Flux Image Automation** (Complex, Fully Automated)

- Install image-reflector-controller and image-automation-controller
- Deploy `platform/flux-image-automation/` kustomization
- Flux watches registry, commits tag updates to git, triggers Helm reconciliation
- Pros: Fully automated, git is source of truth
- Cons: Bot commits clutter git history, adds complexity, needs write access to repo

**Option B: GitHub Actions Triggers Deployment** (Simple, Fast)

- After image push, Actions calls webhook or kubectl to trigger rollout
- Uses existing `imagePullPolicy: Always` + `tag: latest`
- Pros: Simple, fast, no bot commits, clear in Actions logs
- Cons: Actions needs cluster access, deployment not purely git-driven

**Option C: Manual Rollouts** (Current, Simplest)

- Keep current process, document it clearly
- Run `kubectl rollout restart` after confirming image push
- Pros: Maximum control, simple, no additional setup
- Cons: Requires manual step, not fully automated

**Recommendation for single-developer setup**: Option B (GitHub Actions triggers deployment)

### 2. HelmRelease Value Update Behavior

**Issue**: Reconciling a HelmRelease after git changes doesn't reliably update values

**Need to investigate**:

- Is this expected Helm behavior?
- Does `valuesFiles` path resolution cache?
- Should we use `valuesFrom` instead?
- Is there a Flux setting to force re-read?

## Documentation Updates Needed

1. **DEPLOY.md**: Remove all Flux Image Automation references (or mark as optional/future)
2. **DEPLOY.md**: Document actual current deployment process
3. **DEPLOY.md**: Fix DATABASE_URL example (remove $(VAR) substitution)
4. **BOOTSTRAP.md**: Add note about HelmRelease recreation when values change
5. **New doc**: Simple deployment guide for current setup

## Lessons Learned

1. **Test environment variables**: Shell substitution patterns vary by context (shell vs K8s vs Docker)
2. **Verify documentation matches reality**: Our docs described features that weren't installed
3. **Flux reconciliation != Helm upgrade**: `flux reconcile` doesn't always force Helm to re-read values
4. **Keep deployment simple**: For single-developer projects, simpler is better than fully automated
5. **Image tags matter**: `latest` + `pullPolicy: Always` works fine with explicit rollout triggers

## Next Steps

1. Choose deployment automation approach
2. Update documentation to match reality
3. Investigate HelmRelease value update behavior
4. Consider: Do we want Flux Image Automation for a single-developer project?
