#!/bin/bash

# Deployment script for monitoring stack
set -e

SERVER_IP="91.99.230.185"
STACK_DIR="/opt/monitoring-stack"

echo "🚀 Deploying monitoring stack to $SERVER_IP..."

# Copy files to server
echo "📁 Copying files..."
scp -r . ubuntu@$SERVER_IP:~/monitoring-stack/

# Run setup on server
echo "⚙️ Running setup..."
ssh ubuntu@$SERVER_IP << 'ENDSSH'
cd ~/monitoring-stack
chmod +x setup.sh
./setup.sh

# Copy compose file to deployment directory
sudo cp docker-compose.yml /opt/monitoring-stack/

# Start services
cd /opt/monitoring-stack
sudo docker compose up -d

echo "✅ Services started!"
echo "🔗 Access points:"
echo "  - Grafana: https://grafana.lvs.me.uk (admin/admin123)"
echo "  - Registry: https://registry.lvs.me.uk (admin/registry123)"
echo "  - Prometheus: https://prometheus.lvs.me.uk"
echo "  - Loki: https://loki.lvs.me.uk"
echo "  - Traefik: https://traefik.lvs.me.uk"
ENDSSH

echo "🎉 Deployment complete!"
