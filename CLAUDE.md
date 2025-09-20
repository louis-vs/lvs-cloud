# LVS Cloud - Private Cloud Infrastructure

You are build LVS Cloud, a private cloud which I can use to deploy projects. The core idea is to use modern DevOps practices to seamlessly deploy and monitor applications. Maximise reproducibility and only rely on persistence where necessary.

## Current Architecture

The project is hosted in Hetzner. Infrastructure is handled with Terraform. Applications are deployed from the self-hosted container registry.

## File Structure

```plaintext
├── README.md             # Status, quick commands, current issues
├── DEPLOY.md             # App deployment, infrastructure setup
├── OPS.md                # Troubleshooting, monitoring, maintenance
├── infrastructure/       # Terraform for Hetzner Cloud
├── platform/             # Platform services
│   ├── traefik/          # SSL/routing
│   ├── monitoring/       # Grafana, Prometheus, Loki
│   └── registry/         # Container registry
├── applications/         # User applications only
│   └── ruby-demo-app/    # Demo app
└── .github/workflows/    # CI/CD automation
```

## Development Process

- Create a detailed plan before writing any code
- Commit changes often

## Important Instructions

Keep documentation concise and to the point.

IMPORTANT: All commits should be GPG signed. However, pinentry *will break your prompt*. Before you run a git command, check that this script has output `gpg-connect-agent 'keyinfo --list' /bye | grep ' 1 '`. If there is not output, ASK THE USER TO RUN THE `reset-gpg` script.

NEVER use `--no-verify` when using `git commit`.
