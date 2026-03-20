# Database Stack: PostgreSQL 16 on AWS RDS

Default database stack. Use for all projects that need relational data, complex queries, or ACID guarantees.

---

## RDS Configuration (via OpenTofu)

```hcl
resource "aws_db_instance" "postgres" {
  identifier        = "${var.project_name}-${var.environment}"
  engine            = "postgres"
  engine_version    = "16.3"
  instance_class    = local.db_instance_class  # varies by scale tier
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  deletion_protection       = true           # Never change this to false in production
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final"
  multi_az                  = var.environment == "production"

  performance_insights_enabled = true
  monitoring_interval          = 60

  tags = local.common_tags
}

# Instance class by scale
locals {
  db_instance_class = {
    mvp        = "db.t3.micro"
    growth     = "db.t3.small"
    enterprise = "db.r7g.large"
  }[var.scale_tier]
}
```

---

## Connection String Format

```
postgresql://[user]:[password]@[host]:[port]/[dbname]?sslmode=require
```

The application reads this from `DATABASE_URL` environment variable, sourced from Secrets Manager.

---

## Migration Pattern

Use raw SQL migration files. No ORM migration tool.

```
migrations/
├── 001_initial_schema.sql
├── 002_add_roles.sql
├── 003_add_refresh_tokens.sql
└── 004_add_habits.sql   ← next migration
```

Migration runner script (runs during Phase 7):
```bash
#!/bin/bash
# scripts/migrate.sh
set -e

DATABASE_URL=${DATABASE_URL:-"$(aws secretsmanager get-secret-value \
  --secret-id "/${PROJECT}/${ENV}/app" \
  --query 'SecretString' --output text | jq -r '.DATABASE_URL')"}

# Run all migrations in order
for migration in migrations/*.sql; do
  echo "Running $migration..."
  psql "$DATABASE_URL" -f "$migration" -v ON_ERROR_STOP=1
done

echo "All migrations complete."
```

---

## Standard Schema Patterns

```sql
-- Standard table structure
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       VARCHAR(255) NOT NULL UNIQUE,
  password    VARCHAR(255) NOT NULL,
  name        VARCHAR(255) NOT NULL,
  role        VARCHAR(50) NOT NULL DEFAULT 'user',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Always index foreign keys and common query columns
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

---

## Query Patterns (Node.js/pg)

```javascript
// ✅ Parameterized — always
const { rows } = await pool.query(
  'SELECT id, email, name, role FROM users WHERE email = $1',
  [email]
)

// ✅ Multiple params
await pool.query(
  'INSERT INTO habits (id, user_id, name, frequency) VALUES (gen_random_uuid(), $1, $2, $3)',
  [userId, name, frequency]
)

// ✅ Pagination
const { rows } = await pool.query(
  'SELECT * FROM habits WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
  [userId, limit, offset]
)

// ✅ Transaction
const client = await pool.connect()
try {
  await client.query('BEGIN')
  await client.query('INSERT INTO habits ...', [...])
  await client.query('UPDATE users SET habit_count = habit_count + 1 WHERE id = $1', [userId])
  await client.query('COMMIT')
} catch (err) {
  await client.query('ROLLBACK')
  throw err
} finally {
  client.release()
}
```

---

## Security Groups

```hcl
# RDS only accessible from ECS tasks — not public
resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]  # ECS only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Rule**: RDS must never be in a public subnet. Never allow public internet access.
