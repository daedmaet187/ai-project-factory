# Backend Stack: Node.js + Express 5 + ESM + Zod

This is the default backend stack. Follow these patterns exactly.

---

## Project Structure

```
src/
├── index.js              ← Entry point — creates app, starts server
├── app.js                ← Express app setup — middleware stack, routes
├── config.js             ← Config loaded from env/Secrets Manager
├── db.js                 ← PostgreSQL pool instance
├── routes/
│   ├── index.js          ← Mounts all routers
│   ├── auth.js           ← /api/auth/* routes
│   ├── users.js          ← /api/users/* routes
│   └── [feature].js      ← /api/[feature]/* routes
├── middleware/
│   ├── auth.js           ← JWT validation, req.user attachment
│   ├── validate.js       ← Zod request validation factory
│   ├── rateLimiter.js    ← express-rate-limit configuration
│   └── errorHandler.js   ← Centralized error handler
└── schemas/
    ├── auth.js           ← Zod schemas for auth requests
    ├── users.js          ← Zod schemas for user requests
    └── [feature].js      ← Zod schemas per feature
```

---

## package.json Setup

```json
{
  "type": "module",
  "engines": { "node": ">=22" },
  "dependencies": {
    "express": "^5.0.0",
    "zod": "^3.23.0",
    "pg": "^8.13.0",
    "jsonwebtoken": "^9.0.0",
    "bcrypt": "^5.1.0",
    "helmet": "^8.0.0",
    "cors": "^2.8.5",
    "express-rate-limit": "^7.4.0",
    "@aws-sdk/client-secrets-manager": "^3.0.0",
    "pino": "^9.0.0",
    "pino-http": "^10.0.0",
    "@sentry/node": "^8.0.0",
    "@sentry/profiling-node": "^8.0.0"
  },
  "devDependencies": {
    "eslint": "^9.0.0",
    "vitest": "^2.0.0"
  },
  "scripts": {
    "start": "node src/index.js",
    "dev": "node --watch src/index.js",
    "lint": "eslint src/",
    "test": "vitest run"
  }
}
```

**Tier 2+ only** — add OTel packages when using Grafana Cloud or Datadog:
```json
"@opentelemetry/sdk-node": "^0.57.0",
"@opentelemetry/auto-instrumentations-node": "^0.57.0",
"@opentelemetry/exporter-trace-otlp-http": "^0.57.0",
"@opentelemetry/exporter-metrics-otlp-http": "^0.57.0"
```

---

## app.js — Middleware Order

Middleware order is critical. Follow this exactly.

```javascript
// src/app.js
import express from 'express'
import helmet from 'helmet'
import cors from 'cors'
import { pinoHttp } from 'pino-http'
import * as Sentry from '@sentry/node'
import { rateLimiter } from './middleware/rateLimiter.js'
import { errorHandler } from './middleware/errorHandler.js'
import { requestId } from './middleware/requestId.js'
import { logger } from './config/logger.js'
import { initSentry } from './config/sentry.js'
import routes from './routes/index.js'

// Init Sentry before app setup — must be first
initSentry()

const app = express()

// 0. Request ID — very first middleware, before everything
app.use(requestId)

// 1. Security headers
app.use(helmet())

// 2. CORS — before any route
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') ?? [],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-request-id']
}))

// 3. HTTP request logging — every request logged with method, url, status, duration
app.use(pinoHttp({
  logger,
  customSuccessMessage: (req, res) => `${req.method} ${req.url} ${res.statusCode}`,
  customErrorMessage: (req, res, err) => `${req.method} ${req.url} ${res.statusCode} - ${err.message}`,
  // Don't log health checks (too noisy)
  autoLogging: { ignore: (req) => req.url === '/health' },
  // Include request ID in every log line
  customProps: (req) => ({ requestId: req.id }),
}))

// 4. Rate limiting on all routes
app.use(rateLimiter)

// 5. Body parsing
app.use(express.json({ limit: '10kb' }))

// 6. Health check — before auth so it's always accessible
app.get('/health', (req, res) => {
  res.json({ status: 'ok', version: process.env.APP_VERSION, timestamp: new Date().toISOString() })
})

// 7. Routes
app.use('/api', routes)

// 8. Sentry error handler — MUST be before custom errorHandler
app.use(Sentry.expressErrorHandler())

// 9. Error handler — always last
app.use(errorHandler)

export default app
```

