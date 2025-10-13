import { json } from '@tanstack/start'
import { fetchRequestHandler } from '@trpc/server/adapters/fetch'
import { appRouter } from '@/server/trpc'

async function handler(request: Request) {
  return fetchRequestHandler({
    endpoint: '/api/trpc',
    req: request,
    router: appRouter,
    createContext: () => ({}),
  })
}

export async function GET({ request }: { request: Request }) {
  return handler(request)
}

export async function POST({ request }: { request: Request }) {
  return handler(request)
}
