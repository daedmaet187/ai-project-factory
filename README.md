# AI Project Factory

A multi-agent system for generating production-ready full-stack projects from a human brief.

## What This Is

Not a starter kit. Not a boilerplate. A **factory** — a set of agent instructions, intake processes, and stack patterns that AI agents use to generate complete projects autonomously.

You give it a brief and credentials. It gives you a deployed, production-ready application with CI/CD, secrets management, and infrastructure already running.

## How It Works

1. Human answers intake questions (`intake/QUESTIONS.md`)
2. Human fills access credentials (`intake/ACCESS.md`)
3. Orchestrator agent validates access, selects stack
4. Agents generate project in parallel by layer
5. Reviewer agent validates before final commit
6. Human receives working repo with CI/CD, deployed infrastructure

## Quick Start (For AI Agents)

If you are an AI agent reading this:

1. Read `PHILOSOPHY.md` — internalize all principles before doing **anything**
2. Read `intake/INTAKE.md` — understand the onboarding process
3. Read `agents/ROSTER.md` — understand your role and others'
4. Read `agents/ORCHESTRATOR.md` or `agents/IMPLEMENTER.md` depending on your role
5. Execute the workflow in `workflows/GENERATION.md`

Do not skip step 1. The principles in PHILOSOPHY.md govern every decision you make.

## Quick Start (For Humans)

1. Fill in `intake/ACCESS.md` with your credentials
2. Tell an AI agent (Claude/Watson): *"Start a new project using the AI Project Factory"*
3. The AI will walk you through `intake/QUESTIONS.md` interactively
4. Approve the generated plan
5. Wait ~2 hours for a deployed, working application

## What Gets Generated

- **Backend API**: Node.js/Express 5 (or Fastify/FastAPI) — containerized on ECS Fargate
- **Admin panel**: React 19 + Vite + TailwindCSS 4 + shadcn/ui — deployed on Cloudflare Pages
- **Mobile app**: Flutter + Riverpod + go_router — ready for iOS/Android distribution
- **Infrastructure**: PostgreSQL on RDS, ECS Fargate, ECR, ALB, CloudFront, all via OpenTofu
- **CI/CD**: GitHub Actions for all layers — build, test, deploy on push
- **Security**: Secrets in AWS Secrets Manager, rate limiting, input validation, JWT auth

## Stack Options

See `stacks/STACKS.md` for all available combinations. Three pre-built combos:

| Combo | Best for |
|---|---|
| Full-stack Mobile | Mobile-first apps with web admin |
| Web-only SaaS | B2B tools, dashboards, SaaS products |
| Edge-first | High-traffic, low-latency global apps |

## Repository Layout

```
ai-project-factory/
├── PHILOSOPHY.md           ← Start here (agents)
├── intake/                 ← Onboarding new projects
├── agents/                 ← Role cards for each agent type
├── stacks/                 ← Stack patterns and options
├── skills/                 ← Deep technical guides per tool
├── security/               ← Security checklists and patterns
├── workflows/              ← End-to-end process flows
└── templates/              ← Files agents fill in
```

## Design Principle

This factory is built on one insight: **AI agents fail when they guess**. Every file in this repo exists to eliminate guessing — by telling agents exactly what pattern to use, what to verify, when to stop and ask, and what done looks like.

The result is consistent, production-quality output regardless of which AI model runs the generation.
