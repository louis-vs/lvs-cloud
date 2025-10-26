# TODO

- [ ] can we make our demo ruby app display the correct version that's actually deployed according to the helm chart
- [ ] we need to restore the LGTM monitoring stack. All the config has been completely erased but you can check the git history to see what it used to look like.
  - [ ] platform/monitoring subfolder
  - [ ] loki, grafana, tempo, mimir
  - [ ] plug into k8s infra and get all the logs we can stored
  - [ ] get a couple essential Grafana dashboards that show the status of our cluster and the node, and create a dashboard for the ruby app as well
  - [ ] persist storage of logs and metrics using Longhorn
- [ ] make sure that our backups to S3 aren't taking up loads of storage, since we are cost limited here. We need a job that deletes backups older than a week.
- [ ] check licence restrictions of the software we're using and add the most restrictive licence possible to the code. We'll consider relicensing later once we're sure what's going on, and individual apps can have different licensing.
