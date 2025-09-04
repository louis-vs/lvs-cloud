# LVS Cloud - Cost Analysis

## Monthly Costs Breakdown

### Hetzner Cloud Infrastructure

| Resource | Type | Specifications | Monthly Cost |
|----------|------|----------------|--------------|
| **Server** | cx22 | 2 vCPU, 4GB RAM, 40GB SSD | €4.90 |
| **Network** | Private Network | 10.0.0.0/16 subnet | €0.00 |
| **Firewall** | Cloud Firewall | Port rules | €0.00 |
| **SSH Key** | Management | Key storage | €0.00 |
| **IPv4** | Public IP | Static assignment | €0.00* |
| **IPv6** | Public IP | /64 subnet | €0.00 |

**Hetzner Total: €4.90/month**

*IPv4 included with server instance

### Domain & DNS

| Service | Provider | Details | Monthly Cost |
|---------|----------|---------|--------------|
| **Domain** | Your DNS Provider | lvs.me.uk registration | ~€1.00** |
| **DNS Management** | Usually included | A records for subdomains | €0.00 |

**Domain Total: ~€1.00/month**

**Annual domain cost amortized

### Data Transfer

| Type | Included | Additional Cost |
|------|----------|-----------------|
| **Outbound Traffic** | 20 TiB/month | €1.19 per TiB |
| **Inbound Traffic** | Unlimited | €0.00 |

**Expected Usage:** ~100GB/month (monitoring data)
**Data Transfer Cost: €0.00** (well within limits)

## Total Monthly Cost: ~€5.90

## Cost Comparison

### Alternative Solutions

| Solution | Monthly Cost | Limitations |
|----------|--------------|-------------|
| **AWS t3.small** | ~€20-25 | + EBS, EIP, data transfer |
| **DigitalOcean** | ~€12 | 2GB RAM droplet + extras |
| **Google Cloud** | ~€25-30 | e2-small + networking |
| **Azure B2s** | ~€20-25 | + storage + bandwidth |
| **Managed Grafana** | ~€25-50 | SaaS solutions |

**Cost Savings: 70-85%** vs cloud alternatives

## Resource Utilization

### Server Specifications (cx22)

```
CPU: 2 vCPU (shared)
RAM: 4GB DDR4
Storage: 40GB NVMe SSD
Network: 1 Gbps
Traffic: 20 TiB included
```

### Expected Resource Usage

| Service | CPU | RAM | Storage |
|---------|-----|-----|---------|
| **Traefik** | ~50m | ~50MB | ~10MB |
| **Registry** | ~100m | ~100MB | ~500MB |
| **Grafana** | ~200m | ~300MB | ~200MB |
| **Prometheus** | ~300m | ~500MB | ~2GB |
| **Loki** | ~200m | ~400MB | ~1GB |
| **Node Exporter** | ~20m | ~20MB | ~5MB |
| **Watchtower** | ~10m | ~30MB | ~10MB |
| **Ruby App** | ~100m | ~100MB | ~50MB |
| **System** | ~200m | ~500MB | ~2GB |

**Total Usage:**

- CPU: ~1.18 vCPU (59% utilization)
- RAM: ~2GB (50% utilization)
- Storage: ~6.8GB (17% utilization)

**Capacity for Growth:** Significant headroom available

## Scaling Costs

### Vertical Scaling (Hetzner Server Types)

| Server | vCPU | RAM | Storage | Monthly |
|--------|------|-----|---------|---------|
| **cx11** | 1 | 2GB | 20GB | €3.29 |
| **cx22** | 2 | 4GB | 40GB | €4.90 ⭐ |
| **cx32** | 2 | 8GB | 80GB | €9.51 |
| **cx42** | 4 | 16GB | 160GB | €18.72 |
| **cx52** | 8 | 32GB | 320GB | €37.44 |

### Horizontal Scaling

| Component | Additional Cost | When Needed |
|-----------|-----------------|-------------|
| **Load Balancer** | €5.39/month | Multiple app servers |
| **Additional Server** | €4.90/month | High availability |
| **Block Storage** | €0.043/GB/month | More persistent data |

## Cost Optimization Tips

### 1. Resource Monitoring

```bash
# Monitor actual usage
docker stats
htop
df -h
```

### 2. Log Retention

```yaml
# Limit log storage in Loki config
limits_config:
  retention_period: 168h  # 7 days
```

### 3. Prometheus Retention

```yaml
# Prometheus storage settings
--storage.tsdb.retention.time=30d
--storage.tsdb.retention.size=2GB
```

### 4. Registry Cleanup

```bash
# Automated cleanup in Watchtower
WATCHTOWER_CLEANUP=true
```

## Long-term Projections

### Year 1 Costs

- **Infrastructure**: €58.80
- **Domain**: €12.00
- **Total**: €70.80/year

### Potential Additional Costs

- **Monitoring tools**: €0 (self-hosted)
- **SSL certificates**: €0 (Let's Encrypt)
- **Backups**: €5-10/month (if needed)
- **Additional domains**: €10-15/year each

### ROI Analysis

**vs Managed Solutions:**

- **Grafana Cloud**: €25-100/month
- **DataDog**: €15-50/month per host
- **New Relic**: €25-100/month

**Annual Savings: €200-1000+**

## Cost Alerts & Monitoring

### Hetzner Usage Monitoring

- Built-in cost tracking in console
- Traffic usage alerts
- Resource utilization graphs

### Budget Recommendations

- Set budget alerts at €10/month
- Monitor traffic usage monthly
- Review resource utilization quarterly

---

**Summary: Professional-grade monitoring infrastructure for the cost of a coffee subscription ☕**

*Costs accurate as of 2025-09-03 | Prices in EUR | Hetzner Cloud pricing*
