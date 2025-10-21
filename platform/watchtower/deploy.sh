#!/bin/bash
# Watchtower Deployment Script
# This script handles the deployment of Watchtower for automatic container updates

set -e  # Exit on any error

echo "🚀 Starting Watchtower deployment..."

# Verify Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not available"
    exit 1
fi

# Verify required environment variables
if [ -z "$REGISTRY_USERNAME" ] || [ -z "$REGISTRY_PASSWORD" ]; then
    echo "❌ Error: REGISTRY_USERNAME and REGISTRY_PASSWORD must be set"
    exit 1
fi

# Create directories
sudo mkdir -p /opt/watchtower
sudo mkdir -p /etc/watchtower/config
sudo chown ubuntu:ubuntu /opt/watchtower

# Create registry authentication config for Watchtower
echo "🔐 Creating registry authentication for Watchtower..."
AUTH_STRING=$(echo -n "${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}" | base64 -w 0)
sudo tee /etc/watchtower/config/config.json > /dev/null << EOF
{
  "auths": {
    "registry.lvs.me.uk": {
      "auth": "$AUTH_STRING"
    }
  }
}
EOF

# Copy all files from current directory to /opt/watchtower
echo "📦 Copying files to /opt/watchtower..."
cp -rf ./* /opt/watchtower/
cd /opt/watchtower

# Verify docker-compose file is present
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi
echo "✅ Configuration files present"

# Deploy with Docker Compose
echo "🚀 Starting Watchtower container..."
docker compose up -d --remove-orphans

# Verify deployment
if docker compose ps --services --filter "status=running" | grep -q "watchtower"; then
    echo "✅ Watchtower deployed successfully"
    docker compose ps

    # Show Watchtower logs to verify it's working
    echo ""
    echo "📋 Recent Watchtower activity:"
    docker compose logs --tail=20
else
    echo "❌ Deployment failed - container is not running"
    echo "📋 Container logs:"
    docker compose logs --tail=50
    exit 1
fi

echo "🎉 Watchtower deployment completed successfully"
echo "🔄 Watchtower will now monitor containers with the 'watchtower.enable=true' label"
