# PostgreSQL Database Management

PostgreSQL database server for LVS Cloud applications with per-app databases and users.

## Quick Start

### Connection Strings

```bash
# Ruby Demo App
DATABASE_URL=postgresql://ruby_demo_user:${POSTGRES_RUBY_PASSWORD}@postgresql:5432/ruby_demo

# Python API
DATABASE_URL=postgresql://python_user:${POSTGRES_PYTHON_PASSWORD}@postgresql:5432/python_api

# Go Service
DATABASE_URL=postgresql://go_user:${POSTGRES_GO_PASSWORD}@postgresql:5432/go_service
```

### Common Database Tasks

```bash
# Connect to PostgreSQL admin console
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec -i postgresql psql -U postgres'

# List all databases
\l

# Connect to specific database
\c ruby_demo

# List tables in current database
\dt

# List all users
\du

# Exit psql
\q
```

## Database Management

### Adding a New Application Database

**All PostgreSQL init scripts are idempotent** - they can be run multiple times safely. This means you can add new databases and users without recreating the entire PostgreSQL setup.

#### Step 1: Update Initialization Scripts

Add to `platform/postgresql/init-scripts/01-create-databases.sql`:

```sql
-- New App Database (idempotent)
SELECT 'CREATE DATABASE new_app
    WITH
    OWNER = postgres
    ENCODING = ''UTF8''
    LC_COLLATE = ''en_US.utf8''
    LC_CTYPE = ''en_US.utf8''
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'new_app')\gexec

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_database WHERE datname = 'new_app') THEN
        EXECUTE 'COMMENT ON DATABASE new_app IS ''Database for new application''';
    END IF;
END
$$;
```

Add to `platform/postgresql/init-scripts/02-create-users.sql`:

```sql
-- New App User (idempotent - creates or updates password)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'new_app_user') THEN
        CREATE USER new_app_user WITH
            PASSWORD '${POSTGRES_NEW_APP_PASSWORD}'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOINHERIT
            LOGIN
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT -1;
        COMMENT ON ROLE new_app_user IS 'Application user for new app';
    ELSE
        -- Update password if user already exists
        ALTER USER new_app_user WITH PASSWORD '${POSTGRES_NEW_APP_PASSWORD}';
    END IF;
END
$$;
```

Add to `platform/postgresql/init-scripts/03-grant-permissions.sql`:

```sql
-- New App Permissions (idempotent - GRANT statements don't error if permission exists)
\c new_app
GRANT CONNECT ON DATABASE new_app TO new_app_user;
GRANT ALL ON SCHEMA public TO new_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO new_app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO new_app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO new_app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO new_app_user;
```

Add to `platform/postgresql/init-scripts/04-enable-extensions.sql`:

```sql
\c new_app
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
```

#### Step 2: Add GitHub Secrets

Add `POSTGRES_NEW_APP_PASSWORD` to GitHub repository secrets.

#### Step 3: Update GitHub Actions Workflow

Add to `.github/workflows/deploy.yml` in the PostgreSQL deployment section:

```bash
# In the cat > .env << 'EOF' section
POSTGRES_NEW_APP_PASSWORD=${{ secrets.POSTGRES_NEW_APP_PASSWORD }}

# In the sed commands section
sed -i "s/\${POSTGRES_NEW_APP_PASSWORD}/${{ secrets.POSTGRES_NEW_APP_PASSWORD }}/g" init-scripts/02-create-users.sql
```

#### Step 4: Run Init Scripts Manually

Since the database already exists, the init scripts won't run automatically. Run them manually:

```bash
# SSH to server
ssh ubuntu@$(dig +short app.lvs.me.uk)

# Go to PostgreSQL directory
cd /opt/postgresql

# Run the updated init scripts
docker exec -i postgresql psql -U postgres < init-scripts/01-create-databases.sql
docker exec -i postgresql psql -U postgres < init-scripts/02-create-users.sql
docker exec -i postgresql psql -U postgres < init-scripts/03-grant-permissions.sql
docker exec -i postgresql psql -U postgres -d new_app < init-scripts/04-enable-extensions.sql
```

#### Step 5: Verify

```bash
# Check database was created
docker exec postgresql psql -U postgres -c "\l" | grep new_app

# Check user was created
docker exec postgresql psql -U postgres -c "\du" | grep new_app_user

# Test connection
docker exec postgresql psql -U new_app_user -d new_app -c "SELECT 1"
```

#### Alternative: Automated via GitHub Actions

Push changes to Git to trigger the PostgreSQL deployment workflow, which will download the updated init scripts. Then manually run them as shown in Step 4.

### User & Permissions Management

```bash
# Create new user manually (if needed)
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "CREATE USER myuser WITH PASSWORD '\''mypassword'\'';"'

# Grant database access
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "GRANT CONNECT ON DATABASE mydatabase TO myuser;"'

# Grant schema permissions
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "GRANT USAGE, CREATE ON SCHEMA public TO myuser;"'

# Grant table permissions
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -d mydatabase -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO myuser;"'

# Remove user access
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "REVOKE CONNECT ON DATABASE mydatabase FROM myuser;"'

# Drop user
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "DROP USER myuser;"'
```

## Backup & Recovery

### Manual Backups

```bash
# Backup all databases
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql pg_dumpall -U postgres > /tmp/full-backup-$(date +%Y%m%d-%H%M%S).sql'

# Backup specific database
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql pg_dump -U postgres -d ruby_demo > /tmp/ruby-demo-$(date +%Y%m%d-%H%M%S).sql'

# Backup with compression
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql pg_dump -U postgres -d ruby_demo | gzip > /tmp/ruby-demo-$(date +%Y%m%d-%H%M%S).sql.gz'

# Download backup locally
scp ubuntu@$(dig +short app.lvs.me.uk):/tmp/ruby-demo-*.sql.gz ./
```

