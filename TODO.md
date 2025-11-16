# TODO

- [x] releases of applications should be creating tags in the git repo with the application name and version but flux isn't doing this. fix this
- [ ] evaluate our use of namespaces in traefik and the duplication of resources between platform application directories. Is this achieving anything or just overcomplicating things? e.g. we have to duplicate our forward-auth middleware configuration and certificate.yaml across multiple platform apps now.
- [ ] Check the kubernetes script - when run in Claude Code it hangs forever, but run in a normal shell it exits as expected. It's essential that all of our scripts run well within Claude Code.
- [ ] Grafana dashboards. We have a bunch that came as default, but it's not clear which ones are actually useful for our setup. We need to evaluate the approach. Should we be storing dashboards in the git repo or is it sufficient to store them in Grafana itself.
- [ ] platform/postgresql-new should just be called platform/postgresql
- [ ] add readmes to all of the subfolders of platform. These should contain a brief summary of what the folder contains, including e.g. a list of what services are deployed.
- [ ] set up SOPS for secrets management
