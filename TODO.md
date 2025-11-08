# TODO

- [ ] Let's audit the backup process. We need to make sure our S3 backups are working as expected and that our cluster will be able to sustain the node being destroyed. Currently, it looks like the backup buckets are empty, so something might not be configured correctly. Longhorn has a built-in backup system so it should be able to manage backups on a Hetzner S3 bucket.
- [ ] work out how to set up alerting using our monitoring stack. Ideally these would send email alerts.
- [ ] Let's do a full audit of LVS Cloud. The main focus should be on reliability and security. This is a non-exhaustive list of things we should check for:
  - How are we storing secrets? Is this maintainable? Is this resilient?
  - How much manual work is needed to maintain? For example, currently the bootstrap script needs us to manually input secrets. We shouldn't need to use that script often as it's a last resort, but still this seems bad. I have used credstash to store secrets in a bucket before - can we use a tool like that? One that doesn't require anything running on the cluster and can store stuff in our Hetzner Object storage.
  - Are there any inconsistencies with configuration? In particular we need to make sure the cloud-init script is very well maintained and that every command in it is being called correctly.
  - Do we have a documented way of debugging cloud-init issues?
- [ ] evaluate our use of namespaces in traefik and the duplication of resources between platform application directories. Is this achieving anything or just overcomplicating things? e.g. we have to duplicate our forward-auth middleware configuration and certificate.yaml across multiple platform apps now.
- [ ] Check the kubernetes script - when run in Claude Code it hangs forever, but run in a normal shell it exits as expected. It's essential that all of our scripts run well within Claude Code.
- [ ] Grafana dashboards. We have a bunch that came as default, but it's not clear which ones are actually useful for our setup. We need to evaluate the approach. Should we be storing dashboards in the git repo or is it sufficient to store them in Grafana itself.
- [ ] platform/postgresql-new should just be called platform/postgresql
- [ ] add readmes to all of the subfolders of platform. These should contain a brief summary of what the folder contains, including e.g. a list of what services are deployed.
