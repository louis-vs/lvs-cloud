-- LVS Cloud PostgreSQL User Creation
-- Creates application-specific users with limited privileges
-- Idempotent: Can be run multiple times safely

-- Ruby Demo App User
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ruby_demo_user') THEN
        CREATE USER ruby_demo_user WITH
            PASSWORD '${POSTGRES_RUBY_PASSWORD}'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOINHERIT
            LOGIN
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT -1;
        COMMENT ON ROLE ruby_demo_user IS 'Application user for Ruby demo app';
    ELSE
        -- Update password if user already exists
        ALTER USER ruby_demo_user WITH PASSWORD '${POSTGRES_RUBY_PASSWORD}';
    END IF;
END
$$;

-- Python FastAPI App User
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'python_user') THEN
        CREATE USER python_user WITH
            PASSWORD '${POSTGRES_PYTHON_PASSWORD}'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOINHERIT
            LOGIN
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT -1;
        COMMENT ON ROLE python_user IS 'Application user for Python FastAPI app';
    ELSE
        ALTER USER python_user WITH PASSWORD '${POSTGRES_PYTHON_PASSWORD}';
    END IF;
END
$$;

-- Go Service App User
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'go_user') THEN
        CREATE USER go_user WITH
            PASSWORD '${POSTGRES_GO_PASSWORD}'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOINHERIT
            LOGIN
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT -1;
        COMMENT ON ROLE go_user IS 'Application user for Go service app';
    ELSE
        ALTER USER go_user WITH PASSWORD '${POSTGRES_GO_PASSWORD}';
    END IF;
END
$$;
