# Redis

In-memory database for session storage.

## Service

- **Redis**: Standalone in-memory data store
- **Namespace**: platform
- **Chart**: Bitnami Redis

## Secrets

None (authentication disabled)

## Configuration

- Standalone mode (no replication)
- No persistence (sessions are ephemeral)
- Used by Authelia for session storage
- Suitable for single-node deployment
