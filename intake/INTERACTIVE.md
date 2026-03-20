# Interactive Intake System

The Orchestrator uses this to conduct the intake interview.  
This is a **conversation**, not a form dump.

---

## Rules for the Orchestrator

1. **Ask ONE group at a time** (3–4 questions max per message)
2. **After each group**: summarize what you heard, confirm before moving on
3. **Offer smart defaults** based on earlier answers  
   (e.g., if mobile=yes → suggest Flutter; if SaaS + B2B → suggest enterprise style)
4. **If an answer implies other decisions, say so**:  
   *"Since you want real-time, I'll add WebSocket support — this affects the backend stack"*
5. **At the end**: produce a complete `intake/PROJECT_BRIEF.json` before showing the plan
6. **Never proceed past a group** without human confirmation of the summary
7. **Validate JSON** against `intake/PROJECT_BRIEF.schema.json` before presenting final plan

---

## Opening Message

The Orchestrator sends this to the human at the start:

```
Hi! I'm going to ask you some questions to understand your project.
I'll ask a few at a time and summarize as we go.

This will take about 10 minutes. At the end, I'll show you a complete
project plan for your approval before generating anything.

Ready? Let's start with the basics.
```

---

## Pre-Intake: Skill Discovery

Before asking intake questions:

1. Ask the human: "In one sentence, what are you building?"
2. Extract keywords from their response (technologies, problem domains, pattern types)
3. Search ClawHub for relevant skills (see `skills/DISCOVERY.md` for process)
4. If skills found: present them, ask if they should be installed
5. Update `skills/SKILLS.md` if new skills are installed
6. Proceed to Group 1

This ensures the factory has all relevant skills before planning begins.

---

## Group 1: Identity

Ask these together:

1. What's the name of the project?
2. In one sentence, what does it do?
3. Who is it for? (target audience)

**After answers — confirm summary**:
> "So you're building **[NAME]** — [description] — for [audience]. Is that right?  
> (Say YES or correct anything)"

**Smart default logic**:
- If audience mentions "internal team" or "employees" → suggest purpose = Internal
- If audience mentions "customers" or "users" → suggest purpose = SaaS or Consumer

---

## Group 2: Scope

Ask these together:

1. What are the 5–7 core features? (list them, one per line)
2. Do you need: **a)** admin dashboard, **b)** mobile app, **c)** user auth?
3. Any real-time features? (live updates, push notifications, chat)
4. File uploads? (images, documents, videos, etc.)

**After answers — confirm summary + flag implications**:

> "You need: [features listed]. Let me note some implications:
>
> - Auth required → JWT + refresh token flow included
> - Mobile app → Flutter + Riverpod (can override in Group 4)
> - Admin dashboard → React + shadcn/ui (can override in Group 4)
> - Real-time → WebSocket layer added to backend (increases complexity slightly)
> - File uploads → S3 bucket + presigned URL pattern included
>
> Does this look right?"

**Smart default logic**:
- mobile_app = true → pre-fill stack.mobile = "flutter-riverpod"
- admin_dashboard = true → pre-fill stack.frontend = "react-shadcn"
- realtime = true → add note to backend plan (WebSocket support)
- file_uploads = true → add S3 to infra plan

---

## Group 3: UI & Design

Ask these together:

1. Do you have a Figma file? (paste the URL if yes, or say "no")
2. If no Figma — pick a style (type the letter):
   - **a)** Clean/minimal (like Linear, Notion)
   - **b)** Bold/vibrant (like Duolingo, Headspace)
   - **c)** Enterprise/professional (like Salesforce, Jira)
   - **d)** Dark/modern (like Vercel, GitHub)
   - **e)** Custom — describe it
3. Brand colors? (primary hex like `#6366F1`, or just a vibe like "blue and white")
4. Dark mode: **required** / **optional** / **not needed**

**After answers — show design token preview**:

> "Here's what your design system will look like:
>
> **Primary**: #[color] ([name])  
> **Style**: [chosen style]  
> **Dark mode**: [required/optional/none]  
>
> Does this match your vision? (YES or adjust)"

**Style → color defaults** (if user gives a vibe, not a hex):
| Style | Default Primary | Default Secondary |
|---|---|---|
| minimal | #18181B (Zinc 900) | #71717A (Zinc 500) |
| bold | #F97316 (Orange 500) | #EC4899 (Pink 500) |
| enterprise | #1E40AF (Blue 800) | #1D4ED8 (Blue 700) |
| dark | #6366F1 (Indigo 500) | #8B5CF6 (Violet 500) |

**Figma handling**:
- If Figma URL provided → extract file key (last segment after `/file/` or `/design/`)
- Set figma_file_key in JSON
- Note: design tokens will be extracted from Figma in Phase 1 of GENERATION.md

---

## Group 4: Technical Preferences

Ask these together:

1. Backend language preference: **Node.js** / **Python** / **No preference**
2. Database: **PostgreSQL** / **MySQL** / **MongoDB** / **No preference**
3. Cloud provider: **AWS** / **GCP** / **Azure** / **Cloudflare** / **No preference**
4. Hosting scale: **MVP** (minimal cost) / **Growth** (moderate) / **Enterprise** (high-availability)

**After answers — recommend stack and explain**:

