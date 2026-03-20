# Pattern: Multi-Tenancy

**Problem**: Isolate data between tenants in a shared database while keeping the architecture simple
**Applies to**: Node.js backend with PostgreSQL
**Last validated**: [Not yet validated — template]

---

## Solution Overview

Row-Level Security (RLS) in PostgreSQL is the recommended approach:
1. Every tenant-scoped table has a `tenant_id` column
2. PostgreSQL RLS policies enforce that queries only see their tenant's rows
3. App sets the tenant context at the start of each request
4. No application-level filtering needed — database enforces it

Alternative: separate schemas per tenant (more isolation, more complexity). Use schema-per-tenant only if you have regulatory requirements for strict isolation.

---

## Database Setup (Row-Level Security)

```sql
-- migrations/002_multi_tenancy.sql

-- Create tenants table
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add tenant_id to all tenant-scoped tables
ALTER TABLE users ADD COLUMN tenant_id UUID REFERENCES tenants(id);
ALTER TABLE [feature_table] ADD COLUMN tenant_id UUID NOT NULL REFERENCES tenants(id);

-- Create a low-privilege role for app connections
CREATE ROLE app_user;
GRANT CONNECT ON DATABASE [dbname] TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Enable RLS on tenant-scoped tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE [feature_table] ENABLE ROW LEVEL SECURITY;

-- Create RLS policy using session variable
CREATE POLICY tenant_isolation ON users
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE POLICY tenant_isolation ON [feature_table]
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Bypass RLS for superuser connections (for migrations)
-- The app_user role respects RLS; postgres superuser bypasses it
```

---

## Backend Implementation (Node.js/Express)

### Tenant Resolution Middleware

```javascript
// src/middleware/tenant.js
export async function resolveTenant(req, res, next) {
  // Option 1: Subdomain-based (api.tenant.example.com)
  const host = req.hostname;
  const subdomain = host.split('.')[0];

  // Option 2: Header-based (X-Tenant-ID)
  // const tenantId = req.headers['x-tenant-id'];

  // Option 3: JWT claim (preferred — no extra DB lookup)
  const tenantId = req.user?.tenantId;  // Set by auth middleware

  if (!tenantId) {
    return res.status(400).json({ error: 'Tenant context required' });
  }

  req.tenantId = tenantId;
  next();
}
```

### Database Client with RLS Context

```javascript
// src/db/tenant-client.js
import { pool } from './pool.js';

export async function withTenant(tenantId, callback) {
  const client = await pool.connect();

  try {
    // Set tenant context for this connection's session
    await client.query(
      `SET LOCAL app.tenant_id = '${tenantId}'`
    );

    return await callback(client);
  } finally {
    client.release();
  }
}

// Usage in route handler
router.get('/items', requireAuth, resolveTenant, async (req, res) => {
  const items = await withTenant(req.tenantId, async (db) => {
    // RLS automatically filters to this tenant's rows
    const result = await db.query('SELECT * FROM items ORDER BY created_at DESC');
    return result.rows;
  });

  res.json({ items });
});
```

### Tenant-Aware Auth JWT

```javascript
// Include tenantId in JWT payload
export function generateAccessToken(user) {
  return jwt.sign(
    {
      sub: user.id,
      role: user.role,
      tenantId: user.tenant_id,  // Include in token
    },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
}

// Auth middleware extracts tenantId from token
export function requireAuth(req, res, next) {
  // ... verify token ...
  req.user = {
    id: payload.sub,
    role: payload.role,
    tenantId: payload.tenantId,  // Available on req.user
  };
  next();
}
```

---

## Tenant-Specific Subdomains (Dynamic Routing)

### DNS Setup (Cloudflare)

```hcl
# Wildcard CNAME for *.example.com → your load balancer
resource "cloudflare_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "CNAME"
  value   = var.alb_dns_name
  proxied = true
}
```

### Express Subdomain Handling

```javascript
// src/middleware/subdomain.js
export async function resolveSubdomain(req, res, next) {
  const host = req.hostname;
  const parts = host.split('.');

  // Skip if no subdomain (e.g., www.example.com or example.com)
  if (parts.length < 3 || parts[0] === 'www') {
    return next();
  }

  const slug = parts[0];

  // Look up tenant by slug
  const result = await db.query(
    'SELECT id, name FROM tenants WHERE slug = $1',
    [slug]
  );

  if (!result.rows[0]) {
    return res.status(404).json({ error: 'Tenant not found' });
  }

  req.tenant = result.rows[0];
  next();
}
```

---

## Gotchas

1. **Never concatenate tenantId directly into SQL** — always use parameterized queries for tenant lookups; the `SET LOCAL` approach is safe but only for UUIDs
2. **Superuser bypasses RLS** — use a separate app_user role that respects RLS; don't connect as postgres
3. **RLS adds a slight query overhead** — negligible for most apps, measurable at very high load
4. **Migrations must bypass RLS** — run migrations as superuser, not app_user
5. **Test RLS in CI** — write tests that verify a user from tenant A cannot read tenant B's data

---

## See Also

- `stacks/backend/nodejs-express.md` — Database connection setup
- `security/CHECKLIST.md` — Multi-tenancy security checklist
- `brain/patterns/auth.md` — JWT with tenant claims
