import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { createTRPCClient, httpBatchLink } from '@trpc/client'
import { TaskList } from '@/components/TaskList'
import { TaskForm } from '@/components/TaskForm'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Plus, Search } from 'lucide-react'
import type { AppRouter, Task } from '@/server/trpc'

export const Route = createFileRoute('/')({
  component: Home,
  loader: async () => {
    // Create a server-side tRPC client
    const trpc = createTRPCClient<AppRouter>({
      links: [
        httpBatchLink({
          url: `http://localhost:${process.env.PORT || 3000}/api/trpc`,
        }),
      ],
    })

    const tasks = await trpc.getTasks.query()
    return { tasks }
  },
})

function Home() {
  const { tasks: initialTasks } = Route.useLoaderData()
  const [tasks, setTasks] = useState<Task[]>(initialTasks)
  const [searchQuery, setSearchQuery] = useState('')
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [editingTask, setEditingTask] = useState<Task | null>(null)

  // Create browser-side tRPC client
  const trpc = createTRPCClient<AppRouter>({
    links: [
      httpBatchLink({
        url: '/api/trpc',
      }),
    ],
  })

  const filteredTasks = tasks.filter(
    (task) =>
      task.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (task.description?.toLowerCase() || '').includes(searchQuery.toLowerCase())
  )

  const handleCreateTask = async (data: { title: string; description?: string }) => {
    const newTask = await trpc.createTask.mutate(data)
    setTasks([newTask, ...tasks])
  }

  const handleUpdateTask = async (data: { title: string; description?: string }) => {
    if (!editingTask) return

    const updatedTask = await trpc.updateTask.mutate({
      id: editingTask.id,
      title: data.title,
      description: data.description,
    })

    setTasks(tasks.map((t) => (t.id === updatedTask.id ? updatedTask : t)))
    setEditingTask(null)
  }

  const handleToggleComplete = async (id: number, completed: boolean) => {
    const updatedTask = await trpc.updateTask.mutate({ id, completed })
    setTasks(tasks.map((t) => (t.id === updatedTask.id ? updatedTask : t)))
  }

  const handleDelete = async (id: number) => {
    await trpc.deleteTask.mutate({ id })
    setTasks(tasks.filter((t) => t.id !== id))
  }

  const handleEdit = (task: Task) => {
    setEditingTask(task)
    setIsFormOpen(true)
  }

  const handleFormOpenChange = (open: boolean) => {
    setIsFormOpen(open)
    if (!open) {
      setEditingTask(null)
    }
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="container mx-auto py-8 px-4 max-w-4xl">
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">Task Manager</h1>
          <p className="text-muted-foreground">
            Manage your tasks with this beautiful TypeScript + tRPC app
          </p>
        </div>

        <div className="mb-6 flex gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground h-4 w-4" />
            <Input
              placeholder="Search tasks..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
          </div>
          <Button onClick={() => setIsFormOpen(true)}>
            <Plus className="h-4 w-4 mr-2" />
            New Task
          </Button>
        </div>

        <TaskList
          tasks={filteredTasks}
          onToggleComplete={handleToggleComplete}
          onDelete={handleDelete}
          onEdit={handleEdit}
        />

        <TaskForm
          open={isFormOpen}
          onOpenChange={handleFormOpenChange}
          onSubmit={editingTask ? handleUpdateTask : handleCreateTask}
          editingTask={editingTask}
        />
      </div>
    </div>
  )
}
