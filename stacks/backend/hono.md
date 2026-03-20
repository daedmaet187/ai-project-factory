# Hono — Backend Stack Guide

## When to Use
- API needs to run on Cloudflare Workers, Bun, Deno, OR Node.js (runtime portability)
- Ultra-low latency needed (Hono is among the fastest Node.js frameworks)
- Building an Edge-first project (Combo 3)
- Team wants a minimal, explicit framework without Express magic

## When NOT to Use
- Large existing codebase on Express (migration cost not worth it)
- Needs Express-specific middleware ecosystem
- ECS Fargate on Node.js with complex middleware needs → use Fastify or Express

## Stack
- Runtime: Node.js 22+ / Bun 1.x / Cloudflare Workers
- Framework: Hono 4.x
- Validation: Zod + @hono/zod-validator
- Auth: hono/jwt or custom JWT middleware
- DB: pg (Node) or D1 (Cloudflare)

## Key Patterns

### App setup (Node.js)
```typescript
import { Hono } from 'hono'
import { serve } from '@hono/node-server'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

const app = new Hono()

app.use('*', cors({ origin: ['https://admin.yourdomain.com'] }))
app.use('*', logger())

app.get('/health', (c) => c.json({ status: 'ok' }))

const createHabitSchema = z.object({
  name: z.string().min(1).max(255),
  frequency: z.enum(['daily', 'weekly', 'monthly']),
})

app.post('/api/habits', zValidator('json', createHabitSchema), async (c) => {
  const body = c.req.valid('json')
  // body is fully typed
  return c.json({ id: '...', ...body }, 201)
})

serve({ fetch: app.fetch, port: 3000 })
```

### Error handling
```typescript
app.onError((err, c) => {
  console.error(err)
  return c.json(
    { error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message },
    500
  )
})
```

### Auth middleware
```typescript
import { jwt } from 'hono/jwt'

const authMiddleware = jwt({ secret: process.env.JWT_SECRET! })
app.use('/api/*', authMiddleware)
```

## Verification
```bash
node --check src/index.ts  # TypeScript check
# or: bun run src/index.ts → server starts without errors
```

## Changelog
- https://github.com/honojs/hono/releases
