#!/bin/bash
set -e

echo "Running tests for vsmp-royalties..."

# Run tests in container with PostgreSQL connection
# DATABASE_URL automatically overrides database.yml settings
docker run --rm \
  --network host \
  -e RAILS_ENV=test \
  -e DATABASE_URL="postgresql://test_user:test_password@localhost:5432/test_db" \
  vsmp-royalties:test \
  bash -c "bin/rails db:create db:schema:load && bin/rails test"

echo "✅ All tests passed!"
