import { initTRPC } from '@trpc/server'
import { z } from 'zod'
import { query } from './db'

// Initialize tRPC
const t = initTRPC.create()

// Export reusable router and procedure helpers
export const router = t.router
export const publicProcedure = t.procedure

// Define input schemas
const createTaskSchema = z.object({
  title: z.string().min(1).max(255),
  description: z.string().optional(),
})

const updateTaskSchema = z.object({
  id: z.number(),
  title: z.string().min(1).max(255).optional(),
  description: z.string().optional(),
  completed: z.boolean().optional(),
})

// Task type
export type Task = {
  id: number
  title: string
  description: string | null
  completed: boolean
  created_at: Date
  updated_at: Date
}

// Create the tRPC router
export const appRouter = router({
  // Get all tasks
  getTasks: publicProcedure.query(async () => {
    const tasks = await query<Task>(
      'SELECT * FROM tasks ORDER BY created_at DESC'
    )
    return tasks
  }),

  // Get single task
  getTask: publicProcedure
    .input(z.object({ id: z.number() }))
    .query(async ({ input }) => {
      const tasks = await query<Task>(
        'SELECT * FROM tasks WHERE id = $1',
        [input.id]
      )
      if (tasks.length === 0) {
        throw new Error('Task not found')
      }
      return tasks[0]
    }),

  // Create task
  createTask: publicProcedure
    .input(createTaskSchema)
    .mutation(async ({ input }) => {
      const tasks = await query<Task>(
        'INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING *',
        [input.title, input.description || null]
      )
      return tasks[0]
    }),

  // Update task
  updateTask: publicProcedure
    .input(updateTaskSchema)
    .mutation(async ({ input }) => {
      const { id, ...updates } = input
      const setClauses: string[] = []
      const values: any[] = []
      let paramIndex = 1

      if (updates.title !== undefined) {
        setClauses.push(`title = $${paramIndex++}`)
        values.push(updates.title)
      }
      if (updates.description !== undefined) {
        setClauses.push(`description = $${paramIndex++}`)
        values.push(updates.description)
      }
      if (updates.completed !== undefined) {
        setClauses.push(`completed = $${paramIndex++}`)
        values.push(updates.completed)
      }

      if (setClauses.length === 0) {
        throw new Error('No fields to update')
      }

      values.push(id)
      const tasks = await query<Task>(
        `UPDATE tasks SET ${setClauses.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
        values
      )

      if (tasks.length === 0) {
        throw new Error('Task not found')
      }
      return tasks[0]
    }),

  // Delete task
  deleteTask: publicProcedure
    .input(z.object({ id: z.number() }))
    .mutation(async ({ input }) => {
      const tasks = await query<Task>(
        'DELETE FROM tasks WHERE id = $1 RETURNING *',
        [input.id]
      )
      if (tasks.length === 0) {
        throw new Error('Task not found')
      }
      return tasks[0]
    }),
})

// Export type definition of API
export type AppRouter = typeof appRouter
