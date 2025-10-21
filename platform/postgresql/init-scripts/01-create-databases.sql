-- LVS Cloud PostgreSQL Database Initialization
-- Creates databases for each application
-- Idempotent: Can be run multiple times safely

-- Ruby Demo App Database
SELECT 'CREATE DATABASE ruby_demo
    WITH
    OWNER = postgres
    ENCODING = ''UTF8''
    LC_COLLATE = ''en_US.utf8''
    LC_CTYPE = ''en_US.utf8''
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ruby_demo')\gexec

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_database WHERE datname = 'ruby_demo') THEN
        EXECUTE 'COMMENT ON DATABASE ruby_demo IS ''Database for Ruby demo application''';
    END IF;
END
$$;

-- Python FastAPI App Database
SELECT 'CREATE DATABASE python_api
    WITH
    OWNER = postgres
    ENCODING = ''UTF8''
    LC_COLLATE = ''en_US.utf8''
    LC_CTYPE = ''en_US.utf8''
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'python_api')\gexec

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_database WHERE datname = 'python_api') THEN
        EXECUTE 'COMMENT ON DATABASE python_api IS ''Database for Python FastAPI application''';
    END IF;
END
$$;

-- Go App Database
SELECT 'CREATE DATABASE go_service
    WITH
    OWNER = postgres
    ENCODING = ''UTF8''
    LC_COLLATE = ''en_US.utf8''
    LC_CTYPE = ''en_US.utf8''
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'go_service')\gexec

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_database WHERE datname = 'go_service') THEN
        EXECUTE 'COMMENT ON DATABASE go_service IS ''Database for Go service application''';
    END IF;
END
$$;
