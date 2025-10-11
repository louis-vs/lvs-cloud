-- LVS Cloud PostgreSQL User Creation
-- Creates application-specific users with limited privileges

-- Ruby Demo App User
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

-- TypeScript App User
CREATE USER typescript_user WITH
    PASSWORD '${POSTGRES_TS_PASSWORD}'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT
    LOGIN
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT -1;

COMMENT ON ROLE typescript_user IS 'Application user for TypeScript tRPC app';

-- Python FastAPI App User
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

-- Go Service App User
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
