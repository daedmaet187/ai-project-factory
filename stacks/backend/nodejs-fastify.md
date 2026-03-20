# Backend Stack: Node.js + Fastify

Use this when: high-throughput API, schema-first development, or when built-in JSON Schema validation is preferred over Zod middleware.

---

## When to Choose Fastify vs Express

| Scenario | Fastify | Express 5 |
|---|---|---|
| Raw throughput priority | ✅ Faster by ~20% | ❌ |
| Schema-first JSON Schema | ✅ Built-in | ❌ (Zod middleware) |
| Plugin ecosystem familiarity | ✅ | ✅ |
| Most examples/resources | ❌ | ✅ |
| WebSocket support | ✅ (@fastify/websocket) | ✅ (ws/socket.io) |

---

## Project Structure

```
src/
├── index.js              ← Entry point
├── app.js                ← Fastify instance, plugin registration
├── config.js             ← Config from env
├── db.js                 ← pg pool
├── plugins/
│   ├── auth.js           ← @fastify/jwt registration
│   ├── cors.js           ← @fastify/cors registration
│   └── rateLimit.js      ← @fastify/rate-limit registration
└── routes/
    ├── auth/
    │   ├── index.js      ← Route definitions
    │   └── schema.js     ← JSON Schema for auth routes
    └── users/
        ├── index.js
        └── schema.js
```

---

## app.js Setup

```javascript
// src/app.js
import Fastify from 'fastify'
import fastifyHelmet from '@fastify/helmet'
import fastifyCors from '@fastify/cors'
import fastifyJwt from '@fastify/jwt'
import fastifyRateLimit from '@fastify/rate-limit'
import authRoutes from './routes/auth/index.js'
import userRoutes from './routes/users/index.js'

export async function buildApp(opts = {}) {
  const app = Fastify({
    logger: {
      level: process.env.LOG_LEVEL ?? 'info',
      transport: process.env.NODE_ENV === 'development'
        ? { target: 'pino-pretty' }
        : undefined
    },
    ...opts
  })

  // Security headers
  await app.register(fastifyHelmet)

  // CORS
  await app.register(fastifyCors, {
    origin: process.env.ALLOWED_ORIGINS?.split(',') ?? [],
    credentials: true
  })

  // Rate limiting
  await app.register(fastifyRateLimit, {
    max: 100,
    timeWindow: '1 minute'
  })

  // JWT
  await app.register(fastifyJwt, {
    secret: process.env.JWT_SECRET
  })

  // Health check
  app.get('/health', async () => ({ status: 'ok', timestamp: new Date().toISOString() }))

  // Routes
  await app.register(authRoutes, { prefix: '/api/auth' })
  await app.register(userRoutes, { prefix: '/api/users' })

  return app
}
```

---

## Route with JSON Schema Validation

```javascript
// src/routes/auth/index.js
import { loginSchema, registerSchema } from './schema.js'
import { pool } from '../../db.js'

export default async function authRoutes(fastify) {
  fastify.post('/login', { schema: loginSchema }, async (request, reply) => {
    const { email, password } = request.body  // Already validated by schema
    
    const { rows } = await pool.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    )
    // ...
    const token = fastify.jwt.sign({ id: user.id, role: user.role }, { expiresIn: '15m' })
    return { accessToken: token }
  })
}
```

```javascript
// src/routes/auth/schema.js
export const loginSchema = {
  body: {
    type: 'object',
    required: ['email', 'password'],
    properties: {
      email: { type: 'string', format: 'email' },
      password: { type: 'string', minLength: 8 }
    },
    additionalProperties: false
  },
  response: {
    200: {
      type: 'object',
      properties: {
        accessToken: { type: 'string' }
      }
    }
  }
}
```

---

## Auth Decorator

```javascript
// Auth preHandler — add to any route that needs authentication
fastify.decorate('authenticate', async function(request, reply) {
  try {
    await request.jwtVerify()
  } catch (err) {
    reply.code(401).send({ error: 'Unauthorized' })
  }
})

// Usage on protected route
fastify.get('/profile', {
  preHandler: [fastify.authenticate],
  schema: profileSchema
}, async (request) => {
  const user = request.user  // { id, role } from JWT payload
  // ...
})
```

---

## Key Differences from Express

| Feature | Express 5 | Fastify |
|---|---|---|
| Error handling | `app.use(errorHandler)` | `setErrorHandler` hook |
| Request validation | Zod middleware | JSON Schema built-in |
| Route registration | `router.get(path, handler)` | `fastify.get(path, { schema }, handler)` |
| Plugins | `app.use(middleware)` | `fastify.register(plugin, opts)` |
| Logging | Manual (`console`, `winston`) | Pino built-in |
| Test server | `supertest` | `fastify.inject()` |
