import { collectDefaultMetrics, Registry, Counter, Gauge } from 'prom-client'

// Create a Registry
const register = new Registry()

// Enable default metrics collection
collectDefaultMetrics({ register })

// Create custom metrics
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
})

const tasksTotal = new Gauge({
  name: 'tasks_total',
  help: 'Total number of tasks',
  registers: [register],
})

const tasksCompleted = new Gauge({
  name: 'tasks_completed',
  help: 'Number of completed tasks',
  registers: [register],
})

export async function GET() {
  try {
    // Update task metrics (would be better to do this on task changes)
    // For now, just expose the metrics endpoint
    const metrics = await register.metrics()

    return new Response(metrics, {
      headers: {
        'Content-Type': register.contentType,
      },
    })
  } catch (error) {
    return new Response('Error generating metrics', { status: 500 })
  }
}
