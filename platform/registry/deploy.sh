#!/bin/bash
# Registry Deployment Script
# This script handles the deployment of the private Docker registry

set -e  # Exit on any error

echo "🚀 Starting Registry deployment..."

# Verify Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not available"
    exit 1
fi

# Verify htpasswd is available for authentication
if ! command -v htpasswd &> /dev/null; then
    echo "❌ htpasswd is not available (required for registry authentication)"
    exit 1
fi

# Verify required environment variables
if [ -z "$REGISTRY_USERNAME" ] || [ -z "$REGISTRY_PASSWORD" ]; then
    echo "❌ Error: REGISTRY_USERNAME and REGISTRY_PASSWORD must be set"
    exit 1
fi

# Create directories
sudo mkdir -p /opt/registry
sudo mkdir -p /etc/docker/registry/auth
sudo chown ubuntu:ubuntu /opt/registry

# Generate htpasswd file for registry authentication
echo "🔐 Creating registry authentication..."
sudo htpasswd -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" | sudo tee /etc/docker/registry/auth/htpasswd > /dev/null

# Copy all files from current directory to /opt/registry
echo "📦 Copying files to /opt/registry..."
cp -rf ./* /opt/registry/
cd /opt/registry

# Deploy with Docker Compose
docker compose -f docker-compose.yml up -d --remove-orphans

# Verify deployment
if docker compose ps --services --filter "status=running" | grep -q "registry"; then
    echo "✅ Registry deployed successfully"
    docker compose ps
else
    echo "❌ Deployment failed - container is not running"
    echo "📋 Container logs:"
    docker compose logs --tail=50
    exit 1
fi

echo "🎉 Registry deployment completed successfully"
