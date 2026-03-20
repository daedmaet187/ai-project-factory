# Database Migration Patterns

How to write and run database migrations safely.

---

## Migration File Format

```
migrations/
├── 001_initial_schema.sql
├── 002_add_users_table.sql
├── 003_add_refresh_tokens.sql
└── ...
```

Each file is numbered and run in order. Never modify a migration after it's been applied to production.

---

## Migration Template

```sql
-- migrations/004_add_products_table.sql
-- Description: Add products table for inventory management
-- Author: AI Project Factory
-- Date: 2026-03-20

BEGIN;

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_products_name ON products(name);

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

COMMIT;
```

---

## Running Migrations

```bash
#!/bin/bash
# scripts/migrate.sh

set -e

DB_URL="${DATABASE_URL:-}"

if [ -z "$DB_URL" ]; then
  echo "DATABASE_URL not set"
  exit 1
fi

# Create migrations tracking table if not exists
psql "$DB_URL" << 'EOF'
CREATE TABLE IF NOT EXISTS _migrations (
  id SERIAL PRIMARY KEY,
  filename TEXT NOT NULL UNIQUE,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);
EOF

# Run pending migrations
for file in migrations/*.sql; do
  filename=$(basename "$file")
  
  # Check if already applied
  applied=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM _migrations WHERE filename = '$filename'")
  
  if [ "$applied" -eq 0 ]; then
    echo "Applying: $filename"
    psql "$DB_URL" -f "$file"
    psql "$DB_URL" -c "INSERT INTO _migrations (filename) VALUES ('$filename')"
    echo "✅ Applied: $filename"
  else
    echo "⏭️ Skipping: $filename (already applied)"
  fi
done

echo "Migrations complete"
```

---

## Rollback Pattern

For reversible migrations, create a down file:

```sql
-- migrations/004_add_products_table.down.sql
BEGIN;
DROP TABLE IF EXISTS products;
COMMIT;
```

**Warning**: Not all migrations are reversible. Data migrations (INSERT/UPDATE) are especially hard to undo.

---

## Safe Migration Practices

1. **Always use transactions** — BEGIN/COMMIT wraps changes
2. **Test on staging first** — never apply untested migrations to production
3. **Make small changes** — one table or one index per migration
4. **Add indexes concurrently** (for large tables):
   ```sql
   CREATE INDEX CONCURRENTLY idx_name ON table(column);
   ```
5. **Never drop columns in production** — mark as deprecated, clean up later
6. **Backup before major migrations**:
   ```bash
   pg_dump "$DATABASE_URL" > backup_$(date +%Y%m%d).sql
   ```