> "Based on your answers, I recommend:
>
> - **Backend**: [nodejs-express | nodejs-fastify | python-fastapi]  
> - **Database**: [postgresql-rds | planetscale | supabase]  
> - **Infra**: [aws-ecs-fargate | aws-lambda | cloudflare-workers]
>
> Why: [2–3 sentence rationale]
>
> Does this work for you? (YES or tell me what to change)"

**Recommendation logic**:
| User answers | Recommended infra |
|---|---|
| AWS + MVP | aws-ecs-fargate (scale-to-zero possible) |
| AWS + Growth/Enterprise | aws-ecs-fargate (auto-scaling) |
| Cloudflare preference | cloudflare-workers |
| No preference + low scale | aws-lambda |
| No preference + medium/high | aws-ecs-fargate |

| User answers | Recommended database |
|---|---|
| PostgreSQL preference | postgresql-rds |
| MySQL preference | planetscale |
| No preference + Supabase-friendly | supabase |
| No preference + default | postgresql-rds |

---

## Group 5: Infrastructure

Ask these together:

1. What domain name do you own? (e.g., `myapp.com`)
2. What should the API subdomain be? (default: `api`)
3. Admin dashboard subdomain? (default: `admin`)
4. AWS region preference? (default: `us-east-1` — lowest latency for global traffic)

**After answers — confirm**:

> "Got it. Your app will be live at:
>
> - API: **https://[api_subdomain].[domain]**
> - Admin: **https://[admin_subdomain].[domain]**
> - Region: **[region]**
>
> Correct?"

---

## Final Summary

After all 5 groups are confirmed:

1. Generate `intake/PROJECT_BRIEF.json` (see schema below)
2. Validate against `intake/PROJECT_BRIEF.schema.json`
3. Show the human a formatted plan:

```
Here's your complete project plan:

PROJECT: [Name] ([slug])
PURPOSE: [SaaS | Consumer | Internal | ...]
AUDIENCE: [description]

FEATURES:
  ✓ [feature 1]
  ✓ [feature 2]
  ...
  ✓ Auth: [yes/no]
  ✓ Admin dashboard: [yes/no]
  ✓ Mobile app: [yes/no]
  ✓ Real-time: [yes/no]
  ✓ File uploads: [yes/no]

DESIGN:
  Style: [style]
  Primary color: [hex]
  Dark mode: [required/optional/none]
  Figma: [URL or "none"]

STACK:
  Backend: [stack name]
  Frontend: [stack name]
  Mobile: [stack name or "none"]
  Database: [stack name]
  Infrastructure: [stack name]

INFRASTRUCTURE:
  Domain: [domain]
  API: https://[api_subdomain].[domain]
  Admin: https://[admin_subdomain].[domain]
  Region: [region]
  Scale: [mvp/growth/enterprise]

---
Does this look right? Type YES to proceed or tell me what to change.
```

4. On human confirmation → set `"approved": true` in PROJECT_BRIEF.json
5. Save file to `intake/PROJECT_BRIEF.json`
6. Proceed to `workflows/GENERATION.md`

---

## PROJECT_BRIEF.json Format

```json
{
  "project": {
    "name": "string",
    "slug": "lowercase-hyphen",
    "description": "one sentence",
    "purpose": "SaaS | Consumer | Internal | API | Marketplace | Content | Other",
    "audience": "string",
    "language": "en"
  },
  "features": {
    "core": ["feature1", "feature2", "feature3"],
    "auth": true,
    "admin_dashboard": true,
    "mobile_app": true,
    "mobile_platforms": "ios+android | ios | android | none",
    "realtime": false,
    "file_uploads": false,
    "roles": ["user", "admin"]
  },
  "design": {
    "figma_url": "https://www.figma.com/file/... | null",
    "figma_file_key": "AbCdEfGhIjKl | null",
    "style": "minimal | bold | enterprise | dark | custom",
    "colors": {
      "primary": "#6366F1",
      "secondary": "#8B5CF6",
      "accent": "#F59E0B"
    },
    "dark_mode": "required | optional | none",
    "typography": "inter | system | custom"
  },
  "stack": {
    "backend": "nodejs-express | nodejs-fastify | python-fastapi",
    "frontend": "react-shadcn | nextjs | vue-nuxt",
    "mobile": "flutter-riverpod | react-native | none",
    "database": "postgresql-rds | planetscale | supabase",
    "infra": "aws-ecs-fargate | aws-lambda | cloudflare-workers"
  },
  "infra": {
    "domain": "example.com",
    "api_subdomain": "api",
    "admin_subdomain": "admin",
    "region": "us-east-1",
    "scale": "mvp | growth | enterprise"
  },
  "approved": false
}
```

**Set `"approved": true` only after the human explicitly types YES or equivalent confirmation.**

---

## Implication Reference

When a feature is selected, automatically add these to the project:

| Feature | Implication |
|---|---|
| auth = true | JWT + refresh tokens; bcrypt password hashing; /api/auth/* routes |
| admin_dashboard = true | React + shadcn stack; admin-only role guard on API |
| mobile_app = true | Flutter + Riverpod stack; flutter_secure_storage for tokens |
| realtime = true | WebSocket layer on backend; Flutter StreamProvider; React useWebSocket |
| file_uploads = true | S3 bucket in infra; presigned URL endpoint on backend; multipart form handling |
| scale = enterprise | Multi-AZ RDS; ECS auto-scaling; CloudFront; WAF recommended |
