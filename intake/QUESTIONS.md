# Question Bank — Full Intake Question Set

These questions are used by the Orchestrator during Phase 1 of intake. Do not ask them all at once. See `INTAKE.md` for pacing rules.

Each question includes full context so the agent knows why it's asking and what to do with the answer.

---

## Category: Identity

### Q-001: What is the project name?
**Category**: Identity  
**Required**: Yes  
**Default**: None  
**Why asked**: Used in repo name, domain names, app bundle IDs, service names, and all generated code.  
**Impact**: Sets `project_name` and `project_slug` (lowercase-hyphen version) used throughout all generated files.

---

### Q-002: Describe the project in one sentence.
**Category**: Identity  
**Required**: Yes  
**Default**: None  
**Why asked**: Used in README, App Store descriptions, and to validate that later answers are consistent with the stated purpose.  
**Impact**: Populates project descriptions across all layers.

---

### Q-003: What is the primary purpose of this product?
**Category**: Identity  
**Required**: Yes  
**Default**: None  
**Options**: SaaS tool / Consumer app / Internal tool / API / Marketplace / Content platform / Other  
**Why asked**: Determines whether the product needs user-facing marketing, admin-heavy management, or purely API-level access.  
**Impact**: Influences which layers are prioritized, whether SEO matters (Next.js vs SPA), and whether a mobile app is expected.

---

### Q-004: Who is the target audience?
**Category**: Identity  
**Required**: Yes  
**Default**: None  
**Why asked**: Determines UX expectations (consumer vs enterprise), accessibility requirements, and localization needs.  
**Impact**: Affects UI choices, onboarding flow complexity, and whether WCAG compliance is needed.

---

### Q-005: What is the primary language of your users?
**Category**: Identity  
**Required**: No  
**Default**: English  
**Why asked**: Determines if i18n setup is needed from day one or can be deferred.  
**Impact**: If non-English: adds `i18next` to backend, `flutter_localizations` to mobile, RTL considerations to admin.

---

## Category: Features

### Q-010: What are the core features? List the top 5–7 things the app must do.
**Category**: Features  
**Required**: Yes  
**Default**: None  
**Why asked**: Drives the data model, API endpoint list, and which features go in Phase 5 vs later.  
**Impact**: Directly determines database schema, API routes generated, and mobile/admin screens.

---

### Q-011: Does the project need an admin dashboard?
**Category**: Features  
**Required**: Yes  
**Default**: Yes  
**Options**: Yes / No / Later (not in v1)  
**Why asked**: Determines whether the React/shadcn admin layer is generated.  
**Impact**: If yes: admin React app is generated in Phase 5. If no: saves ~45 min of generation.

---

### Q-012: Does the project need a mobile app?
**Category**: Features  
**Required**: Yes  
**Default**: Yes  
**Options**: iOS + Android / iOS only / Android only / No  
**Why asked**: Determines whether the Flutter layer is generated.  
**Impact**: If yes: Flutter app generated in Phase 5. Affects Phase 2 (Figma ingestion for mobile). If no: skips mobile entirely.

---

### Q-013: Does the project require user authentication?
**Category**: Features  
**Required**: Yes  
**Default**: Yes  
**Options**: Yes / No  
**Why asked**: Almost every app needs auth, but some APIs do not. Skipping auth changes backend structure significantly.  
**Impact**: If yes: JWT auth system generated with login/register/refresh endpoints. If no: all routes are public (flag for security review).

---

### Q-014: What user roles are needed?
**Category**: Features  
**Required**: Yes (if Q-013 = Yes)  
**Default**: user, admin  
**Why asked**: Determines authorization middleware patterns and role-based access control (RBAC) setup.  
**Impact**: Sets roles enum in DB, generates role-checking middleware, determines admin panel access logic.

---

### Q-015: Are real-time features needed?
**Category**: Features  
**Required**: No  
**Default**: No  
**Options**: WebSockets / Server-Sent Events / Long polling / No  
**Why asked**: WebSockets require significant infrastructure changes (sticky sessions on ALB, or separate WS service).  
**Impact**: If yes: adds Socket.io or WS setup to backend, real-time client patterns to mobile/admin. Infra changes required.

---

### Q-016: Are file uploads needed?
**Category**: Features  
**Required**: No  
**Default**: No  
**Options**: Yes (images) / Yes (documents) / Yes (any type) / No  
**Why asked**: File uploads require S3 bucket, pre-signed URL generation, and file validation middleware.  
**Impact**: If yes: S3 bucket in infra, upload endpoint with MIME validation, Flutter image picker, admin file uploader.

---

