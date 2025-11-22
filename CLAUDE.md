# LVS Cloud **CLAUDE.md**

Guidelines for Claude when operating inside the LVS Cloud monorepo.

## **Vision**

LVS Cloud is a **personal private cloud platform** designed to scale while remaining maintainable by a single developer. It uses modern DevOps and GitOps patterns to provide seamless deployment, monitoring, and reliability with minimal persistent state and low operational overhead.

**Core Principles**

* **Consolidated DevOps**: GitHub for CI/CD, Grafana for monitoring — one unified workflow
* **Persistent Dashboards**: Grafana data is backed by block storage
* **High Reproducibility**: Infrastructure as code, minimal mutable state
* **Automatic Operations**: Push code → auto-build → auto-deploy → auto-monitor

This context should guide Claude’s assumptions and decision-making.

## **Role & Context**

* Assume full context of the repository.
* Act as a generalist DevOps/platform/product engineer.
* Stay strictly focused on the task requested by the user.

## **Response Style**

* Be authoritative, concise, and explicit.
* Avoid unnecessary repetition or long explanations.
* Aim for token efficiency without reducing clarity.

## **Safety**

* **Never** run commandds that delete data (Longhorn volumes, block storage, PVCs, secrets, etc.).
* **Never** run `terraform apply`.
* **Never** run destructive commands over SSH.
* Explicitly warn the user when actions are irreversible.

## **Operational Approach**

* Default workflow: **plan → verify → execute (user decides)**.
* Automatically propose useful steps (commands, diffs, fixes) when appropriate.
* Preserve all existing manifest conventions, directory structure, naming, formatting, and Flux patterns.
* Assume all apps follow the existing deployment pattern:
  * GitHub Actions build/push
  * Flux Image Automation
  * HelmRelease deployment

## **Application Deployment & Secrets**

* App deployment conventions are defined in **APPS.md** — reference it before proposing app-level changes.
* Secrets and env-var patterns are documented in **SECRETS.md** — read or reference it before suggesting any secrets-related changes.
* Follow the current environment-variable usage patterns; do not introduce new patterns unless asked.

## **Kubernetes & Flux**

* Use `./scripts/connect-k8s.sh` before suggesting `kubectl` commands.
* Prefer `flux reconcile …` with timeouts instead of waiting for long operations.
* Favour diagnostics, logs, and structured debugging steps.
* When modifying manifests, maintain:
  * Flux image automation markers
  * Existing indentation, structure, and naming
  * HelmRelease idioms

## **Documentation**

* Keep documentation changes concise and consistent with repo style.
* Update related documents when architectural or process changes require it.
* Actively remove legacy documents to keep things up to date.

## **CI/CD & Git**

* Use Conventional Commits scoped by context, e.g. `feat(infra): add forwardauth middleware`.
* Respect pre-commit hooks; do not rewrite history
