# Zod — Schema Validation Patterns

Read this before adding any input validation to backend endpoints.

---

## Core Concept

Zod schemas define the expected shape of data. They parse AND validate simultaneously — invalid data throws, valid data is returned as typed and coerced.

```javascript
import { z } from 'zod'

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
})

// safeParse — returns { success, data } or { success, error } — never throws
const result = schema.safeParse(req.body)
if (!result.success) {
  return res.status(400).json({ error: result.error.flatten().fieldErrors })
}
const { email, password } = result.data  // Typed and validated
```

---

## Common Schema Patterns

### String validations
```javascript
z.string()                              // any string
z.string().email()                      // valid email
z.string().url()                        // valid URL
z.string().uuid()                       // valid UUID
z.string().min(1).max(255)              // length constraints
z.string().regex(/^[a-z0-9-]+$/)        // pattern match
z.string().trim().toLowerCase()          // transform: normalize
z.string().optional()                   // allows undefined
z.string().nullable()                   // allows null
z.string().default('active')            // default value if omitted
```

### Number validations
```javascript
z.number().int()                        // integer only
z.number().positive()                   // > 0
z.number().min(1).max(100)             // range
z.coerce.number()                       // coerce string "42" → 42 (useful for query params)
z.coerce.number().int().min(1)         // coerce + validate
```

### Enum
```javascript
z.enum(['user', 'admin', 'moderator'])  // explicit allowed values
z.nativeEnum(UserRole)                  // TypeScript enum
```

### Object schema
```javascript
const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(255).trim(),
  role: z.enum(['user', 'admin']).default('user')
})
  .strict()  // No extra keys allowed
```

### Partial update schema (PATCH endpoints)
```javascript
const updateUserSchema = createUserSchema
  .pick({ name: true, role: true })  // only these fields
  .partial()                          // all optional

// Result: { name?: string, role?: 'user' | 'admin' }
```

---

## Validate Middleware

```javascript
// src/middleware/validate.js

// Validate request body
export const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body)
  if (!result.success) {
    return res.status(400).json({
      error: 'Validation failed',
      details: result.error.flatten().fieldErrors
    })
  }
  req.body = result.data  // Replace with parsed/transformed values
  next()
}

// Validate query parameters (always coerce strings to correct types)
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

## Query Parameter Schema

Query params are always strings. Use `z.coerce` to convert:

```javascript
// src/schemas/pagination.js
import { z } from 'zod'

export const paginationSchema = z.object({
  limit:  z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
  sort:   z.enum(['asc', 'desc']).default('desc'),
  search: z.string().trim().optional()
})

// Usage
router.get('/', auth, validateQuery(paginationSchema), async (req, res) => {
  const { limit, offset, sort, search } = req.query  // Now typed numbers/strings
  // ...
})
```

---

## Error Response Format

Use `flatten()` for structured field errors:

```javascript
const result = schema.safeParse(body)
if (!result.success) {
  // flatten() produces:
  // {
  //   formErrors: [],  // top-level errors
  //   fieldErrors: {   // per-field errors
  //     email: ['Invalid email'],
  //     password: ['String must contain at least 8 character(s)']
  //   }
  // }
  return res.status(400).json({
    error: 'Validation failed',
    details: result.error.flatten().fieldErrors
  })
}
```

---

## Advanced Patterns

### Conditional validation
```javascript
const schema = z.object({
  type: z.enum(['individual', 'company']),
  companyName: z.string().optional()
}).refine(data => {
  if (data.type === 'company' && !data.companyName) return false
  return true
}, { message: 'Company name required for company accounts', path: ['companyName'] })
```

### Cross-field validation (password confirm)
```javascript
const registrationSchema = z.object({
  password: z.string().min(8),
  confirmPassword: z.string()
}).refine(data => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ['confirmPassword']
})
```

### Transform on parse
```javascript
const schema = z.object({
  email: z.string().email().toLowerCase().trim(),  // normalize email
  tags: z.string().transform(s => s.split(',').map(t => t.trim()))  // "a,b,c" → ["a","b","c"]
})
```

---

## Anti-Patterns

```javascript
// ❌ WRONG — using parse() in route handlers (throws untyped error)
const data = schema.parse(req.body)

// ✅ CORRECT — safeParse() returns structured error
const result = schema.safeParse(req.body)
if (!result.success) return res.status(400).json(...)

// ❌ WRONG — not assigning parsed data back to req.body
schema.safeParse(req.body)
const { email } = req.body  // Still has original, uncoerced values

// ✅ CORRECT
const result = schema.safeParse(req.body)
req.body = result.data  // Use coerced/transformed values

// ❌ WRONG — not using .strict() on object schemas (allows extra keys)
const schema = z.object({ email: z.string() })
schema.parse({ email: 'x', admin: true })  // Succeeds! admin sneaks in

// ✅ CORRECT
const schema = z.object({ email: z.string() }).strict()
// OR to strip unknown keys:
const schema = z.object({ email: z.string() }).strip()  // removes extra keys
```