### Q-017: Are third-party integrations needed?
**Category**: Features  
**Required**: No  
**Default**: None  
**Examples**: Stripe (payments), SendGrid (email), Twilio (SMS), Firebase (push notifications), Segment (analytics)  
**Why asked**: Integrations require secrets, additional SDK setup, and sometimes infra changes.  
**Impact**: Each integration adds secrets to Secrets Manager and SDK setup to the relevant layer.

---

## Category: UI

### Q-020: Do you have a Figma file for the design?
**Category**: UI  
**Required**: No  
**Default**: No  
**Why asked**: If yes, design tokens (colors, typography, spacing) are extracted automatically. This is the highest-quality design input.  
**Impact**: If yes: UI Agent runs Phase 2 with Figma MCP. Provides `FIGMA_FILE_KEY` for ACCESS.md. All layers use extracted tokens.

---

### Q-021: Do you have a specific shadcn/ui theme or color palette?
**Category**: UI  
**Required**: No  
**Default**: Auto-generated  
**Options**: shadcn theme URL / hex color palette / style description / none  
**Why asked**: Lets the admin/web layer match exact brand colors even without Figma.  
**Impact**: If provided: CSS variables set to exact colors. If not: UI Agent generates palette from Q-022/Q-023 description.

---

### Q-022: What are your brand colors?
**Category**: UI  
**Required**: No  
**Default**: UI Agent generates from Q-023  
**Format**: Primary hex, secondary hex, accent hex (e.g., `#6366F1, #8B5CF6, #F59E0B`)  
**Why asked**: Brand colors are applied to all layers — mobile ThemeData, admin TailwindCSS variables, landing page.  
**Impact**: Sets the design token color values used by all generated code.

---

### Q-023: Describe the visual style of the product.
**Category**: UI  
**Required**: No (unless Q-020, Q-021, Q-022 all skipped)  
**Default**: "Clean, minimal, modern"  
**Examples**: "Bold and dark, high contrast" / "Soft pastel, friendly, consumer" / "Professional, enterprise, data-dense" / "Playful, colorful, mobile-first"  
**Why asked**: If no Figma or palette provided, this description drives UI Agent's design system generation.  
**Impact**: Determines color palette, font choice, border radius style, component density.

---

### Q-024: What typography style do you prefer?
**Category**: UI  
**Required**: No  
**Default**: Inter (modern, readable)  
**Options**: Inter / Geist / DM Sans / Outfit / System default  
**Why asked**: Font family is set in both Flutter ThemeData and TailwindCSS config. Changing it later requires touching all layers.  
**Impact**: Sets font family across all layers.

---

### Q-025: Is dark mode required?
**Category**: UI  
**Required**: No  
**Default**: Optional (system-default)  
**Options**: Required (always supported) / Optional (system-default) / Light only  
**Why asked**: Dark mode requires double the CSS custom properties in Tailwind and a Flutter dark theme. Non-trivial to retrofit.  
**Impact**: If required: generates full dark mode theme for both mobile and admin. If light only: simpler but harder to add later.

---

## Category: Stack

### Q-030: What backend language do you prefer?
**Category**: Stack  
**Required**: No  
**Default**: Auto-recommend based on features  
**Options**: Node.js / Python / Go  
**Why asked**: Backend language determines which stack pattern is used from `stacks/backend/`.  
**Impact**: Node.js → Express 5 or Fastify. Python → FastAPI. Go → not yet in stack catalog (write ADR).

---

### Q-031: What database do you prefer?
**Category**: Stack  
**Required**: No  
**Default**: PostgreSQL (recommended for most projects)  
**Options**: PostgreSQL / MySQL (PlanetScale) / Supabase (managed PostgreSQL)  
**Why asked**: Database choice affects infra (RDS vs PlanetScale vs Supabase), migration tooling, and raw query patterns.  
**Impact**: Determines which `stacks/database/` pattern is followed.

---

### Q-032: What hosting preference do you have?
**Category**: Stack  
**Required**: No  
**Default**: AWS  
**Options**: AWS / Cloudflare (edge-first) / GCP / Azure  
**Why asked**: Hosting preference determines the infra stack used.  
**Impact**: AWS → ECS Fargate or Lambda. Cloudflare → Workers + Pages. Non-AWS means no ECS/RDS patterns — custom ADR needed.

---

### Q-033: What mobile platforms are you targeting?
**Category**: Stack  
**Required**: Yes (if Q-012 = Yes)  
**Default**: iOS + Android  
**Options**: iOS + Android / iOS only / Android only / Web only (PWA)  
**Why asked**: Determines Flutter build targets and CI/CD matrix.  
**Impact**: iOS only: Apple credentials needed. Android only: Google Play service account needed. Both: need both.

---

## Category: Infrastructure

