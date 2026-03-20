# Infrastructure Stack: AWS ECS Fargate

Default compute stack for containerized APIs.

---

## Architecture Overview

```
Internet
    │
    ▼
Cloudflare DNS (CNAME → ALB)
    │
    ▼
Application Load Balancer (ALB)
  ├── HTTPS:443 → ECS Service (API)
  └── HTTP:80   → Redirect to HTTPS
    │
    ▼
ECS Fargate Cluster
  └── ECS Service
      └── Task Definition
          └── Container: api:latest (pulled from ECR)
              ├── Secrets: from Secrets Manager
              └── Env: NODE_ENV=production, PORT=3000
    │
    ▼
AWS RDS PostgreSQL (private subnet)
```

---

## Module Structure

```
infra/
├── main.tf           ← Module calls + provider config
├── variables.tf      ← Input variables
├── outputs.tf        ← ECR URL, ALB DNS, RDS endpoint
├── versions.tf       ← Provider versions
├── locals.tf         ← Common tags, computed locals
└── modules/
    ├── networking/   ← VPC, subnets, NAT, security groups
    ├── compute/      ← ECR, ECS cluster, task def, service, ALB
    ├── database/     ← RDS instance, subnet group, parameter group
    ├── secrets/      ← Secrets Manager, random passwords
    └── dns/          ← Cloudflare DNS records (CNAME to ALB)
```

---

## main.tf

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
  backend "s3" {
    bucket         = "${var.project_name}-tfstate"
    key            = "${var.environment}/terraform.tfstate"
    region         = var.aws_region
    encrypt        = true
    dynamodb_table = "${var.project_name}-tfstate-lock"
  }
}

provider "aws" { region = var.aws_region }
provider "cloudflare" { api_token = var.cf_api_token }

module "networking" {
  source           = "./modules/networking"
  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  common_tags      = local.common_tags
}

module "secrets" {
  source       = "./modules/secrets"
  project_name = var.project_name
  environment  = var.environment
  db_name      = var.db_name
  db_username  = var.db_username
  common_tags  = local.common_tags
}

module "database" {
  source          = "./modules/database"
  project_name    = var.project_name
  environment     = var.environment
  db_name         = var.db_name
  db_username     = var.db_username
  db_password     = module.secrets.db_password
  subnet_ids      = module.networking.private_subnet_ids
  security_group  = module.networking.rds_security_group_id
  scale_tier      = var.scale_tier
  common_tags     = local.common_tags
}

module "compute" {
  source              = "./modules/compute"
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  secrets_arn         = module.secrets.app_secrets_arn
  scale_tier          = var.scale_tier
  common_tags         = local.common_tags
}

module "dns" {
  source        = "./modules/dns"
  zone_id       = var.cf_zone_id
  domain        = var.domain_name
  api_subdomain = var.api_subdomain
  alb_dns_name  = module.compute.alb_dns_name
}
```

---

## ECS Task Definition Key Points

```hcl
# In modules/compute/main.tf
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-${var.environment}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.task_cpu[var.scale_tier]
  memory                   = local.task_memory[var.scale_tier]
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${aws_ecr_repository.api.repository_url}:latest"
    essential = true

    portMappings = [{ containerPort = 3000, protocol = "tcp" }]

    # Secrets from Secrets Manager — NOT environment field
    secrets = [
      { name = "JWT_SECRET",    valueFrom = "${var.secrets_arn}:JWT_SECRET::" },
      { name = "DATABASE_URL",  valueFrom = "${var.secrets_arn}:DATABASE_URL::" },
    ]

    # Non-sensitive config only
    environment = [
      { name = "NODE_ENV",           value = "production" },
      { name = "PORT",               value = "3000" },
      { name = "ALLOWED_ORIGINS",    value = "https://admin.${var.domain}" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "api"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

locals {
  task_cpu    = { mvp = 256,  growth = 512,  enterprise = 1024 }
  task_memory = { mvp = 512,  growth = 1024, enterprise = 2048 }
}
```

---

## CI/CD — Deploy to ECS

```yaml
# .github/workflows/deploy-backend.yml
name: Deploy Backend

on:
  push:
    branches: [main]
    paths: ['backend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Login to ECR
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, push image
        env:
          ECR_REGISTRY: ${{ steps.ecr-login.outputs.registry }}
          ECR_REPOSITORY: myproject-api
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG backend/
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
                     $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster myproject-production \
            --service myproject-api \
            --force-new-deployment
          
          aws ecs wait services-stable \
            --cluster myproject-production \
            --services myproject-api
```

---

## Outputs

```hcl
# outputs.tf
output "ecr_url" {
  value = module.compute.ecr_url
}
output "alb_dns_name" {
  value = module.compute.alb_dns_name
}
output "rds_endpoint" {
  value     = module.database.endpoint
  sensitive = true
}
output "api_url" {
  value = "https://${var.api_subdomain}.${var.domain_name}"
}
```
