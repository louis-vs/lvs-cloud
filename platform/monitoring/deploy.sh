#!/bin/bash
# Monitoring Stack Deployment Script
# This script handles the deployment of the LGTM monitoring stack
# (Loki, Grafana, Tempo, Mimir, and Alloy)

set -e  # Exit on any error

echo "🚀 Starting Monitoring Stack deployment..."

# Verify Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not available"
    exit 1
fi

# Verify required environment variables
if [ -z "$GRAFANA_ADMIN_USER" ] || [ -z "$GRAFANA_ADMIN_PASS" ]; then
    echo "❌ Error: GRAFANA_ADMIN_USER and GRAFANA_ADMIN_PASS must be set"
    exit 1
fi

# Create main directory
sudo mkdir -p /opt/monitoring-stack
sudo chown ubuntu:ubuntu /opt/monitoring-stack
cd /opt/monitoring-stack

# Create .env file
cat > .env << EOF
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER}
GRAFANA_ADMIN_PASS=${GRAFANA_ADMIN_PASS}
EOF

# Verify all required files are present
echo "📁 Verifying configuration files..."
REQUIRED_FILES=(
    "docker-compose.prod.yml"
    "mimir/mimir.yml"
    "tempo/tempo.yml"
    "loki/local-config.yaml"
    "alloy/config.alloy"
    "grafana/provisioning/datasources/datasources.yml"
    "grafana/provisioning/dashboards/dashboards.yml"
    "grafana/provisioning/dashboards/system-overview.json"
    "grafana/provisioning/dashboards/application-metrics.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file missing: $file"
        exit 1
    fi
done

echo "✅ All configuration files present"

# Clean up any existing deployment
echo "🧹 Cleaning up existing deployment..."
docker compose down 2>/dev/null || true
docker network rm monitoring 2>/dev/null || true

# Deploy with Docker Compose
echo "🚀 Starting monitoring containers..."
docker compose -f docker-compose.prod.yml up -d --remove-orphans

# Verify deployment
FAILED_SERVICES=0
for SERVICE in grafana loki mimir tempo alloy; do
    if docker compose -f docker-compose.prod.yml ps --services --filter "status=running" | grep -q "$SERVICE"; then
        echo "✅ $SERVICE is running"
    else
        echo "❌ $SERVICE failed to start"
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
    fi
done

if [ $FAILED_SERVICES -gt 0 ]; then
    echo "❌ Deployment partially failed - $FAILED_SERVICES service(s) not running"
    echo "📋 Container logs:"
    docker compose -f docker-compose.prod.yml logs --tail=50
    exit 1
fi

echo "✅ Monitoring stack deployed successfully"
docker compose -f docker-compose.prod.yml ps

echo "🎉 Monitoring stack deployment completed successfully"
echo "📊 Grafana should be available at https://grafana.lvs.me.uk"