### Q-040: What AWS region should the project deploy to?
**Category**: Infra  
**Required**: Yes (if hosting = AWS)  
**Default**: us-east-1  
**Why asked**: All AWS resources (ECS, RDS, ECR, ALB, SecretsManager) are region-specific. Changing region post-deploy requires re-creating everything.  
**Impact**: Sets `aws_region` variable across all OpenTofu modules.

---

### Q-041: What is the expected scale at launch?
**Category**: Infra  
**Required**: Yes  
**Default**: MVP  
**Options**: MVP (< 1000 users) / Growth (1k–100k users) / Enterprise (100k+ users)  
**Why asked**: Determines ECS task sizing, RDS instance class, ALB configuration, and CloudFront caching.  
**Impact**: MVP → smallest instances (cost-optimized). Growth → medium instances. Enterprise → multi-AZ, read replicas, larger instances.

---

### Q-042: What budget tier are you targeting?
**Category**: Infra  
**Required**: No  
**Default**: Minimal  
**Options**: Minimal ($50–150/mo) / Standard ($150–500/mo) / Production ($500+/mo)  
**Why asked**: Budget constraints override scale recommendations. A growth-scale project on minimal budget needs explicit trade-offs documented.  
**Impact**: If budget conflicts with scale: Orchestrator raises this with human before proceeding.

---

### Q-INF-020: What monitoring tier do you want?
**Category**: Infra
**Required**: No
**Default**: Tier 1 (free, CloudWatch + Sentry free + Firebase)
**Options**: Tier 1 (MVP/free) / Tier 2 (Grafana Cloud ~$30/month) / Tier 3 (Datadog $46+/host/month)
**Why asked**: Sets up the right observability stack from day one
**Impact**: Determines which monitoring infrastructure gets generated. Tier 1 → CloudWatch alarms + Sentry free + Firebase Crashlytics. Tier 2 → adds Grafana Cloud LGTM stack + OTel tracing. Tier 3 → Datadog full platform.

---

### Q-INF-021: Alert email address?
**Category**: Infra
**Required**: Yes
**Default**: None
**Why asked**: CloudWatch alarms need an SNS subscription email to notify on incidents
**Impact**: Populates `alert_email` variable in OpenTofu. Used for 5xx rate alarms, CPU alarms, and RDS storage alarms.

---

### Q-043: Do you want a staging environment?
**Category**: Infra  
**Required**: No  
**Default**: No (MVP) / Yes (Growth, Production)  
**Options**: Yes / No  
**Why asked**: Staging environment doubles infra costs but enables safe deployments.  
**Impact**: If yes: OpenTofu workspaces used for staging/production. GitHub Actions deploys to staging on PR, production on main merge.

---

## Category: Domain

### Q-050: What is your domain name?
**Category**: Domain  
**Required**: Yes  
**Default**: None  
**Why asked**: Domain must already be registered and have Cloudflare as its DNS provider.  
**Impact**: Sets `domain_name` used in all DNS records, TLS certificates (ACM), and CORS configuration.

---

### Q-051: What subdomain should the API use?
**Category**: Domain  
**Required**: No  
**Default**: `api`  
**Why asked**: The API subdomain receives DNS CNAME pointing to the ALB. Used in all mobile/admin API base URLs.  
**Impact**: Sets `api_subdomain`. API will be at `{api_subdomain}.{domain}`.

---

### Q-052: What subdomain should the admin panel use?
**Category**: Domain  
**Required**: No (only if admin = yes)  
**Default**: `admin`  
**Why asked**: Admin subdomain served by Cloudflare Pages. Needs DNS CNAME record.  
**Impact**: Sets `admin_subdomain`. Admin at `{admin_subdomain}.{domain}`.

---

### Q-053: What subdomain should the mobile app backend use?
**Category**: Domain  
**Required**: No (only if mobile = yes)  
**Default**: `app`  
**Why asked**: Mobile apps point to a specific API URL baked into build configuration. Changing it later requires a new app release.  
**Impact**: Sets `app_subdomain`. Mobile app uses `{app_subdomain}.{domain}` as its API base URL.

---

### Q-054: Is the domain already using Cloudflare as its DNS provider?
**Category**: Domain  
**Required**: Yes  
**Default**: Assumed yes (required)  
**Why asked**: Cloudflare DNS is required for CNAME flattening, Page Rules, and Cloudflare Pages deployment.  
**Impact**: If no: Orchestrator explains the nameserver change process and waits for confirmation before proceeding.

---

### Q-055: Do you want a www redirect?
**Category**: Domain  
**Required**: No  
**Default**: Yes (www → apex or apex → www)  
**Options**: www → apex / apex → www / No redirect  
**Why asked**: Prevents duplicate content and ensures consistent canonical URLs.  
**Impact**: Adds Cloudflare redirect rule in infra.
