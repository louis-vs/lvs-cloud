#!/bin/bash

set -e

echo "🚀 Starting Typescript App deployment..."

# Regenerate .env from template with current environment variables
if [ -f .env.template ]; then
    echo "🔧 Regenerating .env from template..."
    envsubst < .env.template > .env
    echo "📝 Generated .env contents (passwords masked):"
    sed 's/\(PASSWORD=\).*/\1***/' .env
else
    echo "⚠️ Warning: .env.template not found, using existing .env"
fi

# Verify .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    exit 1
fi

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
