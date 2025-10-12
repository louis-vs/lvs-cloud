-- LVS Cloud PostgreSQL Permissions
-- Grants appropriate permissions to application users
-- Idempotent: Can be run multiple times safely (GRANT statements don't error if permission already exists)

-- Ruby Demo App Permissions
\c ruby_demo
GRANT CONNECT ON DATABASE ruby_demo TO ruby_demo_user;
GRANT ALL ON SCHEMA public TO ruby_demo_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ruby_demo_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ruby_demo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ruby_demo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ruby_demo_user;

-- TypeScript App Permissions
\c typescript_app
GRANT CONNECT ON DATABASE typescript_app TO typescript_user;
GRANT ALL ON SCHEMA public TO typescript_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO typescript_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO typescript_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO typescript_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO typescript_user;

-- Python FastAPI App Permissions
\c python_api
GRANT CONNECT ON DATABASE python_api TO python_user;
GRANT ALL ON SCHEMA public TO python_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO python_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO python_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO python_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO python_user;

-- Go Service App Permissions
\c go_service
GRANT CONNECT ON DATABASE go_service TO go_user;
GRANT ALL ON SCHEMA public TO go_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO go_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO go_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO go_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO go_user;
