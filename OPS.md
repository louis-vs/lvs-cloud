# Operations & Troubleshooting

## Monitoring

### Access Points
- **Grafana**: https://grafana.lvs.me.uk (admin/[secure-password])
- **Prometheus**: https://prometheus.lvs.me.uk
- **Server SSH**: `ssh ubuntu@$(dig +short app.lvs.me.uk)`

### Current Critical Issues
**Platform Issues**:
- [x] **Security**: All services use secure credentials from GitHub secrets ✅
- [x] **Structure**: Clean separation - platform/ for services, applications/ for apps ✅
- [x] **GitOps**: Apps deploy automatically on ANY file changes ✅

**Monitoring Gaps**:
- [ ] Prometheus scraping app metrics
- [ ] Custom Grafana dashboards
- [ ] App health checks
- [ ] Log aggregation from apps
- [ ] Alert rules

### What's Currently Monitored
- System metrics (CPU, memory, disk) via Node Exporter
- Container status via Docker
- SSL certificate expiry via Traefik

## Common Issues

### Services Down
```bash
# Check all containers
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker ps -a'

# Restart specific service
ssh ubuntu@$(dig +short app.lvs.me.uk) 'cd /opt/monitoring-stack && docker compose restart grafana'

# Check logs
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker logs grafana'
```

### SSL Certificate Problems
```bash
# Check Traefik logs
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker logs traefik | grep -i acme'

# Force certificate renewal
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker restart traefik'
```

### App Not Updating
```bash
# Check GitHub Actions workflow status
gh run list --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)

# Force app deployment
gh workflow run "Deploy Infrastructure & Applications" -f app_name=ruby-demo-app

# Check app container status
ssh ubuntu@$(dig +short app.lvs.me.uk) 'cd /opt/apps/ruby-demo-app && docker compose ps'

# Force manual update
ssh ubuntu@$(dig +short app.lvs.me.uk) 'cd /opt/apps/ruby-demo-app && docker compose pull && docker compose up -d'
```

### Registry Issues
```bash
# Test registry login
echo "$REGISTRY_PASS" | docker login registry.lvs.me.uk -u admin --password-stdin

# Check registry logs
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker logs registry'
```

## Maintenance

### Resource Usage
```bash
# Check disk space
ssh ubuntu@$(dig +short app.lvs.me.uk) 'df -h'

# Check memory usage
ssh ubuntu@$(dig +short app.lvs.me.uk) 'free -h'

# Container resource usage
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker stats --no-stream'
```

### Log Cleanup
```bash
# Docker log cleanup (logs can get large)
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker system prune -f'
```

### Updates
- **OS updates**: Handled by Watchtower automatically
- **Container updates**: Watchtower checks every 5 minutes
- **SSL renewal**: Automatic via Traefik

## Debugging Workflows

### GitHub Actions Failing
```bash
# Check workflow status
gh run list --repo your-username/lvs-cloud

# View specific run logs
gh run view <run-id> --log
```

### Terraform State Issues
```bash
# View current state
cd infrastructure && terraform show

# Refresh state
terraform refresh

# If corrupted, reimport resources
terraform import hcloud_server.main <server-id>
```

### Network Issues
```bash
# Check Docker networks
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker network ls'

# Recreate web network if needed
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker network create web'
```

## Performance Monitoring

### Current Resource Usage (~50% capacity)
- **CPU**: ~1.2/2 vCPU used
- **RAM**: ~2GB/4GB used
- **Storage**: ~7GB/40GB used
- **Network**: Minimal usage

### Scaling Triggers
Consider upgrading if:
- CPU consistently >80%
- RAM consistently >90%
- Storage >80%
- Response times degrading

### Next Server Size
**cx32**: 2 vCPU, 8GB RAM, 80GB SSD (+€4.61/month)

## Security

### Current Measures
- SSH key authentication only
- Firewall rules (HTTP/HTTPS/SSH only)
- Registry authentication
- SSL everywhere
- Container isolation

### Regular Checks
- Monitor failed SSH attempts: `ssh ubuntu@$(dig +short app.lvs.me.uk) 'grep "Failed password" /var/log/auth.log'`
- Check open ports: `nmap app.lvs.me.uk`

## Backup Strategy

**Current**: No automated backups configured

**Critical Data**:
- Grafana dashboards: `/var/lib/grafana`
- Prometheus data: `/var/lib/prometheus`
- Container registry: `/var/lib/registry`

**Recovery**: Most data recreated automatically, but custom dashboards/configs would be lost.

## Cost Monitoring

**Monthly Breakdown**:
- Hetzner cx22 server: €4.90
- Object Storage: €4.99
- **Total**: €9.89/month

**Monitor**: Check Hetzner Console for unexpected usage spikes.
