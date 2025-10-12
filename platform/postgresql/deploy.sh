#!/bin/bash
# PostgreSQL Deployment Script
# This script handles the deployment of PostgreSQL database server

set -e  # Exit on any error

echo "🚀 Starting PostgreSQL deployment..."

# Verify Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not available"
    exit 1
fi

# Verify required environment variables
if [ -z "$POSTGRES_ADMIN_PASSWORD" ] || [ -z "$POSTGRES_RUBY_PASSWORD" ] || \
   [ -z "$POSTGRES_TS_PASSWORD" ] || [ -z "$POSTGRES_PYTHON_PASSWORD" ] || \
   [ -z "$POSTGRES_GO_PASSWORD" ]; then
    echo "❌ Error: All PostgreSQL password environment variables must be set"
    exit 1
fi

# Create directories
sudo mkdir -p /opt/postgresql
sudo chown ubuntu:ubuntu /opt/postgresql
cd /opt/postgresql

# Create .env file
cat > .env << EOF
POSTGRES_ADMIN_PASSWORD=${POSTGRES_ADMIN_PASSWORD}
POSTGRES_RUBY_PASSWORD=${POSTGRES_RUBY_PASSWORD}
POSTGRES_TS_PASSWORD=${POSTGRES_TS_PASSWORD}
POSTGRES_PYTHON_PASSWORD=${POSTGRES_PYTHON_PASSWORD}
POSTGRES_GO_PASSWORD=${POSTGRES_GO_PASSWORD}
EOF

# Verify all required files are present
echo "📁 Verifying PostgreSQL configuration files..."
REQUIRED_FILES=(
    "docker-compose.yml"
    "postgresql.conf"
    "init-scripts/01-create-databases.sql"
    "init-scripts/02-create-users.sql"
    "init-scripts/03-grant-permissions.sql"
    "init-scripts/04-enable-extensions.sql"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file missing: $file"
        exit 1
    fi
done

echo "✅ All configuration files present"

# Substitute password placeholders in user creation script
echo "🔐 Configuring database user passwords..."
sed -i "s/\${POSTGRES_RUBY_PASSWORD}/${POSTGRES_RUBY_PASSWORD}/g" init-scripts/02-create-users.sql
sed -i "s/\${POSTGRES_TS_PASSWORD}/${POSTGRES_TS_PASSWORD}/g" init-scripts/02-create-users.sql
sed -i "s/\${POSTGRES_PYTHON_PASSWORD}/${POSTGRES_PYTHON_PASSWORD}/g" init-scripts/02-create-users.sql
sed -i "s/\${POSTGRES_GO_PASSWORD}/${POSTGRES_GO_PASSWORD}/g" init-scripts/02-create-users.sql

echo "✅ All configuration files prepared"

# Check if PostgreSQL is already running
POSTGRES_RUNNING=false
if docker compose ps --services --filter "status=running" | grep -q "postgresql"; then
    echo "⚠️  PostgreSQL is already running"
    POSTGRES_RUNNING=true
fi

# Stop PostgreSQL if running (for clean deployment)
if [ "$POSTGRES_RUNNING" = true ]; then
    echo "🛑 Stopping PostgreSQL for configuration update..."
    docker compose down 2>/dev/null || true
fi

# Deploy with Docker Compose
echo "🚀 Starting PostgreSQL container..."
docker compose up -d --remove-orphans

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker exec postgresql pg_isready -U postgres >/dev/null 2>&1; then
        echo "✅ PostgreSQL is ready"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "❌ PostgreSQL failed to become ready after $MAX_ATTEMPTS attempts"
        echo "📋 Container logs:"
        docker compose logs --tail=50
        exit 1
    fi
    sleep 2
done

# Verify deployment
if docker compose ps --services --filter "status=running" | grep -q "postgresql"; then
    echo "✅ PostgreSQL deployed successfully"
    docker compose ps

    # Show database info
    echo ""
    echo "📊 Database Status:"
    docker exec postgresql psql -U postgres -c "\l" | grep -E "ruby_demo|typescript_app|python_api|go_service" || echo "Databases not yet initialized (will be created on first start)"
else
    echo "❌ Deployment failed - container is not running"
    echo "📋 Container logs:"
    docker compose logs --tail=50
    exit 1
fi

# Note about init scripts
if [ "$POSTGRES_RUNNING" = true ]; then
    echo ""
    echo "⚠️  Note: PostgreSQL was already running. Init scripts only run on first deployment."
    echo "To manually run updated init scripts:"
    echo "  docker exec -i postgresql psql -U postgres < init-scripts/01-create-databases.sql"
    echo "  docker exec -i postgresql psql -U postgres < init-scripts/02-create-users.sql"
    echo "  docker exec -i postgresql psql -U postgres < init-scripts/03-grant-permissions.sql"
    echo "  docker exec -i postgresql psql -U postgres < init-scripts/04-enable-extensions.sql"
fi

echo "🎉 PostgreSQL deployment completed successfully"
