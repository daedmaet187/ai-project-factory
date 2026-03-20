# Stack Catalog

This document defines all available stack options per layer and how to select between them.

---

## How to Select a Stack

Use the decision matrix below to auto-recommend a stack based on intake answers. If the human specified preferences, validate them against this catalog. If a requested stack isn't listed, write an ADR before proceeding.

---

## Decision Matrix

| Need | Recommended Stack |
|---|---|
| Mobile app (iOS/Android) + web admin + API | Full-stack Mobile combo |
| Web only, SEO matters (marketing pages, blogs) | Next.js App Router |
| Web only, SPA, no SEO (internal tools, dashboards) | React + Vite |
| API only, no frontend | Node.js/Express or FastAPI |
| Serverless API, bursty traffic, low idle cost | Cloudflare Workers or AWS Lambda |
| Persistent API, long-running connections, WebSockets | ECS Fargate |
| Simple database, low cost, no raw SQL needed | Supabase |
| Complex relational queries, reporting, strict ACID | PostgreSQL on RDS |
| Multi-tenant SaaS with high per-tenant isolation | PostgreSQL on RDS with row-level security |
| Real-time features (chat, notifications, live data) | Node.js/Express + Socket.io + Redis |
| Python-first team | Python/FastAPI backend |
| Heavy background jobs / workers | ECS Fargate (separate task definition) |
| Need crash reports for mobile | Firebase Crashlytics (free) |
| Need unified errors across API + mobile | Sentry |
| Need traces and dashboards | Grafana Cloud (free tier) |
| Need audit trail (who did what) | AWS CloudTrail |
| Need enterprise full-platform observability | Datadog ($46+/host) |

---

## Pre-Built Stack Combinations

### Combo 1: Full-Stack Mobile *(recommended for mobile-first products)*

Best for: Consumer apps with mobile + web admin panel + backend API

| Layer | Technology |
|---|---|
| **Backend** | Node.js 22 + Express 5 + ESM + Zod |
| **Admin frontend** | React 19 + Vite + TailwindCSS 4 + shadcn/ui |
| **Mobile** | Flutter 3.x + Riverpod 2 + go_router 14 |
| **Database** | PostgreSQL 16 on AWS RDS |
| **Container registry** | AWS ECR |
| **Compute** | AWS ECS Fargate |
| **Load balancer** | AWS ALB |
| **CDN/DNS** | Cloudflare |
| **Admin deploy** | AWS S3 + CloudFront |
| **Infra as code** | OpenTofu |
| **CI/CD** | GitHub Actions |
| **Secrets** | AWS Secrets Manager |
| **Observability** | Tier 1: CloudWatch + Sentry free + Firebase Crashlytics; Tier 2: + Grafana Cloud |

Stack guides:
- Backend: `stacks/backend/nodejs-express.md`
- Admin: `stacks/frontend/react-shadcn.md`
- Mobile: `stacks/mobile/flutter-riverpod.md`
- Infra: `stacks/infra/aws-ecs-fargate.md`
- Database: `stacks/database/postgresql-rds.md`
- Observability: `stacks/observability/OBSERVABILITY.md`

---

### Combo 2: Web-Only SaaS *(recommended for B2B tools and dashboards)*

Best for: SaaS products that are entirely web-based, no mobile app needed

| Layer | Technology |
|---|---|
| **Full-stack** | Next.js 15 App Router + React 19 |
| **Backend API** | Next.js API Routes or separate Node.js/Express |
| **UI** | TailwindCSS 4 + shadcn/ui |
| **Database** | PostgreSQL 16 on AWS RDS |
| **Compute** | ECS Fargate (API) + S3 + CloudFront (admin/frontend) |
| **CDN/DNS** | Cloudflare |
| **Infra** | OpenTofu |
| **CI/CD** | GitHub Actions |
| **Observability** | Tier 1: CloudWatch + Sentry free + Firebase Crashlytics; Tier 2: + Grafana Cloud |

Stack guides:
- Frontend: `stacks/frontend/nextjs.md`
- Backend: `stacks/backend/nodejs-express.md`
- Database: `stacks/database/postgresql-rds.md`
- Infra: `stacks/infra/aws-ecs-fargate.md`
- Observability: `stacks/observability/OBSERVABILITY.md`

---

### Combo 3: Edge-First *(recommended for high-traffic, global, latency-sensitive apps)*

Best for: APIs and frontends where latency matters globally; low-ops overhead; lowest cost

