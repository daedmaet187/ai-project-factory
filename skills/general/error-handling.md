# Error Handling — Centralized Patterns

---

## Principle

Errors are handled in one place. Routes throw. The error handler catches and responds.

**Client gets**: Generic message for 5xx, specific message for 4xx  
**Logs get**: Full error with stack trace, request context  
**Code gets**: Consistent, predictable error responses

---

## Error Handler (Express)

```javascript
// src/middleware/errorHandler.js

// Structured error class for typed errors
export class AppError extends Error {
  constructor(message, statusCode = 500, code = null) {
    super(message)
    this.name = 'AppError'
    this.statusCode = statusCode
    this.code = code  // Machine-readable code: 'USER_NOT_FOUND', 'INSUFFICIENT_BALANCE'
    this.isOperational = true  // Expected errors vs programming errors
  }
}

// Pre-built error factories
export const NotFoundError = (resource = 'Resource') =>
  new AppError(`${resource} not found`, 404, 'NOT_FOUND')

export const UnauthorizedError = (msg = 'Unauthorized') =>
  new AppError(msg, 401, 'UNAUTHORIZED')

export const ForbiddenError = (msg = 'Forbidden') =>
  new AppError(msg, 403, 'FORBIDDEN')

export const ConflictError = (msg) =>
  new AppError(msg, 409, 'CONFLICT')

export const ValidationError = (msg, details = null) => {
  const err = new AppError(msg, 400, 'VALIDATION_ERROR')
  err.details = details
  return err
}

// The actual error handler middleware — MUST have exactly 4 params
export const errorHandler = (err, req, res, next) => {
  // Log everything internally
  console.error({
    level:   'error',
    message: err.message,
    code:    err.code ?? 'UNKNOWN',
    status:  err.statusCode ?? 500,
    stack:   err.stack,
    request: {
      method: req.method,
      path:   req.path,
      body:   req.body,  // Careful: may contain sensitive data — sanitize in production
      userId: req.user?.sub ?? null
    },
    timestamp: new Date().toISOString()
  })

  // Don't leak details on server errors
  const status = err.statusCode ?? err.status ?? 500
  const isClientError = status >= 400 && status < 500

  const response = {
    error: isClientError ? err.message : 'Internal server error',
  }

  // Include machine-readable code for client handling
  if (err.code && isClientError) response.code = err.code

  // Include validation details
  if (err.details && isClientError) response.details = err.details

  res.status(status).json(response)
}
```

---

## Using Error Classes in Routes

```javascript
import { NotFoundError, ConflictError, AppError } from '../middleware/errorHandler.js'

// Throw errors directly — Express 5 propagates automatically
router.get('/:id', auth, async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [req.params.id])
  
  if (!rows[0]) throw NotFoundError('User')  // → 404 "User not found"
  res.json(rows[0])
})

router.post('/', auth, validate(createUserSchema), async (req, res) => {
  try {
    const { rows: [user] } = await pool.query(
      'INSERT INTO users (email) VALUES ($1) RETURNING *',
      [req.body.email]
    )
    res.status(201).json(user)
  } catch (err) {
    // Handle specific DB error codes
    if (err.code === '23505') {  // PostgreSQL unique_violation
      throw ConflictError('Email already registered')
    }
    throw err  // Re-throw — error handler will catch it
  }
})

// Custom AppError when no factory fits
router.post('/purchase', auth, async (req, res) => {
  const balance = await getUserBalance(req.user.sub)
  if (balance < req.body.amount) {
    throw new AppError('Insufficient balance', 402, 'INSUFFICIENT_BALANCE')
  }
  // ...
})
```

---

## PostgreSQL Error Codes

```javascript
// Common PostgreSQL error codes to handle
const PG_ERRORS = {
  '23505': 'unique_violation',      // Duplicate key
  '23503': 'foreign_key_violation', // Referenced record doesn't exist
  '23502': 'not_null_violation',    // Required field missing
  '22P02': 'invalid_text_representation',  // Invalid UUID format
}

// Utility for handling PG errors
export function handlePgError(err) {
  switch (err.code) {
    case '23505': throw ConflictError('Record already exists')
    case '23503': throw NotFoundError('Referenced record')
    case '22P02': throw new AppError('Invalid ID format', 400, 'INVALID_ID')
    default: throw err  // Unknown DB error — let error handler log it
  }
}
```

---

## Error Response Format

Clients can rely on this consistent format:

```json
// 4xx — client error
{
  "error": "User not found",
  "code": "NOT_FOUND"
}

// 4xx — validation error
{
  "error": "Validation failed",
  "code": "VALIDATION_ERROR",
  "details": {
    "email": ["Invalid email address"],
    "password": ["String must contain at least 8 character(s)"]
  }
}

// 5xx — server error (client gets generic message)
{
  "error": "Internal server error"
}
```

---

## Async Error Patterns

```javascript
// ✅ Express 5 — no try/catch needed for propagation
router.get('/users', auth, async (req, res) => {
  const users = await pool.query('SELECT * FROM users')  // throws → error handler
  res.json(users.rows)
})

// ✅ When you need to handle specific errors locally
router.post('/users', async (req, res) => {
  try {
    const user = await createUser(req.body)
    res.status(201).json(user)
  } catch (err) {
    if (err.code === '23505') throw ConflictError('Email taken')
    throw err  // Re-throw everything else
  }
})

// ❌ WRONG — swallowing errors
router.get('/users', async (req, res) => {
  try {
    const users = await pool.query('SELECT * FROM users')
    res.json(users.rows)
  } catch (err) {
    console.log(err)  // Logged but NOT re-thrown → client gets no response
    // Request hangs forever!
  }
})
```

---

## Startup Error Handling

```javascript
// src/index.js
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled rejection:', reason)
  // Don't exit process — let it continue serving other requests
  // But alert monitoring
})

process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err)
  // This is fatal — exit gracefully
  process.exit(1)
})

// Graceful shutdown
const server = app.listen(PORT)

process.on('SIGTERM', () => {
  console.log('SIGTERM received — shutting down gracefully')
  server.close(() => {
    pool.end()  // Close DB connections
    process.exit(0)
  })
})
```
