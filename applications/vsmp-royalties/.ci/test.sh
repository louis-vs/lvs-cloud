#!/bin/bash
set -e

echo "Running tests for vsmp-royalties..."

# Run tests in container
docker run --rm \
  -e RAILS_ENV=test \
  -e DATABASE_URL=sqlite3::memory: \
  vsmp-royalties:test \
  bin/rails test

echo "✅ All tests passed!"
