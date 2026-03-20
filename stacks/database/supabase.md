# Database Stack: Supabase

Use when: rapid development, realtime features built-in, or auth + DB in one service.

---

## When to Choose Supabase vs RDS

| Scenario | Supabase | RDS PostgreSQL |
|---|---|---|
| Rapid MVP | ✅ No infra setup | ❌ ~20 min infra setup |
| Realtime (row-level) | ✅ Built-in | ❌ Requires custom setup |
| Auth built-in | ✅ | ❌ (build your own) |
| Full SQL control | ✅ (it's PostgreSQL) | ✅ |
| Custom infra/VPC | ❌ | ✅ |
| Self-hosted option | ✅ | ✅ (it IS self-hosted) |
| Production scale SLA | ✅ Pro plan | ✅ |

---

## Connection Options

### Option 1: Direct PostgreSQL (same as RDS)
```javascript
// Uses standard pg library — identical to RDS patterns
import pg from 'pg'
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,  // From Supabase dashboard
  ssl: { rejectUnauthorized: false }
})
```

### Option 2: Supabase JS Client (for realtime/auth)
```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY  // Server-side only
)

// Typed queries
const { data, error } = await supabase
  .from('users')
  .select('id, email, name')
  .eq('role', 'admin')
  .limit(20)
```

**Use Option 1** (direct PostgreSQL) for the backend API — consistent with `stacks/backend/nodejs-express.md` patterns. Use Option 2 only for realtime subscriptions.

---

## Row-Level Security (RLS)

Supabase's killer feature — enable it:

```sql
-- Enable RLS on table
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;

-- Users can only see their own habits
CREATE POLICY "users_own_habits" ON habits
  FOR ALL
  USING (user_id = auth.uid());
```

RLS is enforced at the database level — an accidental missing WHERE clause won't expose another user's data.

---

## Realtime Subscriptions (admin/mobile)

```typescript
// Frontend — subscribe to changes
const channel = supabase
  .channel('habits-changes')
  .on('postgres_changes',
    { event: '*', schema: 'public', table: 'habits', filter: `user_id=eq.${userId}` },
    (payload) => console.log('Change:', payload)
  )
  .subscribe()

// Cleanup
return () => supabase.removeChannel(channel)
```

---

## Key Differences from RDS Setup

1. No OpenTofu for database infra — Supabase manages it
2. Use Supabase dashboard for connection strings
3. Migrations run via Supabase CLI: `supabase db push`
4. Service role key in Secrets Manager (not just DATABASE_URL)
5. RLS must be explicitly enabled per table (default: disabled)
