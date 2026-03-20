# JWT Authentication — Implementation Patterns

---

## Architecture

```
Client                    Server
  │── POST /api/auth/login ──►│ Verify credentials
  │◄── { accessToken, ────────│ Sign JWT (15min) + refresh (7d)
  │      refreshToken }       │
  │                           │
  │── GET /api/users ─────────│ auth middleware validates JWT
  │   Authorization: Bearer   │
  │◄── { users } ─────────────│
  │                           │
  │── POST /api/auth/refresh ─│ Validate refresh token
  │   { refreshToken }        │ Issue new access token
  │◄── { accessToken } ───────│
  │                           │
  │── POST /api/auth/logout ──│ Delete refresh token from DB
  │◄── { success: true } ─────│
```

---

## Token Configuration

```javascript
// src/config/auth.js
export const JWT_CONFIG = {
  accessTokenExpiry:  '15m',    // Short-lived — minimize exposure window
  refreshTokenExpiry: '7d',     // Long-lived — stored in DB
  algorithm:          'HS256',  // HMAC-SHA256 — symmetric, fine for single service
  issuer:             process.env.APP_NAME ?? 'app',
}

// HS256 is correct for single-service auth
// Use RS256 only if multiple services need to verify tokens independently
```

---

## Token Payload

Keep JWT payload minimal — JWTs are not encrypted (only signed):

```javascript
// ✅ CORRECT — minimal payload
const payload = {
  sub: user.id,     // Subject — user ID
  role: user.role,  // For authorization checks
  iat: Math.floor(Date.now() / 1000),  // Issued at
}

// ❌ WRONG — too much data in JWT
const payload = {
  id: user.id,
  email: user.email,      // Don't include — PII, payload is readable
  name: user.name,        // Don't include
  permissions: [...],     // Don't include — use role checks
  passwordHash: '...',    // NEVER include
}
```

---

## Full Auth Implementation

```javascript
// src/routes/auth.js
import { Router } from 'express'
import jwt from 'jsonwebtoken'
import bcrypt from 'bcrypt'
import { pool } from '../db.js'
import { validate } from '../middleware/validate.js'
import { loginSchema, registerSchema, refreshSchema } from '../schemas/auth.js'
import { auth } from '../middleware/auth.js'

const router = Router()

router.post('/register', validate(registerSchema), async (req, res) => {
  const { email, password, name } = req.body

  // Check for existing user
  const { rows: existing } = await pool.query(
    'SELECT id FROM users WHERE email = $1',
    [email]
  )
  if (existing[0]) throw Object.assign(new Error('Email already registered'), { statusCode: 409 })

  // Hash password
  const passwordHash = await bcrypt.hash(password, 12)  // cost factor 12

  // Create user
  const { rows: [user] } = await pool.query(
    'INSERT INTO users (id, email, password, name, role) VALUES (gen_random_uuid(), $1, $2, $3, $4) RETURNING id, email, name, role',
    [email, passwordHash, name, 'user']
  )

  const tokens = generateTokens(user)
  await storeRefreshToken(user.id, tokens.refreshToken)

  res.status(201).json({ user, ...tokens })
})

router.post('/login', validate(loginSchema), async (req, res) => {
  const { email, password } = req.body

  const { rows: [user] } = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  )

  // Use constant-time comparison — don't reveal if email exists
  const passwordMatch = user 
    ? await bcrypt.compare(password, user.password)
    : await bcrypt.compare(password, '$2b$12$invalidhashtopreventtimingattack')

  if (!user || !passwordMatch) {
    throw Object.assign(new Error('Invalid email or password'), { statusCode: 401 })
  }

  const tokens = generateTokens(user)
  await storeRefreshToken(user.id, tokens.refreshToken)

  const { password: _, ...safeUser } = user  // Never return password hash
  res.json({ user: safeUser, ...tokens })
})

router.post('/refresh', validate(refreshSchema), async (req, res) => {
  const { refreshToken } = req.body

  let payload
  try {
    payload = jwt.verify(refreshToken, process.env.JWT_SECRET)
  } catch {
    throw Object.assign(new Error('Invalid refresh token'), { statusCode: 401 })
  }

  // Check token exists in DB (enables logout/revocation)
  const { rows: [stored] } = await pool.query(
    'SELECT * FROM refresh_tokens WHERE token = $1 AND user_id = $2 AND expires_at > NOW()',
    [refreshToken, payload.sub]
  )
  if (!stored) throw Object.assign(new Error('Token not found or expired'), { statusCode: 401 })

  // Rotate: delete old, issue new (prevents token reuse after logout)
  await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken])

  const { rows: [user] } = await pool.query(
    'SELECT id, email, name, role FROM users WHERE id = $1',
    [payload.sub]
  )

  const tokens = generateTokens(user)
  await storeRefreshToken(user.id, tokens.refreshToken)

  res.json(tokens)
})

router.post('/logout', auth, async (req, res) => {
  // Delete all refresh tokens for this user
  await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.user.sub])
  res.json({ success: true })
})

// Helpers
function generateTokens(user) {
  const accessToken = jwt.sign(
    { sub: user.id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '15m', issuer: 'app' }
  )
  const refreshToken = jwt.sign(
    { sub: user.id },
    process.env.JWT_SECRET,
    { expiresIn: '7d', issuer: 'app' }
  )
  return { accessToken, refreshToken }
}

async function storeRefreshToken(userId, token) {
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)  // 7 days
  await pool.query(
    'INSERT INTO refresh_tokens (token, user_id, expires_at) VALUES ($1, $2, $3)',
    [token, userId, expiresAt]
  )
}

export default router
```

---

## Refresh Tokens Table

```sql
CREATE TABLE IF NOT EXISTS refresh_tokens (
  token       VARCHAR(500) PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
```

---

## Token Cleanup Cron

```sql
-- Run daily to clean expired tokens
DELETE FROM refresh_tokens WHERE expires_at < NOW();
```

Add as a scheduled ECS task or Lambda cron.

---

## Security Checklist

```
[ ] bcrypt cost factor is 12 (not 8, not 10)
[ ] Constant-time comparison (bcrypt.compare) — prevents timing attacks
[ ] Access token TTL: 15 minutes maximum
[ ] Refresh tokens stored in DB (enables revocation)
[ ] Refresh token rotation on every use (invalidate old, issue new)
[ ] JWT_SECRET is at least 64 characters (256-bit)
[ ] JWT_SECRET from Secrets Manager, not hardcoded
[ ] Password hash never returned in any response
[ ] Invalid credentials: same error message for wrong email AND wrong password
[ ] Rate limiting on /login and /register endpoints (see authRateLimiter)
```
