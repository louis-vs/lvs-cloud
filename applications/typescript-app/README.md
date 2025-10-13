# TypeScript Task Manager

A modern, full-stack TypeScript application built with:

- **TanStack Start** - React SSR framework
- **tRPC** - End-to-end type-safe API
- **Bun** - Fast JavaScript runtime
- **shadcn/ui** - Beautiful component library
- **Tailwind CSS v4** - Styling
- **PostgreSQL** - Database
- **React 19** - Latest React

## Features

- ✅ Server-side rendering with TanStack Start
- ✅ Type-safe API with tRPC
- ✅ Beautiful UI with shadcn/ui components
- ✅ Task CRUD operations
- ✅ Real-time task filtering
- ✅ PostgreSQL persistence
- ✅ Prometheus metrics endpoint
- ✅ Health check endpoint
- ✅ Docker deployment ready

## Local Development

### Prerequisites

- Bun >= 1.0
- PostgreSQL database

### Setup

1. Install dependencies:

   ```bash
   bun install
   ```

1. Create `.env` file:

   ```bash
   DATABASE_URL=postgresql://user:password@localhost:5432/typescript_app
   NODE_ENV=development
   PORT=3000
   ```

1. Run migrations:

   ```bash
   bun run migrate
   ```

1. Start development server:

   ```bash
   bun run dev
   ```

1. Open <http://localhost:3000>

## Production Deployment

The application is automatically deployed via GitOps when changes are pushed to the repository.

### Deployment Flow

1. Push code to `applications/typescript-app/**`
2. GitHub Actions detects changes
3. Builds Docker image with Bun
4. Pushes to private registry
5. Deploys to production server
6. Runs migrations automatically
7. Application available at <https://typescript-app.lvs.me.uk>

### Manual Deployment

On the production server:

```bash
cd /tmp/deploy-typescript-app
./deploy.sh
```

## API Endpoints

- `/` - Main application (SSR)
- `/api/trpc` - tRPC API endpoint
- `/api/health` - Health check
- `/api/metrics` - Prometheus metrics

## Database

The application uses the shared PostgreSQL server with:

- **Database**: `typescript_app`
- **User**: `typescript_user`
- **Password**: Stored in `POSTGRES_TS_PASSWORD` secret

Migrations run automatically on startup for GitOps compatibility.

## Monitoring

- Metrics exposed at `/api/metrics`
- Automatically collected by Grafana Alloy
- Container logs sent to Loki
- Accessible via Grafana dashboards

## Technology Stack

- **Runtime**: Bun 1.x
- **Framework**: TanStack Start (React 19)
- **API**: tRPC v11
- **Database**: PostgreSQL (via pg)
- **Styling**: Tailwind CSS v4
- **Components**: shadcn/ui + Radix UI
- **Deployment**: Docker + Traefik + Watchtower
