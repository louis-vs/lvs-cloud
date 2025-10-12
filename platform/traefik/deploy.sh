#!/bin/bash
# Traefik Deployment Script
# This script handles the deployment of Traefik reverse proxy

set -e  # Exit on any error

echo "🚀 Starting Traefik deployment..."

# Wait for cloud-init to complete (only needed on first boot)
if [ -f /var/lib/cloud/instance/boot-finished ]; then
    echo "✓ Cloud-init already completed"
else
    echo "⏳ Waiting for system setup to complete..."
    sudo cloud-init status --wait || {
        echo "❌ Cloud-init failed or timed out"
        exit 1
    }
fi

# Verify Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not available"
    exit 1
fi

# Verify required files are present
if [ ! -f "traefik.yml" ] || [ ! -f "docker-compose.yml" ]; then
    echo "❌ Required files (traefik.yml, docker-compose.yml) not found"
    exit 1
fi
echo "✅ Configuration files present"

# Create directories
sudo mkdir -p /opt/traefik
sudo mkdir -p /etc/traefik
sudo chown ubuntu:ubuntu /opt/traefik

# Copy configuration file to system location
sudo cp traefik.yml /etc/traefik/traefik.yml

# Copy docker-compose to deployment directory
sudo cp docker-compose.yml /opt/traefik/

# Deploy with Docker Compose
cd /opt/traefik
docker compose -f docker-compose.yml up -d --remove-orphans

# Verify deployment
if docker compose ps --services --filter "status=running" | grep -q "traefik"; then
    echo "✅ Traefik deployed successfully"
    docker compose ps
else
    echo "❌ Deployment failed - container is not running"
    echo "📋 Container logs:"
    docker compose logs --tail=50
    exit 1
fi

echo "🎉 Traefik deployment completed successfully"
