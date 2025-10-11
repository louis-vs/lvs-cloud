# Operations & Troubleshooting

## Monitoring

### Access Points

**Internet-accessible services:**

- **Grafana**: <https://grafana.lvs.me.uk> (admin/[secure-password])
- **Registry**: <https://registry.lvs.me.uk> (see .env for credentials)
- **Server SSH**: `ssh ubuntu@$(dig +short app.lvs.me.uk)`

**Internal services** (access via Grafana or SSH):

- **PostgreSQL**: `postgresql:5432` (database server)
- **Mimir**: `http://mimir:8080` (metrics storage & query)
- **Tempo**: `http://tempo:3200` (distributed tracing)
- **Loki**: `http://loki:3100` (log aggregation)

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

### PostgreSQL Issues

```bash
# Check PostgreSQL status
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker logs postgresql'

# Test database connectivity
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql pg_isready -U postgres'

# Connect to PostgreSQL admin console
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec -it postgresql psql -U postgres'

# Check database connections
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "SELECT datname, usename, client_addr FROM pg_stat_activity WHERE state = '\''active'\'';"'

# View database sizes
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;"'

# Restart PostgreSQL service
ssh ubuntu@$(dig +short app.lvs.me.uk) 'cd /opt/postgresql && docker compose restart'
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
# Check disk space (including block storage)
ssh ubuntu@$(dig +short app.lvs.me.uk) 'df -h'

# Check persistent data usage
ssh ubuntu@$(dig +short app.lvs.me.uk) 'du -sh /mnt/data/*'

# PostgreSQL data usage specifically
ssh ubuntu@$(dig +short app.lvs.me.uk) 'du -sh /mnt/data/postgresql'

# Check memory usage
ssh ubuntu@$(dig +short app.lvs.me.uk) 'free -h'

# Container resource usage
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker stats --no-stream'
```

### Database Backups

```bash
# Backup all databases
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql pg_dumpall -U postgres > /tmp/lvs-cloud-backup-$(date +%Y%m%d).sql'

# Backup specific database
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql pg_dump -U postgres ruby_demo > /tmp/ruby-demo-backup-$(date +%Y%m%d).sql'

# Download backup to local machine
scp ubuntu@$(dig +short app.lvs.me.uk):/tmp/lvs-cloud-backup-*.sql ./

# Restore from backup (DESTRUCTIVE)
# scp ./backup.sql ubuntu@$(dig +short app.lvs.me.uk):/tmp/
# ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec -i postgresql psql -U postgres < /tmp/backup.sql'
```

### Log Cleanup

```bash
# Docker log cleanup (logs can get large)
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker system prune -f'
```

### Updates

- **OS updates**: Handled automatically by cloud-init
- **Container updates**: Watchtower checks every 5 minutes
- **SSL renewal**: Automatic via Traefik
- **Metrics collection**: Grafana Alloy scrapes every 15s

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

## Cost Tracking

- Hetzner cx22: €4.90/month
- Object Storage (Terraform state): €4.99/month
- **Total**: €9.89/month
- Domain costs excluded

**Monitor**: Check Hetzner Console for unexpected usage spikes.
