# OpenTofu — Infrastructure Patterns

Read this before making any infrastructure changes.

---

## Module Structure Rules

Every module must have exactly these three files:

```
modules/[module-name]/
├── main.tf        ← Resource definitions
├── variables.tf   ← Input variables (all resources parameterized)
└── outputs.tf     ← Output values (exposed to root or other modules)
```

No exceptions. If you're adding resources, they go in a module.

**Root-level files**:
- `main.tf` — module calls and provider config only
- `variables.tf` — top-level variables
- `outputs.tf` — top-level outputs
- `versions.tf` — required_providers block
- `locals.tf` — computed locals (common tags, etc.)

---

## Module Pattern

```hcl
# modules/database/variables.tf
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (staging, production)"
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true  # ← MANDATORY for any secret value
}

variable "subnet_ids" {
  description = "Private subnet IDs for RDS placement"
  type        = list(string)
}
```

```hcl
# modules/database/outputs.tf
output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true  # ← Always for connection strings
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}
```

---

## Random Secret Generation

Generate all secrets with OpenTofu — never manually create them.

```hcl
# modules/secrets/main.tf

# Generate random passwords
resource "random_password" "db_password" {
  length  = 32
  special = false  # RDS passwords: no special chars
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "random_bytes" "encryption_key" {
  length = 32  # 256-bit key
}

# Store in Secrets Manager
resource "aws_secretsmanager_secret" "app" {
  name                    = "/${var.project_name}/${var.environment}/app"
  recovery_window_in_days = 7  # 7 days before permanent deletion

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    JWT_SECRET      = random_password.jwt_secret.result
    DB_PASSWORD     = random_password.db_password.result
    ENCRYPTION_KEY  = random_bytes.encryption_key.hex
    # DATABASE_URL built after RDS is created — see compute module
  })

  # Lifecycle: prevent accidental rotation destroying secrets
  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

---

## State Management

```bash
# Never edit .tfstate manually

# Import existing resource into state
tofu import aws_s3_bucket.tfstate my-bucket-name

# List resources in state
tofu state list

# Show specific resource in state
tofu state show aws_ecs_service.api

# Remove resource from state (without destroying — use carefully)
tofu state rm aws_ecr_repository.old_repo

# Rename resource in state
tofu state mv aws_ecs_task_definition.api aws_ecs_task_definition.api_v2
```

---

## Backend — Remote State

Always use remote state. Bootstrap the S3 bucket and DynamoDB table before first `tofu init`:

```bash
# Create state bucket (one-time)
aws s3api create-bucket \
  --bucket "${PROJECT_NAME}-tfstate" \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket "${PROJECT_NAME}-tfstate" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${PROJECT_NAME}-tfstate" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name "${PROJECT_NAME}-tfstate-lock" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Workspace Pattern — Multiple Environments

```bash
# Create environments
tofu workspace new staging
tofu workspace new production

# Switch between environments
tofu workspace select staging
tofu apply -var-file=staging.tfvars

tofu workspace select production
tofu apply -var-file=production.tfvars

# List workspaces
tofu workspace list
```

```hcl
# Use workspace name in resource naming
resource "aws_ecs_service" "api" {
  name = "${var.project_name}-${terraform.workspace}-api"
  # ...
}
```

---

## Before Every Apply — Mandatory Sequence

```bash
# 1. Format code
tofu fmt

# 2. Validate syntax
tofu validate
# Must output: "Success! The configuration is valid."

# 3. Plan with output file
tofu plan -out=tfplan.out 2>&1 | tee plan-output.txt

# 4. CRITICAL: Check plan for destroy operations
grep -E "will be destroyed|must be replaced|forces replacement" plan-output.txt
# If any matches → STOP and escalate to Orchestrator

# 5. Check resource counts
grep "Plan:" plan-output.txt
# Review: X to add, Y to change, Z to destroy
# Z > 0 in production → escalate

# 6. Apply
tofu apply tfplan.out

# 7. Verify outputs
tofu output
```

---

## Dependency Management

```hcl
# Explicit dependency when resource creation order matters
# but there's no implicit reference
resource "aws_ecs_service" "api" {
  name = "api"
  # ...
  depends_on = [
    aws_alb_listener.https  # ECS service needs listener to exist first
  ]
}

# Implicit dependency (preferred when possible)
resource "aws_ecs_service" "api" {
  task_definition = aws_ecs_task_definition.api.arn  # ← Implicit dep on task def
}
```

---

## Common Gotchas

### 1. `tofu plan` shows "forces replacement" for ECS task definition
Task definitions are immutable. Each `tofu apply` creates a new revision. This is expected — not a replacement.

### 2. RDS password change causes replacement
```hcl
# Prevent password changes from causing RDS replacement
lifecycle {
  ignore_changes = [password]
}
```

### 3. ECR image tag not tracked by OpenTofu
ECR images are pushed by CI/CD, not OpenTofu. Force ECS service to pull new image:
```bash
aws ecs update-service --cluster NAME --service api --force-new-deployment
```

### 4. CloudFront distribution takes 15–20 min to deploy
Normal behavior. Don't kill the apply — wait for it.

### 5. ACM certificate validation pending
DNS validation can take a few minutes. Add `create_before_destroy` lifecycle if needed.
