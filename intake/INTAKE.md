# Intake Process — How to Onboard a New Project

This document is the Orchestrator's guide for onboarding a new project. Follow every phase in order. Do not skip phases. Do not parallelize phases within intake.

---

## Overview

```
Phase 0: Credential Validation   ← NOTHING happens until this passes
Phase 1: Project Brief (Q&A)     ← Interactive, grouped questions
Phase 2: Stack Selection         ← Auto-recommend or human chooses
Phase 3: Project Plan            ← Orchestrator generates, human approves
Phase 4: Hand off to Generation  ← Execute workflows/GENERATION.md
```

---

## Phase 0: Credential Validation

**Before asking a single intake question**, validate credentials.

### Step 0.1 — Request credentials

Say to the human:

> "Before we start, please fill in `intake/ACCESS.md` with your credentials. This includes GitHub, AWS, Cloudflare, and your domain. When you're ready, tell me and I'll validate everything."

Wait for confirmation.

### Step 0.2 — Run validation checks

Read `intake/ACCESS.md` and run each validation command listed per service.

**GitHub**:
```bash
gh auth status
gh repo list --limit 1
```
Expected: No auth errors, at least one repo listed.

**AWS**:
```bash
aws sts get-caller-identity
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'UserName' --output text) 2>/dev/null || echo "Using role"
```
Expected: JSON with Account, UserId, Arn.

Then check service access:
```bash
aws ecr describe-repositories --max-items 1 2>&1 | grep -v "Error\|Exception" && echo "ECR: OK" || echo "ECR: FAILED"
aws ecs list-clusters --max-items 1 2>&1 | grep -v "Error\|Exception" && echo "ECS: OK" || echo "ECS: FAILED"
aws rds describe-db-instances --max-records 20 2>&1 | grep -v "Error\|Exception" && echo "RDS: OK" || echo "RDS: FAILED"
aws secretsmanager list-secrets --max-results 1 2>&1 | grep -v "Error\|Exception" && echo "SecretsManager: OK" || echo "SecretsManager: FAILED"
```

**Cloudflare**:
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" | jq '.success'
```
Expected: `true`

**Figma** (if provided):
```bash
curl -s -X GET "https://api.figma.com/v1/files/${FIGMA_FILE_KEY}" \
  -H "X-Figma-Token: ${FIGMA_TOKEN}" | jq '.name'
```
Expected: File name (not error).

### Step 0.3 — Report results

Fill in the Validation Results table in ACCESS.md. Report to human:

```
✅ GitHub — authenticated as @username
✅ AWS — account 123456789, region us-east-1
✅ ECR, ECS, RDS, SecretsManager — all accessible
✅ Cloudflare — zone example.com verified
❌ Figma — token invalid or file not found

Required services: all pass.
Optional: Figma failed. You can provide a corrected token, or I'll generate the design system from your description.
```

### Step 0.4 — Decision

- All **required** services pass → proceed to Phase 1
- Any **required** service fails → STOP. List exactly what's needed. Do not proceed.
- **Optional** services fail → note it, ask if they want to fix or skip

---

## Phase 1: Project Brief (Interactive Q&A)

Questions are in `intake/QUESTIONS.md`. Do NOT dump them all at once.

### Pacing rules

- Ask **3–4 questions per message**, grouped by category
- After each group, **summarize what you heard** and confirm before moving on
- Use conversational language, not a form
- If an answer implies another answer (e.g., "no mobile app" means skip mobile questions), skip those questions

### Question order

**Group 1 — Identity** (Q-001 through Q-005):
> "Let's start with the basics. What's the project called? What does it do in one sentence? Who is it for?"

**Group 2 — Features** (Q-010 through Q-017):
> "Now let's define scope. What are the core features? Do you need an admin dashboard? Mobile app? Authentication with roles?"

**Group 3 — UI** (Q-020 through Q-027):
> "How should it look? Do you have a Figma file, a color palette, or a design reference? Or should I generate a design system from your description?"

**Group 4 — Stack** (Q-030 through Q-035) — *often auto-decided*:
> "I can recommend a stack based on your answers, or you can specify. Want me to recommend?"

**Group 5 — Infra** (Q-040 through Q-045):
> "A few infrastructure questions: which AWS region, what scale are you planning for, and what's your budget tier?"

**Group 6 — Domain** (Q-050 through Q-055):
> "Finally: what's your domain name? What subdomains do you want for the API, admin, and app?"

### Confirmation step

After all groups, produce a summary:

```
Here's what I captured:

**Project**: HabitTracker
**Purpose**: Habit tracking app for individuals
**Features**: Habits CRUD, streak tracking, push notifications, admin dashboard, iOS + Android mobile app
**Auth**: Email + password, two roles (user / admin)
**Design**: Figma file provided (key: abc123)
**Stack**: Flutter + Node.js/Express + React/shadcn + PostgreSQL + ECS Fargate
**Region**: us-east-1
**Scale**: MVP
**Domain**: habittracker.com — api.habittracker.com, admin.habittracker.com

Does this look right? Any corrections?
```

Only proceed when human says yes (or corrects and you confirm corrections).

---

## Phase 2: Stack Selection

If human specified a stack → validate it against `stacks/STACKS.md`.  
If human said "recommend" or didn't specify → use the decision matrix in `stacks/STACKS.md`.

Document the selection with reasoning:

```
**Selected stack**: Full-stack Mobile combo
- Backend: Node.js + Express 5 + ESM + Zod
- Admin: React 19 + Vite + TailwindCSS 4 + shadcn/ui → Cloudflare Pages
- Mobile: Flutter 3.x + Riverpod 2 + go_router 14
- Database: PostgreSQL 16 on AWS RDS
- Infra: ECS Fargate + ECR + ALB + CloudFront
- DNS/CDN: Cloudflare

Reasoning: Mobile app is required, admin dashboard is required, persistent API needed (not serverless), complex relational data (habits, streaks, users → PostgreSQL).
```

If human wants a different stack, validate it's in `stacks/STACKS.md`. If not, note the gap and ask if they want to proceed with the closest match.

---

## Phase 3: Project Plan

Generate `PROJECT.md` using `templates/PROJECT.template.md`. Fill in all fields.

Present it to the human. Specifically highlight:
- The timeline estimate
- Any technical risks or unknowns
- What permissions/access will be used

**Explicit approval required**:
> "Here's the full project plan. Please review it, then say 'approved' to start generation, or let me know what to change."

Do NOT start generation until you receive explicit approval.

---

## Phase 4: Hand Off to Generation

Once approved:

1. Save `PROJECT.md` to the project root (the human's new project repo, not this factory repo)
2. Execute `workflows/GENERATION.md` from Phase 0

The intake process is complete.

---

## Anti-Patterns to Avoid

- ❌ Starting generation before credential validation
- ❌ Asking all questions in one giant message
- ❌ Proceeding after a human says "looks fine" without a clear summary to confirm
- ❌ Auto-selecting a stack without explaining why
- ❌ Skipping the plan approval step because the human seems eager
- ❌ Proceeding if a required service fails validation
