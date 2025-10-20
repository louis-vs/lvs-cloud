import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import { Button } from '@/components/ui/button'
import { Trash2 } from 'lucide-react'
import type { Task } from '@/integrations/trpc/router'

interface TaskListProps {
  tasks: Task[]
  onToggleComplete: (id: number, completed: boolean) => void
  onDelete: (id: number) => void
  onEdit: (task: Task) => void
}

export function TaskList({ tasks, onToggleComplete, onDelete, onEdit }: TaskListProps) {
  if (tasks.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-muted-foreground">No tasks yet. Create one to get started!</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {tasks.map((task) => (
        <Card key={task.id} className="hover:shadow-md transition-shadow">
          <CardHeader className="pb-3">
            <div className="flex items-start justify-between gap-4">
              <div className="flex items-start gap-3 flex-1">
                <Checkbox
                  checked={task.completed}
                  onCheckedChange={(checked) =>
                    onToggleComplete(task.id, checked as boolean)
                  }
                  className="mt-1"
                />
                <div className="flex-1">
                  <CardTitle
                    className={`text-lg cursor-pointer hover:text-primary transition-colors ${
                      task.completed ? 'line-through text-muted-foreground' : ''
                    }`}
                    onClick={() => onEdit(task)}
                  >
                    {task.title}
                  </CardTitle>
                  {task.description && (
                    <CardDescription className="mt-1">
                      {task.description}
                    </CardDescription>
                  )}
                </div>
              </div>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => onDelete(task.id)}
                className="text-destructive hover:text-destructive hover:bg-destructive/10"
              >
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
        </Card>
      ))}
    </div>
  )
}
