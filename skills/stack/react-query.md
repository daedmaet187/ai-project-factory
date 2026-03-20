# TanStack Query (React Query) — Data Fetching Patterns

Read this before writing any data fetching in the admin frontend.

---

## Setup

```typescript
// src/main.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,  // 5 minutes — don't refetch if data is fresh
      retry: 1,                   // Retry once on failure
      refetchOnWindowFocus: false // Don't refetch every time window regains focus
    }
  }
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <QueryClientProvider client={queryClient}>
    <App />
    <ReactQueryDevtools />
  </QueryClientProvider>
)
```

---

## Query Keys Convention

Query keys must be consistent. Use arrays with hierarchy:

```typescript
// Convention: [resource, ...params]
['users']                           // all users
['users', { role: 'admin' }]       // filtered users
['users', userId]                  // single user
['users', userId, 'habits']        // user's habits
['habits', { page: 1 }]           // paginated habits
```

Define query keys as constants to avoid typos:

```typescript
// src/lib/query-keys.ts
export const queryKeys = {
  users: {
    all: ['users'] as const,
    filtered: (params: object) => ['users', params] as const,
    detail: (id: string) => ['users', id] as const,
  },
  habits: {
    all: ['habits'] as const,
    paginated: (page: number) => ['habits', { page }] as const,
    detail: (id: string) => ['habits', id] as const,
  }
}
```

---

## Standard Query Hook Pattern

```typescript
// src/hooks/useUsers.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '@/lib/api'
import { queryKeys } from '@/lib/query-keys'
import type { User } from '@/types'

// Fetch list
export function useUsers(params?: { role?: string; search?: string }) {
  return useQuery({
    queryKey: queryKeys.users.filtered(params ?? {}),
    queryFn: async (): Promise<{ users: User[]; total: number }> => {
      const { data } = await api.get('/api/users', { params })
      return data
    }
  })
}

// Fetch single
export function useUser(id: string) {
  return useQuery({
    queryKey: queryKeys.users.detail(id),
    queryFn: async (): Promise<User> => {
      const { data } = await api.get(`/api/users/${id}`)
      return data
    },
    enabled: !!id  // Don't fetch if id is empty
  })
}

// Create mutation
export function useCreateUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (body: { email: string; name: string; role: string }) =>
      api.post('/api/users', body).then(r => r.data),
    onSuccess: () => {
      // Invalidate the users list so it refreshes
      queryClient.invalidateQueries({ queryKey: queryKeys.users.all })
    }
  })
}

// Update mutation
export function useUpdateUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, ...body }: { id: string; name?: string; role?: string }) =>
      api.patch(`/api/users/${id}`, body).then(r => r.data),
    onSuccess: (updatedUser: User) => {
      // Update specific user in cache (avoids refetch)
      queryClient.setQueryData(queryKeys.users.detail(updatedUser.id), updatedUser)
      // Invalidate list (may have changed)
      queryClient.invalidateQueries({ queryKey: queryKeys.users.all })
    }
  })
}

// Delete mutation
export function useDeleteUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => api.delete(`/api/users/${id}`),
    onSuccess: (_, id) => {
      // Remove from cache
      queryClient.removeQueries({ queryKey: queryKeys.users.detail(id) })
      queryClient.invalidateQueries({ queryKey: queryKeys.users.all })
    }
  })
}
```

---

## Usage in Components

```typescript
// src/pages/users/UsersPage.tsx
export function UsersPage() {
  const [search, setSearch] = useState('')
  const { data, isLoading, isError, error } = useUsers({ search: search || undefined })
  const deleteUser = useDeleteUser()

  if (isLoading) return <TableSkeleton />
  if (isError) return <ErrorAlert message={error.message} />

  return (
    <div>
      <Input
        placeholder="Search users..."
        value={search}
        onChange={e => setSearch(e.target.value)}
      />
      <DataTable
        columns={columns}
        data={data?.users ?? []}
        onDelete={(id) => deleteUser.mutate(id)}
      />
    </div>
  )
}
```

---

## Optimistic Updates

```typescript
export function useToggleHabit() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, completed }: { id: string; completed: boolean }) =>
      api.patch(`/api/habits/${id}`, { completed }),

    // Update UI immediately before server responds
    onMutate: async ({ id, completed }) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.habits.all })
      const previous = queryClient.getQueryData(queryKeys.habits.all)
      
      queryClient.setQueryData(queryKeys.habits.all, (old: Habit[]) =>
        old.map(h => h.id === id ? { ...h, completed } : h)
      )
      return { previous }  // Return for rollback
    },

    // On error, roll back to previous value
    onError: (err, _, context) => {
      queryClient.setQueryData(queryKeys.habits.all, context?.previous)
    },

    // Always refetch to confirm server state
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.habits.all })
    }
  })
}
```

---

## Pagination

```typescript
export function useHabitsPaginated(page: number) {
  return useQuery({
    queryKey: queryKeys.habits.paginated(page),
    queryFn: () => api.get('/api/habits', { params: { limit: 20, offset: (page - 1) * 20 } }).then(r => r.data),
    placeholderData: (prev) => prev  // Keep previous data while loading next page (no flash)
  })
}
```

---

## Anti-Patterns

```typescript
// ❌ WRONG — fetching in useEffect (manual fetch)
useEffect(() => {
  fetch('/api/users').then(r => r.json()).then(setUsers)
}, [])

// ✅ CORRECT — TanStack Query handles caching, loading, errors
const { data } = useUsers()

// ❌ WRONG — no queryKey dependency (stale data)
useQuery({ queryKey: ['users'], queryFn: () => fetchUsers(role) })
// role changes → query doesn't refetch

// ✅ CORRECT — include all dependencies in queryKey
useQuery({ queryKey: ['users', { role }], queryFn: () => fetchUsers(role) })

// ❌ WRONG — not handling loading state
const { data } = useUsers()
return <div>{data.users.map(...)}</div>  // Crashes if data is undefined

// ✅ CORRECT — handle all states
const { data, isLoading, isError } = useUsers()
if (isLoading) return <Skeleton />
if (isError) return <ErrorMessage />
return <div>{data.users.map(...)}</div>
```
