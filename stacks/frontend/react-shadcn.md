# Frontend Stack: React 19 + Vite + TanStack Router + TailwindCSS 4 + shadcn/ui

Default admin frontend stack. Use for internal tools, admin panels, and dashboards.

## Stack Summary

| Layer | Technology |
|---|---|
| Framework | React 19 |
| Build tool | Vite 6 |
| Router | **TanStack Router** (default) |
| Data fetching | TanStack Query |
| Styling | TailwindCSS 4 |
| Components | shadcn/ui |

**Why TanStack Router (not React Router 7):** For SPA admin dashboards, TanStack Router provides end-to-end type safety including URL search params — React Router 7's type safety only works in framework mode (i.e., when used as a full-stack framework, not as a plain SPA router). TanStack Router is purpose-built for client-heavy applications.

**Alternative — React Router 7:** Use if the team is migrating from an existing React Router app or already has deep familiarity with the RR API.

## Deployment

- **AWS stack**: deploy to S3 + CloudFront (see Hosting Coherence Rule in `stacks/STACKS.md`)
- **Edge/Cloudflare stack**: deploy to Cloudflare Pages

---

---

## Project Structure

```
admin/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── package.json
├── src/
│   ├── main.tsx              ← React root, router setup
│   ├── App.tsx               ← Root component, routes
│   ├── index.css             ← TailwindCSS 4 config + CSS variables
│   ├── lib/
│   │   ├── api.ts            ← Axios/fetch wrapper with auth headers
│   │   ├── auth.ts           ← Auth utilities (token storage, helpers)
│   │   └── utils.ts          ← shadcn's cn() utility + other helpers
│   ├── components/
│   │   ├── ui/               ← shadcn/ui generated components (never edit)
│   │   ├── layout/           ← Sidebar, header, nav components
│   │   └── [feature]/        ← Feature-specific components
│   ├── pages/
│   │   ├── auth/             ← Login, forgot password
│   │   ├── dashboard/        ← Main dashboard
│   │   └── [feature]/        ← Feature pages
│   ├── hooks/                ← Custom React hooks (useUsers, useProducts, etc.)
│   └── types/                ← TypeScript type definitions
```

---

## vite.config.ts

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') }
  }
})
```

---

## index.css — TailwindCSS 4 Configuration

```css
@import "tailwindcss";

@theme {
  /* Brand colors — set from design tokens */
  --color-primary: oklch(55% 0.2 264);
  --color-primary-foreground: oklch(98% 0 0);
  --color-secondary: oklch(60% 0.15 280);
  --color-accent: oklch(75% 0.18 70);
  
  /* Neutral palette */
  --color-background: oklch(100% 0 0);
  --color-foreground: oklch(10% 0 0);
  --color-muted: oklch(96% 0 0);
  --color-muted-foreground: oklch(45% 0 0);
  --color-border: oklch(90% 0 0);
  
  /* Semantic */
  --color-destructive: oklch(55% 0.22 27);
  --color-success: oklch(60% 0.17 145);
  
  /* Radius */
  --radius: 0.5rem;
  
  /* Font */
  --font-sans: 'Inter', ui-sans-serif, system-ui;
}

@custom-variant dark (&:is(.dark *));
```

---

## API Client Pattern

```typescript
// src/lib/api.ts
import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  timeout: 10000,
})

// Attach auth token to every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Handle 401 — redirect to login
api.interceptors.response.use(
  (res) => res,
  async (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('access_token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default api
```

---

## Data Fetching Pattern — TanStack Query

```typescript
// src/hooks/useUsers.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '@/lib/api'

export function useUsers(params = {}) {
  return useQuery({
    queryKey: ['users', params],
    queryFn: async () => {
      const { data } = await api.get('/api/users', { params })
      return data
    }
  })
}

export function useUpdateUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, ...body }: { id: string; name: string }) =>
      api.patch(`/api/users/${id}`, body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
    }
  })
}
```

---

## Page Pattern — Loading / Error / Data States

```typescript
// src/pages/users/UsersPage.tsx
import { useUsers } from '@/hooks/useUsers'
import { columns } from './columns'
import { DataTable } from '@/components/ui/data-table'
import { Skeleton } from '@/components/ui/skeleton'
import { Alert, AlertDescription } from '@/components/ui/alert'

export function UsersPage() {
  const { data, isLoading, isError, error } = useUsers()

  if (isLoading) return <Skeleton className="h-64 w-full" />
  
  if (isError) return (
    <Alert variant="destructive">
      <AlertDescription>{error.message}</AlertDescription>
    </Alert>
  )

  return <DataTable columns={columns} data={data.users} />
}
```

---

## Form Pattern — react-hook-form + Zod

```typescript
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form'

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
})

type FormData = z.infer<typeof schema>

export function LoginForm({ onSubmit }: { onSubmit: (data: FormData) => void }) {
  const form = useForm<FormData>({ resolver: zodResolver(schema) })

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField control={form.control} name="email" render={({ field }) => (
          <FormItem>
            <FormLabel>Email</FormLabel>
            <FormControl><Input type="email" {...field} /></FormControl>
            <FormMessage />
          </FormItem>
        )} />
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Signing in...' : 'Sign in'}
        </Button>
      </form>
    </Form>
  )
}
```

---

## Router Setup — TanStack Router

```typescript
// src/main.tsx
import { StrictMode } from 'react'
import ReactDOM from 'react-dom/client'
import { RouterProvider, createRouter } from '@tanstack/react-router'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { routeTree } from './routeTree.gen'

const queryClient = new QueryClient()

const router = createRouter({
  routeTree,
  context: { queryClient },
})

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>
)
```

```typescript
// src/routes/__root.tsx
import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'
import type { QueryClient } from '@tanstack/react-query'

interface RouterContext {
  queryClient: QueryClient
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: () => <Outlet />,
})
```

```typescript
// src/routes/dashboard/index.tsx — type-safe route with search params
import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'

const dashboardSearchSchema = z.object({
  page: z.number().catch(1),
  filter: z.string().optional(),
})

export const Route = createFileRoute('/dashboard/')({
  validateSearch: dashboardSearchSchema,
  component: DashboardPage,
})

function DashboardPage() {
  // search params are fully typed — no casting needed
  const { page, filter } = Route.useSearch()
  return <div>Page {page}, filter: {filter}</div>
}
```

---

## Key Rules

1. **Never modify `src/components/ui/` files** — they're generated by shadcn CLI; regenerate them instead
2. **Always use `@/` imports** — not relative paths `../../`
3. **Loading and error states are required** — every data-fetching page must handle both
4. **VITE_API_URL** — never hardcode API URLs; always use this env variable
5. **Auth tokens in localStorage** — fine for admin panels (not mobile); clear on 401
6. **TanStack Router file-based routing** — run `tsr generate` or enable `@tanstack/router-plugin` in vite config to auto-generate `routeTree.gen.ts`
