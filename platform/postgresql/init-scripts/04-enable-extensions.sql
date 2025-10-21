-- LVS Cloud PostgreSQL Extensions
-- Enable commonly used PostgreSQL extensions for each database

-- Connect to ruby_demo database
\c ruby_demo

-- Enable UUID extension for Ruby app
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Connect to python_api database
\c python_api

-- Enable UUID extension for Python app
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Connect to go_service database
\c go_service

-- Enable UUID extension for Go app
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Return to postgres database
\c postgres
