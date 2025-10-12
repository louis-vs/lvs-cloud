#!/bin/bash
# Ruby Demo App Deployment Script
# This script handles the deployment of the Ruby demo application
# It is executed on the production server after the directory is uploaded

set -e  # Exit on any error
set -u  # Exit on undefined variables

echo "🚀 Starting Ruby Demo App deployment..."

# Verify required environment variables
if [ -z "${POSTGRES_RUBY_PASSWORD:-}" ]; then
    echo "❌ Error: POSTGRES_RUBY_PASSWORD environment variable is not set"
    exit 1
fi

# Create .env file from template
echo "🔐 Creating environment file from template..."
envsubst < .env.template > .env

# Verify .env was created successfully
if [ ! -f .env ]; then
    echo "❌ Error: Failed to create .env file"
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
