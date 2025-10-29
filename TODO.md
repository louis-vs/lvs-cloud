# TODO

- [x] we need to update our GitHub build and push application workflow. It should attempt to pull the latest version of the existing image first, or otherwise be able to use the cached layers from the registry. This should speed up building significantly, since it prevents dependencies being reinstalled on every build.
- [ ] I want to be able to see the traefik dashboard at traefik.lvs.me.uk again, but it should be behind some kind of authentication.
- [ ] I want a proper SSO authentication server for all of my applications to be able to use. Grafana should be able to use this as a login server as well. I've done some research and authelia looks like a good option. Look into our options for incorporating an authelia server via helm.