| Layer | Technology |
|---|---|
| **Backend** | Cloudflare Workers (TypeScript) |
| **Frontend** | React + Vite on Cloudflare Pages |
| **Database** | Cloudflare D1 (SQLite-compatible) or Supabase |
| **Infra** | Cloudflare Wrangler CLI + OpenTofu for Cloudflare resources |
| **CI/CD** | GitHub Actions + Wrangler deploy |
| **Secrets** | Cloudflare Workers Secrets |
| **Observability** | Tier 1: Cloudflare Analytics + Sentry free; Tier 2: + Grafana Cloud |

Stack guides:
- Backend: `stacks/infra/cloudflare-workers.md`
- Database: `stacks/database/supabase.md`
- Observability: `stacks/observability/OBSERVABILITY.md`

---

## Hosting Coherence Rule

Static frontends (admin SPA, marketing site) belong on the same CDN/cloud as your compute. Mixing creates egress costs and operational complexity.

| Backend on | Admin SPA should be on | Why |
|---|---|---|
| AWS (ECS/Lambda) | S3 + CloudFront | Same IAM, same VPC egress, zero cross-cloud transfer cost |
| Cloudflare Workers | Cloudflare Pages | Same platform, zero config, instant deploys |
| GCP Cloud Run | Cloud Storage + Cloud CDN | Same billing, integrated IAM |
| Vercel | Vercel (static export) | Same deployment pipeline |

**Exception**: If you want Cloudflare's DDoS protection/WAF in front of an AWS-hosted admin, put Cloudflare as DNS-only (orange cloud off) proxying to CloudFront — don't use Cloudflare Pages for the hosting itself.

---

## Layer Catalog

### Backend Options

| Option | File | Best when |
|---|---|---|
| Node.js + Express 5 | `stacks/backend/nodejs-express.md` | Default for teams with existing Express knowledge; largest ecosystem |
| Node.js + Fastify | `stacks/backend/nodejs-fastify.md` | High-throughput API, schema-first, JSON Schema validation baked in |
| Hono | `stacks/backend/hono.md` | Edge deployment needed; runtime portability (Node/Bun/Deno/CF Workers); ultra-light |
| Python + FastAPI | `stacks/backend/python-fastapi.md` | Team prefers Python, ML integration, async-first |

### Frontend Options

| Option | File | Best when |
|---|---|---|
| React + Vite + TanStack Router + shadcn/ui | `stacks/frontend/react-shadcn.md` | **Default** — admin panels, dashboards, SPAs. Type-safe routing, client-heavy apps |
| Next.js 15 App Router | `stacks/frontend/nextjs.md` | SEO matters, marketing + app in same repo, SSR needed |
| React + Vite + React Router 7 | (existing pattern) | When team already knows React Router, migration path from existing RR app |
| Vue + Nuxt | `stacks/frontend/vue-nuxt.md` | Team prefers Vue |

### Mobile Options

| Option | File | Best when |
|---|---|---|
| Flutter + Riverpod | `stacks/mobile/flutter-riverpod.md` | Default — single codebase iOS + Android |
| React Native + Expo | `stacks/mobile/react-native.md` | Team prefers JS, rapid prototyping |

### Database Options

| Option | File | Best when |
|---|---|---|
| PostgreSQL on RDS | `stacks/database/postgresql-rds.md` | Default — complex queries, ACID, full SQL |
| PlanetScale (MySQL) | `stacks/database/planetscale.md` | Serverless, branching, schema migrations |
| Supabase | `stacks/database/supabase.md` | Rapid development, realtime, auth included |

### Infrastructure Options

| Option | File | Best when |
|---|---|---|
| AWS ECS Fargate | `stacks/infra/aws-ecs-fargate.md` | Default — containerized, autoscaling |
| AWS Lambda | `stacks/infra/aws-lambda.md` | Bursty workloads, low idle cost, simple functions |
| Cloudflare Workers | `stacks/infra/cloudflare-workers.md` | Edge-first, global, ultra-low latency |

---

## Stack Constraints

Some combinations are incompatible or require extra work:

| Combination | Issue | Resolution |
|---|---|---|
| Lambda + WebSockets | Lambda doesn't support persistent connections | Use API Gateway WebSocket API or switch to ECS |
| Cloudflare Workers + PostgreSQL | Workers can't connect to RDS directly | Use Hyperdrive + connection pooler, or switch to D1/Supabase |
| Flutter + Next.js API Routes | Fine, but no separate admin panel | Add React admin as separate Cloudflare Pages project |
| PlanetScale + raw SQL patterns | PlanetScale uses MySQL syntax | Adjust all SQL patterns: `$1` → `?`, different UUID handling |
