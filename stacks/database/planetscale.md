# Database Stack: PlanetScale (MySQL)

Use when: serverless database, no server to manage, branch-based schema workflow preferred.

---

## When to Choose PlanetScale vs RDS

| Scenario | PlanetScale | RDS PostgreSQL |
|---|---|---|
| Serverless, auto-scaling | ✅ | ❌ (always-on instance) |
| Schema branching (like git) | ✅ | ❌ |
| Complex SQL, window functions | ❌ MySQL limits | ✅ Full PostgreSQL |
| UUID primary keys | ❌ Prefer int/bigint | ✅ Native UUID |
| Row-level security | ❌ | ✅ |
| Lowest monthly cost (MVP) | ✅ Free tier | ❌ ~$15+/mo minimum |

---

## Connection Setup

PlanetScale uses HTTP-based connections (no persistent TCP). Use `@planetscale/database`:

```javascript
import { connect } from '@planetscale/database'

const conn = connect({
  url: process.env.DATABASE_URL  // pscale://... connection string
})

// Usage — same parameterized pattern but with ?
const results = await conn.execute(
  'SELECT * FROM users WHERE email = ?',
  [email]
)
```

**MySQL vs PostgreSQL syntax differences**:
| PostgreSQL | MySQL/PlanetScale |
|---|---|
| `$1, $2` params | `?, ?` params |
| `gen_random_uuid()` | `UUID()` |
| `TIMESTAMPTZ` | `DATETIME` |
| `RETURNING id` | Not supported — use `insertId` |
| `ILIKE` | `LIKE` (case-insensitive by default with utf8mb4) |

---

## Schema Migration (Branching Workflow)

```bash
# Create development branch
pscale branch create my-app add-habits-table

# Connect to branch
pscale connect my-app add-habits-table --port 3309

# Apply migration against branch
mysql -u root -h 127.0.0.1 -P 3309 my-app < migrations/004_add_habits.sql

# Create deploy request (like a PR for schema)
pscale deploy-request create my-app add-habits-table

# After review, deploy to main
pscale deploy-request deploy my-app [deploy-request-number]
```

---

## Key Differences for Implementers

1. No `gen_random_uuid()` — use `UUID()` or generate UUIDs in application layer
2. No `RETURNING` clause — capture `insertId` from result object
3. Parameterized queries use `?` not `$1`
4. Connection string starts with `pscale://` not `postgresql://`
5. No persistent connections — each query opens a new HTTP connection (handled by SDK)
