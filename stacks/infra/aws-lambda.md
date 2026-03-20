# Infrastructure Stack: AWS Lambda (Serverless)

Use when: bursty workloads, cost-sensitive MVP, no persistent connections needed.

---

## When to Choose Lambda vs ECS Fargate

| Scenario | Lambda | ECS Fargate |
|---|---|---|
| Bursty/infrequent traffic | ✅ | ❌ (always-on cost) |
| Cost-sensitive MVP | ✅ Free tier | ❌ ~$20+/mo minimum |
| WebSockets / SSE | ❌ | ✅ |
| Long-running jobs (>15 min) | ❌ | ✅ |
| Cold start acceptable (<1s) | ✅ | ✅ (no cold start) |
| Container reuse / warm state | ❌ | ✅ |

---

## Architecture

```
Internet → API Gateway (HTTP API) → Lambda Function → RDS Proxy → RDS
                                                      → Secrets Manager
```

**Important**: Lambda + RDS requires RDS Proxy to manage connection pooling. Lambda can't maintain persistent DB connections efficiently.

---

## Lambda Function Setup (Node.js)

```javascript
// handler.js — Lambda entry point
import { buildApp } from './src/app.js'

let app

export const handler = async (event, context) => {
  // Reuse app instance across warm invocations
  if (!app) {
    app = await buildApp()
    await app.ready()
  }
  
  // Use @fastify/aws-lambda for Fastify
  // Use serverless-http for Express
  return handler(event, context)
}
```

---

## OpenTofu for Lambda

```hcl
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-${var.environment}-api"
  role          = aws_iam_role.lambda.arn
  
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.api.repository_url}:latest"
  
  timeout       = 30
  memory_size   = 512
  
  environment {
    variables = {
      NODE_ENV    = "production"
      SECRETS_ARN = aws_secretsmanager_secret.app.arn
    }
  }
  
  vpc_config {
    subnet_ids         = module.networking.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-${var.environment}"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["https://admin.${var.domain}"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}
```

---

## Key Differences from ECS

1. No `tofu plan` needed for Lambda deployment — just push new image to ECR and update function
2. No ALB — use API Gateway HTTP API
3. Cold starts: use provisioned concurrency for latency-sensitive endpoints
4. Connection pooling: RDS Proxy is **required** (Lambda can exhaust RDS connections)
5. Max runtime: 15 minutes — long jobs need separate Lambda or Step Functions
