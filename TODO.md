# TODO

- [ ] we need to restore the LGTM monitoring stack. All the config has been completely erased but you can check the git history to see what it used to look like.
  - [ ] platform/monitoring subfolder
  - [ ] loki, grafana, tempo, mimir
  - [ ] plug into k8s infra and get all the logs we can stored
  - [ ] get a couple essential Grafana dashboards that show the status of our cluster and the node, and create a dashboard for the ruby app as well
  - [ ] persist storage of logs and metrics using Longhorn
- [ ] make sure that our backups to S3 aren't taking up loads of storage, since we are cost limited here. We need a job that deletes backups older than a week.
- [ ] check licence restrictions of the software we're using and add the most restrictive licence possible to the code. We'll consider relicensing later once we're sure what's going on, and individual apps can have different licensing.
- [ ] we need to update our GitHub build and push application workflow. It should attempt to pull the latest version of the existing image first, or otherwise be able to use the cached layers from the registry. This should speed up building significantly, since it prevents dependencies being reinstalled on every build.
- [ ] I want to be able to see the traefik dashboard at traefik.lvs.me.uk again, but it should be behind some kind of authentication.
- [ ] I want a proper SSO authentication server for all of my applications to be able to use. Grafana should be able to use this as a login server as well. I've done some research and authelia looks like a good option. Look into our options for incorporating an authelia server via helm.
