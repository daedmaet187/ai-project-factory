# Infrastructure Stack: Cloudflare Workers

Use for: edge-first APIs, ultra-low latency globally, or when avoiding AWS entirely.

---

## When to Choose Cloudflare Workers vs ECS

| Scenario | CF Workers | ECS Fargate |
|---|---|---|
| Global low latency (<50ms) | ✅ Edge, 300+ PoPs | ❌ Single region |
| Zero ops overhead | ✅ | ❌ |
| Cost (low traffic) | ✅ Free tier generous | ❌ |
| Node.js ecosystem (full) | ❌ V8 isolates only | ✅ |
| WebSockets | ✅ Durable Objects | ✅ |
| Long-running jobs | ❌ 50ms CPU limit | ✅ |
| Large npm packages | ❌ 1MB bundle limit | ✅ |
| VPC / private networking | ❌ | ✅ |

---

## Worker Setup

```typescript
// src/index.ts — Cloudflare Worker entry point
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { bearerAuth } from 'hono/bearer-auth'
import { rateLimiter } from 'hono-rate-limiter'

export interface Env {
  DB: D1Database
  JWT_SECRET: string  // Workers Secret
  ALLOWED_ORIGINS: string
}

const app = new Hono<{ Bindings: Env }>()

app.use('*', cors({
  origin: (origin, c) => c.env.ALLOWED_ORIGINS.split(',').includes(origin) ? origin : null,
  credentials: true
}))

app.get('/health', (c) => c.json({ status: 'ok' }))

app.route('/api/auth', authRouter)
app.route('/api/users', usersRouter)

export default app
```

---

## wrangler.toml

```toml
name = "my-project-api"
main = "src/index.ts"
compatibility_date = "2024-01-01"
compatibility_flags = ["nodejs_compat"]

[[d1_databases]]
binding = "DB"
database_name = "my-project"
database_id = "your-d1-database-id"

[vars]
ENVIRONMENT = "production"
ALLOWED_ORIGINS = "https://admin.example.com"

# Secrets set via: wrangler secret put JWT_SECRET
```

---

## D1 Database (SQLite-compatible)

```typescript
// D1 uses SQLite syntax
const stmt = c.env.DB.prepare(
  'SELECT * FROM users WHERE email = ?'
).bind(email)

const user = await stmt.first()

// Batch operations
const results = await c.env.DB.batch([
  c.env.DB.prepare('INSERT INTO habits (id, user_id, name) VALUES (?, ?, ?)').bind(id, userId, name),
  c.env.DB.prepare('UPDATE users SET habit_count = habit_count + 1 WHERE id = ?').bind(userId),
])
```

**D1 vs PostgreSQL syntax**:
- Params: `?` not `$1`
- No `gen_random_uuid()` — use `crypto.randomUUID()` in worker
- No `RETURNING` clause
- SQLite type affinity (not strict typing)

---

## Secrets Management

```bash
# Set secrets via Wrangler CLI (not in wrangler.toml)
wrangler secret put JWT_SECRET
wrangler secret put DATABASE_URL  # If using external DB

# List secrets
wrangler secret list
```

---

## Deployment

```bash
# Deploy worker
wrangler deploy

# Deploy with GitHub Actions
- name: Deploy Worker
  run: npx wrangler deploy
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CF_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CF_ACCOUNT_ID }}
```

---

## Key Constraints

1. **50ms CPU time limit** per request (not wall time — actual CPU execution)
2. **1MB bundle limit** — can't use large Node.js packages
3. **No file system** — all storage via D1/KV/R2
4. **No TCP** — only HTTP/WebSocket connections to external services
5. **V8 isolates** — not full Node.js; some APIs unavailable (use `nodejs_compat` flag for most)
