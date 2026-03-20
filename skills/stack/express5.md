# Express 5 — Deep Technical Guide

Read this before writing any Express backend code.

---

## What Changed in Express 5

Express 5 is a major version with breaking changes from Express 4.

### 1. Native Async Error Propagation *(most important change)*

In Express 4, unhandled promise rejections in route handlers crashed the process silently or required manual `try/catch + next(err)`.

In Express 5, thrown errors in `async` handlers are **automatically forwarded to error handling middleware**.

```javascript
// Express 4 — required this pattern
router.get('/users', async (req, res, next) => {
  try {
    const users = await db.query('SELECT * FROM users')
    res.json(users.rows)
  } catch (err) {
    next(err)  // Had to do this manually
  }
})

// Express 5 — throw directly, error middleware catches it
router.get('/users', async (req, res) => {
  const users = await db.query('SELECT * FROM users')  // If this throws, error handler catches it
  res.json(users.rows)
})
```

**When to still use try/catch**: when you want to handle a specific error locally and return a different response, not when you want generic error handling.

### 2. path-to-regexp v8 Breaking Changes

Express 5 upgraded to path-to-regexp v8. Several route patterns that worked in Express 4 now throw errors.

```javascript
// ❌ BROKEN in Express 5 — inline regex
router.get('/files/:name(\\w+)', handler)  // throws TypeError

// ✅ CORRECT — validate in handler
router.get('/files/:name', (req, res) => {
  if (!/^\w+$/.test(req.params.name)) {
    return res.status(400).json({ error: 'Invalid filename' })
  }
  // ...
})

// ❌ BROKEN — Optional params with (?)
router.get('/users/:id?', handler)

// ✅ CORRECT — explicit routes
router.get('/users', listHandler)
router.get('/users/:id', getHandler)
```

### 3. Removed APIs

- `req.param()` → use `req.params.name` directly
- `app.del()` → use `app.delete()`
- `res.json(obj, status)` → use `res.status(status).json(obj)`
- `res.send(body, headers, status)` → set separately

---

## Middleware Order

Order is critical. Wrong order = security bypass or broken functionality.

```javascript
import express from 'express'
import helmet from 'helmet'
import cors from 'cors'
import rateLimit from 'express-rate-limit'

const app = express()

// 1. Security headers — FIRST, always
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"]
    }
  }
}))

// 2. CORS — must be before routes
app.use(cors({
  origin: (origin, callback) => {
    const allowed = process.env.ALLOWED_ORIGINS?.split(',') ?? []
    if (!origin || allowed.includes(origin)) callback(null, true)
    else callback(new Error('Not allowed by CORS'))
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}))

// 3. Rate limiting — before body parsing (cheaper to rate-limit before parsing)
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests' }
}))

// 4. Body parsing
app.use(express.json({ limit: '10kb' }))
app.use(express.urlencoded({ extended: false, limit: '10kb' }))

// 5. Health check — before auth middleware so monitoring always works
app.get('/health', (req, res) => res.json({ status: 'ok' }))

// 6. Routes
app.use('/api', routes)

// 7. 404 handler — after routes, before error handler
app.use((req, res) => res.status(404).json({ error: 'Not found' }))

// 8. Error handler — MUST be last, MUST have 4 parameters
app.use((err, req, res, next) => {
  console.error(err)
  res.status(err.statusCode ?? 500).json({
    error: err.statusCode < 500 ? err.message : 'Internal server error'
  })
})
```

---

## Router Pattern — One File Per Resource

```javascript
// src/routes/products.js
import { Router } from 'express'
import { pool } from '../db.js'
import { auth } from '../middleware/auth.js'
import { validate } from '../middleware/validate.js'
import { createProductSchema, updateProductSchema } from '../schemas/products.js'

const router = Router()

// All routes follow: METHOD path, [...middleware], handler
// Handler is always async
// No try/catch needed — Express 5 propagates

router.get('/', auth, async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit ?? '20'), 100)
  const offset = parseInt(req.query.offset ?? '0')
  
  const { rows } = await pool.query(
    'SELECT id, name, price, created_at FROM products ORDER BY created_at DESC LIMIT $1 OFFSET $2',
    [limit, offset]
  )
  const { rows: [{ count }] } = await pool.query('SELECT COUNT(*) FROM products')
  
  res.json({ products: rows, total: parseInt(count), limit, offset })
})

router.get('/:id', auth, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM products WHERE id = $1',
    [req.params.id]
  )
  if (!rows[0]) throw Object.assign(new Error('Product not found'), { statusCode: 404 })
  res.json(rows[0])
})

router.post('/', auth, auth.requireRole('admin'), validate(createProductSchema), async (req, res) => {
  const { name, price, description } = req.body
  const { rows } = await pool.query(
    'INSERT INTO products (id, name, price, description) VALUES (gen_random_uuid(), $1, $2, $3) RETURNING *',
    [name, price, description]
  )
  res.status(201).json(rows[0])
})

export default router
```

---

## Auth Middleware Pattern

```javascript
// src/middleware/auth.js
import jwt from 'jsonwebtoken'

export const auth = (req, res, next) => {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' })
  }
  
  const token = authHeader.slice(7)
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET)
    next()
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' })
  }
}

// Role-based access control
auth.requireRole = (...roles) => (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' })
  if (!roles.includes(req.user.role)) return res.status(403).json({ error: 'Forbidden' })
  next()
}
```

---

## Stricter Rate Limiting for Auth Routes

```javascript
// src/middleware/rateLimiter.js
import rateLimit from 'express-rate-limit'

// Strict limit for auth endpoints (prevent brute force)
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 10,                    // 10 attempts per window
  skipSuccessfulRequests: true,  // Only count failed attempts
  message: { error: 'Too many login attempts. Please try again later.' }
})

// Default limit for all other routes
export const defaultRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
})
```

---

## ESM Import Patterns

Express 5 works well with ESM. Always use `.js` extensions in imports.

```javascript
// ✅ CORRECT — explicit .js extension required in ESM
import { Router } from 'express'
import { pool } from '../db.js'
import { auth } from '../middleware/auth.js'

// ❌ WRONG — missing .js extension breaks ESM
import { pool } from '../db'
import { auth } from '../middleware/auth'
```

`package.json` must have `"type": "module"` for ESM.

---

## Anti-Patterns Checklist

Before submitting any Express code:

```
[ ] No string interpolation in SQL queries
[ ] No wildcard CORS (origin: '*')
[ ] No hardcoded secrets
[ ] No routes missing auth middleware (check every router.get/post/put/patch/delete)
[ ] No missing body size limit on express.json()
[ ] Error handler has exactly 4 parameters (err, req, res, next)
[ ] Health check is not behind auth middleware
[ ] Rate limiting applied to all routes (especially auth routes)
```