---

## Observability Config Files

Generate these files into every scaffold. They are baked in, not optional.

### `src/config/logger.js`

```javascript
// src/config/logger.js
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: {
    service: process.env.SERVICE_NAME || 'api',
    env: process.env.NODE_ENV || 'production',
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  // Redact sensitive fields from logs — never log passwords or tokens
  redact: {
    paths: ['*.password', '*.token', '*.secret', '*.authorization', 'req.headers.authorization'],
    censor: '[REDACTED]',
  },
})
```

Usage in controllers and services:
```javascript
// Good — structured context first, message last
logger.info({ requestId: req.id, userId: req.user.id }, 'user.created')
logger.error({ err, requestId: req.id, userId: req.user.id }, 'user.create.failed')

// Bad — never console.log in production
console.log('user created')
```

ECS task definition already has the CloudWatch log driver — JSON logs from pino go directly to CloudWatch Logs and are queryable via CloudWatch Logs Insights.

---

### `src/config/sentry.js`

```javascript
// src/config/sentry.js
import * as Sentry from '@sentry/node'

export function initSentry() {
  if (!process.env.SENTRY_DSN) {
    // Graceful no-op — don't break the app if Sentry isn't configured
    console.warn('SENTRY_DSN not set — error tracking disabled')
    return
  }
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'production',
    release: process.env.APP_VERSION,  // set via CI: git SHA or semver
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
    profilesSampleRate: 0.1,
    beforeSend(event) {
      // Strip PII from error events before sending to Sentry
      if (event.user) {
        delete event.user.email
        delete event.user.ip_address
      }
      return event
    },
  })
}
```

---

### `src/middleware/requestId.js` — Correlation IDs

Correlation IDs allow you to trace a single request across all log lines, even in high-concurrency environments.

```javascript
// src/middleware/requestId.js
import { randomUUID } from 'crypto'

export const requestId = (req, res, next) => {
  // Respect upstream request ID (load balancer, API gateway, mobile client)
  req.id = req.headers['x-request-id'] || randomUUID()
  // Echo it back so clients can correlate their logs with server logs
  res.setHeader('x-request-id', req.id)
  next()
}
```

Pass `req.id` through every logger call in controllers:
```javascript
logger.info({ requestId: req.id, userId }, 'habit.created')
logger.warn({ requestId: req.id, attemptedId }, 'habit.not_found')
```

This makes CloudWatch Logs Insights queries trivial:
```
fields @timestamp, requestId, message, userId
| filter requestId = "abc-123-..."
| sort @timestamp asc
```

---

## Express 5 — Async Error Propagation

In Express 5, thrown errors in async route handlers are automatically caught. No try/catch needed.

```javascript
// CORRECT — Express 5 catches this automatically
router.get('/users/:id', async (req, res) => {
  const user = await db.query('SELECT * FROM users WHERE id = $1', [req.params.id])
  if (!user.rows[0]) throw new NotFoundError('User not found')
  res.json(user.rows[0])
})

// WRONG — unnecessary try/catch in Express 5
router.get('/users/:id', async (req, res) => {
  try {
    const user = await db.query(...)
    res.json(user.rows[0])
  } catch (err) {
    next(err) // Don't need this
  }
})
```

**Exception**: If you need custom error handling for a specific error type, use try/catch for that specific case only.

---

## Route File Pattern

Every route file follows this exact pattern:

```javascript
// src/routes/users.js
import { Router } from 'express'
import { pool } from '../db.js'
import { auth } from '../middleware/auth.js'
import { validate } from '../middleware/validate.js'
import { updateUserSchema } from '../schemas/users.js'

const router = Router()

// GET /api/users — list users (admin only)
router.get('/', auth, auth.requireRole('admin'), async (req, res) => {
  const { rows } = await pool.query(
    'SELECT id, email, name, role, created_at FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2',
    [req.query.limit ?? 20, req.query.offset ?? 0]
  )
  res.json({ users: rows, total: rows.length })
})

// GET /api/users/:id — get user by ID
router.get('/:id', auth, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT id, email, name, role, created_at FROM users WHERE id = $1',
    [req.params.id]
  )
  if (!rows[0]) throw Object.assign(new Error('User not found'), { statusCode: 404 })
  res.json(rows[0])
})

// PATCH /api/users/:id — update user
router.patch('/:id', auth, validate(updateUserSchema), async (req, res) => {
  const { name } = req.body
  const { rows } = await pool.query(
    'UPDATE users SET name = $1, updated_at = NOW() WHERE id = $2 RETURNING id, email, name',
    [name, req.params.id]
  )
  if (!rows[0]) throw Object.assign(new Error('User not found'), { statusCode: 404 })
  res.json(rows[0])
})

export default router
```

---

## Zod Validation Middleware

```javascript
// src/middleware/validate.js
import { ZodError } from 'zod'

export const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body)
  if (!result.success) {
    return res.status(400).json({
      error: 'Validation failed',
      details: result.error.flatten().fieldErrors
    })
  }
  req.body = result.data  // Replace with parsed/coerced values
  next()
}

// For query params:
export const validateQuery = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.query)
  if (!result.success) {
    return res.status(400).json({
      error: 'Invalid query parameters',
      details: result.error.flatten().fieldErrors
    })
  }
  req.query = result.data
  next()
}
```

---

## Error Handler

```javascript
// src/middleware/errorHandler.js
import { logger } from '../config/logger.js'

export const errorHandler = (err, req, res, next) => {
  // Log the full error internally with structured context
  const statusCode = err.statusCode ?? err.status ?? 500
  const logLevel = statusCode >= 500 ? 'error' : 'warn'

  logger[logLevel]({
    err,
    requestId: req.id,
    path: req.path,
    method: req.method,
  }, err.message)

  // Respond with generic message (never expose internals to clients)
  const message = statusCode < 500 ? err.message : 'Internal server error'

  res.status(statusCode).json({ error: message })
}
```

---

## Database Pool

```javascript
// src/db.js
import pg from 'pg'

const { Pool } = pg

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
})

// Test connection at startup
pool.query('SELECT 1').catch(err => {
  console.error('Database connection failed:', err.message)
  process.exit(1)
})
```

---

## Common Express 5 Gotchas

### path-to-regexp v8 breaking changes
Express 5 uses path-to-regexp v8. Named capture groups and some patterns changed:

```javascript
// WRONG — Express 4 style, breaks in Express 5
router.get('/users/:id(\\d+)', handler)

// CORRECT — Express 5 regex in routes
router.get('/users/:id', async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) throw Object.assign(new Error('Invalid ID'), { statusCode: 400 })
  // ...
})
```

### Removed `req.param()`
Use `req.params.id` directly — `req.param('id')` is removed.

### `res.json()` vs `res.send()`
Use `res.json()` for all API responses. It sets Content-Type correctly.

---

## Anti-Patterns

```javascript
// ❌ NEVER — string interpolation in SQL
pool.query(`SELECT * FROM users WHERE email = '${email}'`)

// ✅ ALWAYS — parameterized
pool.query('SELECT * FROM users WHERE email = $1', [email])

// ❌ NEVER — hardcoded secrets
const JWT_SECRET = 'my-secret-key'

// ✅ ALWAYS — from environment (sourced from Secrets Manager at container start)
const JWT_SECRET = process.env.JWT_SECRET

// ❌ NEVER — wildcard CORS in production
app.use(cors({ origin: '*' }))

// ✅ ALWAYS — explicit allowlist
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') }))

// ❌ NEVER — missing auth on protected route
router.get('/admin/users', async (req, res) => { ... })

// ✅ ALWAYS — auth middleware on every non-public route
router.get('/admin/users', auth, auth.requireRole('admin'), async (req, res) => { ... })
```