### Restore Procedures

```bash
# Upload backup to server
scp ./backup.sql ubuntu@$(dig +short app.lvs.me.uk):/tmp/

# Restore full backup (DESTRUCTIVE - drops all databases)
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec -i postgresql psql -U postgres < /tmp/backup.sql'

# Restore specific database
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec -i postgresql psql -U postgres -d ruby_demo < /tmp/ruby-demo-backup.sql'

# Restore from compressed backup
ssh ubuntu@$(dig +short app.lvs.me.uk) 'zcat /tmp/backup.sql.gz | docker exec -i postgresql psql -U postgres'
```

### Recovery from Complete Data Loss

1. **Redeploy PostgreSQL** via GitHub Actions
2. **Databases and users recreated** automatically from initialization scripts
3. **Restore data** from latest backup:

```bash
scp ./latest-backup.sql ubuntu@$(dig +short app.lvs.me.uk):/tmp/
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec -i postgresql psql -U postgres < /tmp/latest-backup.sql'
```

## Monitoring & Troubleshooting

### Health Checks

```bash
# PostgreSQL service status
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql pg_isready -U postgres'

# Check active connections
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "SELECT datname, usename, client_addr, state FROM pg_stat_activity WHERE state = '\''active'\'';"'

# Database sizes
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC;"'

# Table sizes in specific database
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -d ruby_demo -c "SELECT schemaname,tablename,pg_size_pretty(pg_total_relation_size(schemaname||'\''.'\'||tablename)) FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'\''.'\'||tablename) DESC;"'
```

### Performance Monitoring

```bash
# Connection count per database
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"'

# Long running queries
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '\''5 minutes'\'';"'

# Lock monitoring
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "SELECT blocked_locks.pid AS blocked_pid, blocked_activity.usename AS blocked_user, blocking_locks.pid AS blocking_pid, blocking_activity.usename AS blocking_user, blocked_activity.query AS blocked_statement FROM pg_catalog.pg_locks blocked_locks JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation WHERE NOT blocked_locks.granted;"'
```

### Common Issues

**Connection refused:**

```bash
# Check if PostgreSQL container is running
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker ps | grep postgresql'

# Restart PostgreSQL
ssh ubuntu@$(dig +short app.lvs.me.uk) 'cd /opt/postgresql && docker compose restart'
```

**Out of disk space:**

```bash
# Check disk usage
ssh ubuntu@$(dig +short app.lvs.me.uk) 'df -h /mnt/data'

# Check PostgreSQL data directory size
ssh ubuntu@$(dig +short app.lvs.me.uk) 'du -sh /mnt/data/postgresql'

# Clean up old log files if needed
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql find /var/lib/postgresql/data/log -name "*.log" -mtime +7 -delete'
```

**Authentication failures:**

```bash
# Check user exists
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "\du"'

# Reset user password
ssh ubuntu@$(dig +short app.lvs.me.uk) 'docker exec postgresql psql -U postgres -c "ALTER USER ruby_demo_user PASSWORD '\''new_password'\'';"'
```

## Development Patterns

### Database Migrations

**Ruby (ActiveRecord):**

```ruby
# Add to your app's docker-compose.prod.yml
environment:
  - DATABASE_URL=postgresql://ruby_demo_user:${POSTGRES_RUBY_PASSWORD}@postgresql:5432/ruby_demo
  - RAILS_ENV=production

# Run migrations on deploy
command: ["bash", "-c", "bundle exec rails db:migrate && bundle exec rails server"]
```

**TypeScript (Prisma):**

```typescript
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// Deploy migrations
npx prisma migrate deploy
```

**Python (Alembic/SQLAlchemy):**

```python
# Run migrations
alembic upgrade head

# In your app
from sqlalchemy import create_engine
engine = create_engine(os.environ['DATABASE_URL'])
```

**Go (golang-migrate):**

```go
// Run migrations
migrate -path ./migrations -database $DATABASE_URL up

// In your app
import "database/sql"
import _ "github.com/lib/pq"

db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
```

### Connection Pooling

For high-traffic applications, consider connection pooling:

```yaml
# Add PgBouncer service if needed
pgbouncer:
  image: pgbouncer/pgbouncer:latest
  environment:
    - DATABASES_HOST=postgresql
    - DATABASES_PORT=5432
    - DATABASES_USER=postgres
    - DATABASES_PASSWORD=${POSTGRES_ADMIN_PASSWORD}
    - POOL_MODE=transaction
  networks:
    - monitoring
```

## Security Best Practices

1. **Unique passwords** for each application user
2. **Minimal privileges** - users can only access their own database
3. **Network isolation** - PostgreSQL only accessible via monitoring network
4. **Regular backups** with encryption for sensitive data
5. **Monitor connections** and unusual query patterns via Grafana dashboards
6. **Keep PostgreSQL updated** by updating the Docker image version

## Integration with Monitoring

PostgreSQL metrics are automatically collected by Grafana Alloy and stored in Mimir. View database performance in Grafana dashboards:

- Connection counts and active queries
- Database sizes and growth trends
- Query performance and slow query detection
- Lock monitoring and deadlock detection

Configure alerts for:

- Database connection limits
- Disk space usage
- Long-running queries
- Failed connections
