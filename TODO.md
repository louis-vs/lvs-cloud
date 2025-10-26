# TODO

- [x] make it clearer how we connect to the cluster. Improve the scripts/connect-k8s.sh somehow.
  - [x] sort out kubeconfig setup - we shouldn't need to export it in every new shell, it should just work. This is making claude code unable to handle command permissions as well which is a pain.
- [x] now that we have persistent etcd, we need to rethink bootstrap. Documentation needs to be clear that most of the steps will only actually need to run if etcd is lost, since most config is preserved. The order of steps needs to be changed. For example, we shouldn't be asking for credentials until we actually need them, to minimise the amount of manual input needed. We also need a more robust check to see if flux is bootstrapped, to account for situations where the bootstrap command is interrupted before properly completing.
  - [x] BOOTSTRAP.md restructured with clear Fresh vs Server Recreation sections
  - [x] bootstrap.sh auto-detects scenario and runs verify-only mode for server recreation
  - [x] Credentials only collected when needed (fresh bootstrap)
  - [x] Improved Flux check verifies kustomizations, not just namespace
- [x] I don't like the structure of having DEPLOY.md, OPS.md and POSTGRES.md. We should just have a single doc file that lists the steps needed to set up an app from scratch. Basically this should just be creating PostgreSQL secrets, and creating a new user and database on the server. We should have automated away most of the steps. We will need to document the basic steps for debugging the state of the cluster, since things will need manual kicks every now and then (to avoid waiting for automatic reconciliation processes). Again, these docs should be minimal and to-the-point.
- [x] Create DISASTER_RECOVERY.md. This needs to detail how to recreate the server from scratch if everything is lost. It can probably mostly reference existing documentation. Bootstrap should just work, recreating etcd.
  - [x] We need to be clear about the expectations. Block storage might end up being deleted by an incorrect Terraform run. We will lose etcd state, but should be able to recover PostgreSQL and registry from S3 backups. We'll then need to manually relink this into Longhorn. Recovery from S3 loss is obviously impossible, and that's fine; it just needs to be documented as a risk. Depending on backup frequency there is a risk of loss due to outdated backups, which again we are accepting. We need to document S3 backup frequency. S3 buckets are created outside of Terraform, that needs to be clear in the docs.
  - [x] We need DR wargames where we test the DR strategy. There should be a disaster recovery checklist, and every time it is used a new file (i.e. DR_2025-01-01.md) should be created with the checklist from that date. This should be in a new directory within infrastructure/. Basic DR will just be, can we handle a recreate of the server. Advanced DR will delete the persist volume and test the S3 backups. Again, it's just me doing this so it should be quite straightforward. Maybe the only finicky thing is reassigning the restored volumes, the exact commands for this need to be documented.
- [ ] can we make our demo ruby app display the correct version that's actually deployed according to the helm chart
- [ ] we need to restore the LGTM monitoring stack. All the config has been completely erased but you can check the git history to see what it used to look like.
  - [ ] platform/monitoring subfolder
  - [ ] loki, grafana, tempo, mimir
  - [ ] plug into k8s infra and get all the logs we can stored
  - [ ] get a couple essential Grafana dashboards that show the status of our cluster and the node, and create a dashboard for the ruby app as well
  - [ ] persist storage of logs and metrics using Longhorn
