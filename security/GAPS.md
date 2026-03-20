# Common Security Gaps — How AI Agents Miss Them

This document catalogs the most common security mistakes AI-generated code makes, with specific fixes.

---

## Gap 1: SQL Injection via String Interpolation

**How it happens**: Agent writes SQL query with template literals instead of parameters.

```javascript
// ❌ VULNERABLE — agent commonly writes this
const { rows } = await pool.query(
  `SELECT * FROM users WHERE email = '${email}' AND role = '${role}'`
)

// ✅ SECURE
const { rows } = await pool.query(
  'SELECT * FROM users WHERE email = $1 AND role = $2',
  [email, role]
)
```

**Detection**: Grep for backticks in SQL: ``grep -rn "query\`" src/``

---

## Gap 2: Missing Auth on New Routes

**How it happens**: Agent creates a new route file and forgets to add auth middleware, or creates a route in a file where auth is applied differently.

```javascript
// ❌ MISSING AUTH — common when adding routes late in development
router.get('/stats', async (req, res) => {
  const stats = await getAdminStats()  // Exposes business metrics publicly
  res.json(stats)
})

// ✅ SECURED
router.get('/stats', auth, auth.requireRole('admin'), async (req, res) => {
  const stats = await getAdminStats()
  res.json(stats)
})
```

**Detection**: Audit every route file — list all routes and verify each has auth middleware.

---

## Gap 3: Wildcard CORS in Production

**How it happens**: Agent copies a development config with `origin: '*'` to production.

```javascript
// ❌ VULNERABLE — any website can make authenticated requests
app.use(cors({ origin: '*', credentials: true }))

// ✅ SECURE
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(','),
  credentials: true
}))
```

**Note**: `credentials: true` with `origin: '*'` is actually blocked by browsers — but `credentials: false` with `*` exposes read-only endpoints to any origin.

---

## Gap 4: Exposed Error Details

**How it happens**: Agent uses `err.message` in all responses, including for 500 errors.

```javascript
// ❌ EXPOSES INTERNALS
app.use((err, req, res, next) => {
  res.status(err.status ?? 500).json({ error: err.message })
  // "Connection refused to postgres://user:password@host:5432/db"
  // Exposes: DB host, credentials, internal architecture
})

// ✅ GENERIC FOR SERVER ERRORS
app.use((err, req, res, next) => {
  const status = err.statusCode ?? err.status ?? 500
  res.status(status).json({
    error: status < 500 ? err.message : 'Internal server error'
  })
})
```

---

## Gap 5: Password Hash in API Response

**How it happens**: Agent returns `rows[0]` directly without stripping sensitive fields.

```javascript
// ❌ RETURNS PASSWORD HASH
const { rows: [user] } = await pool.query('SELECT * FROM users WHERE id = $1', [id])
res.json(user)  // Includes user.password (bcrypt hash)

// ✅ EXPLICIT FIELD SELECTION
const { rows: [user] } = await pool.query(
  'SELECT id, email, name, role, created_at FROM users WHERE id = $1',
  [id]
)
res.json(user)
```

---

## Gap 6: Insecure bcrypt Cost Factor

**How it happens**: Agent uses default cost factor (10) or low cost factor for "performance."

```javascript
// ❌ COST 10 — crackable on modern hardware
const hash = await bcrypt.hash(password, 10)

// ✅ COST 12 — significantly harder to crack
const hash = await bcrypt.hash(password, 12)
```

Cost 12 adds ~500ms to hashing — acceptable for auth. Do not reduce for "performance" — it's intentionally slow.

---

## Gap 7: Timing Attack on Login

**How it happens**: Agent checks if user exists first, only compares password if user found.

```javascript
// ❌ TIMING ATTACK — takes longer for existing users
const user = await findUserByEmail(email)
if (!user) return res.status(401).json({ error: 'Invalid credentials' })
const valid = await bcrypt.compare(password, user.password)

// ✅ CONSTANT-TIME — same execution time regardless of user existence
const user = await findUserByEmail(email)
const dummyHash = '$2b$12$invalidhashtopreventtimingattackaaaaaaaaaaaaaaaaaaaa'
const valid = await bcrypt.compare(password, user?.password ?? dummyHash)
if (!user || !valid) return res.status(401).json({ error: 'Invalid credentials' })
```

---

## Gap 8: Refresh Token Not Revocable

**How it happens**: Agent signs refresh token as JWT without database storage — logout doesn't work.

```javascript
// ❌ NOT REVOCABLE — attacker with refresh token can get new access tokens after logout
router.post('/logout', auth, async (req, res) => {
  // Client deletes token, but server can't invalidate it
  res.json({ success: true })
})

// ✅ REVOCABLE — store and delete refresh tokens
// See skills/general/jwt-auth.md for full implementation
await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.user.sub])
```

---

## Gap 9: Missing Rate Limiting on Auth Routes

**How it happens**: Agent applies generic rate limiter globally, doesn't add stricter limit to auth endpoints.

```javascript
// ❌ 100 requests per 15 min on /auth/login — still allows brute force
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }))

// ✅ Stricter limit specifically for auth
import { authRateLimiter } from './middleware/rateLimiter.js'
router.post('/login', authRateLimiter, validate(loginSchema), handler)
// authRateLimiter: max 10 attempts per 15 min, skipSuccessfulRequests: true
```

---

## Gap 10: Overly Permissive IAM

**How it happens**: Agent creates IAM policy with `"*"` resource for simplicity.

```json
// ❌ TOO BROAD — application can access ANY secret
{
  "Effect": "Allow",
  "Action": ["secretsmanager:*"],
  "Resource": "*"
}

// ✅ LEAST PRIVILEGE — only this app's secret
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": ["arn:aws:secretsmanager:us-east-1:123456789:secret:/myapp/production/app-*"]
}
```

---

## Automated Gap Detection

Before any code review, run these checks:

```bash
# SQL injection
grep -rn "query\`\|query(\".*\${" src/

# Hardcoded secrets
grep -rn "password\s*=\s*['\"]" src/
grep -rn "secret\s*=\s*['\"]" src/
grep -rn "AKIA" .  # AWS key IDs

# Missing auth (routes without auth middleware in route files)
grep -n "router\.\(get\|post\|put\|patch\|delete\)" src/routes/*.js | grep -v "auth"

# Wildcard CORS
grep -rn "origin.*\*" src/

# Error message exposure
grep -rn "err\.message\|error\.message" src/middleware/
```
