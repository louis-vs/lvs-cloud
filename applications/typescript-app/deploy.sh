#!/bin/bash

set -e

echo "🚀 Starting Typescript App deployment..."

# Verify .env file exists (created by GitHub Actions before upload)
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found - should have been created by GitHub Actions"
    exit 1
fi

echo "📝 Using .env file (passwords masked):"
sed 's/\(PASSWORD=\).*/\1***/' .env

# Use the production compose file
COMPOSE_FILE="docker-compose.prod.yml"

# Pull latest image
echo "📦 Pulling latest container image..."
docker compose -f "$COMPOSE_FILE" pull

# Deploy application
echo "🔄 Deploying application..."
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 5

# Check if container is running
if docker compose -f "$COMPOSE_FILE" ps --services --filter "status=running" | grep -q "typescript-app"; then
    echo "✅ Ruby Demo App deployed successfully"
    docker compose -f "$COMPOSE_FILE" ps
else
    echo "❌ Deployment failed - container is not running"
    echo "📋 Container logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail=50
    exit 1
fi

echo "🎉 Deployment completed successfully"
