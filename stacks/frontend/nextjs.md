# Frontend Stack: Next.js 15 App Router

Use when: SEO matters, marketing + app in same codebase, or full-stack React is preferred.

---

## When to Choose Next.js vs React+Vite

| Scenario | Next.js | React+Vite |
|---|---|---|
| SEO required (marketing pages) | ✅ SSR/SSG | ❌ SPA only |
| Admin panel (no SEO) | ❌ Overkill | ✅ Simpler |
| API routes in same repo | ✅ API Routes | ❌ (separate service) |
| Static export possible | ✅ | ✅ |
| Faster cold start in Vercel/CF | ✅ | ✅ |

---

## Project Structure

```
app/
├── layout.tsx              ← Root layout (fonts, providers)
├── page.tsx                ← Landing page (/)
├── (auth)/
│   ├── login/page.tsx
│   └── register/page.tsx
├── (dashboard)/
│   ├── layout.tsx          ← Dashboard layout (sidebar, header)
│   ├── dashboard/page.tsx
│   └── users/
│       ├── page.tsx        ← Users list
│       └── [id]/page.tsx   ← User detail
├── api/                    ← API routes (if not using separate backend)
│   └── auth/
│       └── route.ts
components/
├── ui/                     ← shadcn/ui generated
└── [feature]/              ← Feature components
lib/
├── api.ts
└── auth.ts
```

---

## App Router Data Fetching

```typescript
// Server Component (default) — fetch on server, no client JS
export default async function UsersPage() {
  const users = await fetch(`${process.env.API_URL}/api/users`, {
    headers: { Authorization: `Bearer ${await getServerToken()}` },
    next: { revalidate: 60 }  // Cache for 60s
  }).then(r => r.json())

  return <UserTable users={users} />
}

// Client Component — for interactivity
'use client'
import { useQuery } from '@tanstack/react-query'

export function UserTable({ initialUsers }) {
  const { data } = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
    initialData: initialUsers  // hydrate from server
  })
  return <DataTable data={data} />
}
```

---

## next.config.ts

```typescript
import type { NextConfig } from 'next'

const config: NextConfig = {
  output: 'standalone',  // For Docker deployment
  images: {
    domains: ['your-cdn.cloudflare.com']
  },
  async headers() {
    return [{
      source: '/(.*)',
      headers: [
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-Content-Type-Options', value: 'nosniff' }
      ]
    }]
  }
}

export default config
```

---

## Deployment to Cloudflare Pages

```bash
# Install adapter
npm install @cloudflare/next-on-pages

# Build
npx @cloudflare/next-on-pages

# Wrangler config (wrangler.toml)
name = "admin-panel"
compatibility_date = "2024-01-01"
pages_build_output_dir = ".vercel/output/static"
```

**Note**: Cloudflare Pages has edge runtime limitations. Use `export const runtime = 'edge'` on pages that need Cloudflare's edge network. Not all Node.js APIs are available at edge.
