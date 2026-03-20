# Secrets Management — AWS Secrets Manager Patterns

---

## Core Rule

**Secrets never appear in**:
- Source code
- `.env` files committed to git
- GitHub Actions env vars (use GitHub Secrets)
- ECS task definition `environment` field
- Logs
- Error messages to clients

**Secrets always live in**: AWS Secrets Manager. Applications read them at startup.

---

## Generating Secrets (OpenTofu)

```hcl
# Generate in infra — never manually
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
  min_special = 8
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "/${var.project_name}/${var.environment}/app"
  recovery_window_in_days = 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    JWT_SECRET    = random_password.jwt_secret.result
    DB_PASSWORD   = random_password.db_password.result
    DATABASE_URL  = "postgresql://${var.db_user}:${random_password.db_password.result}@${aws_db_instance.postgres.endpoint}/${var.db_name}?sslmode=require"
  })

  lifecycle {
    ignore_changes = [secret_string]  # Prevent OpenTofu from overwriting manual rotations
  }
}
```

---

## Reading Secrets at App Startup

```javascript
// src/config.js — called once at startup, before server starts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'

const client = new SecretsManagerClient({ region: process.env.AWS_REGION ?? 'us-east-1' })

let _config = null

export async function loadConfig() {
  if (_config) return _config  // Cached after first load

  if (process.env.NODE_ENV === 'development') {
    // Local development: use .env.local (gitignored)
    _config = {
      jwtSecret: process.env.JWT_SECRET,
      databaseUrl: process.env.DATABASE_URL,
    }
    return _config
  }

  // Production: load from Secrets Manager
  const secretArn = process.env.SECRETS_ARN
  if (!secretArn) throw new Error('SECRETS_ARN environment variable required')

  const { SecretString } = await client.send(
    new GetSecretValueCommand({ SecretId: secretArn })
  )
  
  const secrets = JSON.parse(SecretString)
  
  _config = {
    jwtSecret: secrets.JWT_SECRET,
    databaseUrl: secrets.DATABASE_URL,
  }
  
  return _config
}
```

```javascript
// src/index.js — startup sequence
import { loadConfig } from './config.js'
import { createApp } from './app.js'

async function start() {
  const config = await loadConfig()
  
  // Secrets are now available — pass to modules that need them
  const app = createApp(config)
  
  app.listen(process.env.PORT ?? 3000, () => {
    console.log(`Server running on port ${process.env.PORT ?? 3000}`)
    // Never log secrets
  })
}

start().catch(err => {
  console.error('Startup failed:', err.message)
  process.exit(1)
})
```

---

## ECS: Injecting Secrets into Containers

Secrets Manager secrets are injected at container startup via the `secrets` field in the task definition. **Never use the `environment` field for secrets**.

```hcl
container_definitions = jsonencode([{
  name  = "api"
  image = "${aws_ecr_repository.api.repository_url}:latest"
  
  # ✅ Secrets from Secrets Manager — encrypted in transit and at rest
  secrets = [
    {
      name      = "JWT_SECRET"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:JWT_SECRET::"
    },
    {
      name      = "DATABASE_URL"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:DATABASE_URL::"
    }
  ]
  
  # ✅ Non-sensitive config only
  environment = [
    { name = "NODE_ENV", value = "production" },
    { name = "PORT",     value = "3000" }
  ]
}])
```

The container receives these as environment variables — same as regular env vars, but the values are never stored in task definition plaintext.

---

## IAM Permissions for Secret Access

The ECS task IAM role must have permission to read the secret:

```hcl
resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${var.project_name}-${var.environment}-task-secrets"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.app.arn]
    }]
  })
}
```

---

## .gitignore Rules

```gitignore
# Local secret files — NEVER commit these
.env
.env.local
.env.development.local
.env.production.local
*.tfvars
!*.tfvars.example

# Never commit these
*.pem
*.p12
*.key
service-account.json
```

---

## Secret Rotation

After project setup, rotate personal tokens used during bootstrap:

1. GitHub PAT: Create new token with same scopes, update GitHub Secrets
2. Cloudflare API token: Create new token, update GitHub Secrets
3. AWS access keys: Create new key pair for CI/CD IAM user, update GitHub Secrets, deactivate old keys

Application secrets (JWT, DB password) are rotated via Secrets Manager rotation feature or by updating the secret version and redeploying ECS.
