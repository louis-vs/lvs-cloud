#!/bin/bash
# Ruby Demo App Deployment Script
# This script handles the deployment of the Ruby demo application
# It is executed on the production server after the directory is uploaded

set -e  # Exit on any error

echo "🚀 Starting Ruby Demo App deployment..."

# Verify .env file exists (created by GitHub Actions before upload)
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found - should have been created by GitHub Actions"
    exit 1
fi

# Pull latest image
echo "📦 Pulling latest container image..."
docker compose pull

# Deploy application
echo "🔄 Deploying application..."
docker compose up -d --remove-orphans

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 5

# Check if container is running
if docker compose ps --services --filter "status=running" | grep -q "ruby-demo-app"; then
    echo "✅ Ruby Demo App deployed successfully"
    docker compose ps
else
    echo "❌ Deployment failed - container is not running"
    echo "📋 Container logs:"
    docker compose logs --tail=50
    exit 1
fi

echo "🎉 Deployment completed successfully"
