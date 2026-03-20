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

## ⚠️ Factory Edit Warning

**This factory is a tightly coupled system.** Before editing ANY file:

1. **Scan ALL files first** — understand the full structure
2. **Search for references** — find everywhere the thing you're changing is mentioned
3. **Update ALL affected files** — not just the one you intended to change

Adding an agent? Update: ROSTER.md, PHILOSOPHY.md, GENERATION.md, ORCHESTRATOR.md, README.md.
Adding a phase? Update: GENERATION.md, every file referencing phase numbers.
Adding a file? Update: README.md layout, any index files.

See `PHILOSOPHY.md` principle 11 for the full checklist.

---

## Quick Start (For AI Agents)

If you are an AI agent reading this:

1. Read `PHILOSOPHY.md` — internalize all principles before doing **anything**
2. Run `updater/PREFLIGHT.md` — mandatory pre-session checklist (takes 2 minutes)
3. Read `agents/LIMITS.md` — rate limits, token budgets, task sizing rules
4. Read `intake/INTAKE.md` + `intake/INTERACTIVE.md` — understand the onboarding process
5. Read `agents/ROSTER.md` — understand your role and others'
6. Read `agents/ORCHESTRATOR.md` or `agents/IMPLEMENTER.md` depending on your role
7. Execute the workflow in `workflows/GENERATION.md`

Do not skip steps 1–3. Preflight ensures the factory is current. LIMITS.md prevents token waste.

**If editing the factory itself**: Read principle 11 in PHILOSOPHY.md first. Scan all files before making changes.

## Quick Start (For Humans)

1. Fill in `intake/ACCESS.md` with your credentials
2. Tell an AI agent (Claude/Watson): *"Start a new project using the AI Project Factory"*
3. The agent runs a **preflight check** (automatic, ~2 min)
4. The agent conducts the **interactive intake** — conversational, group-by-group questions
5. You approve the generated `PROJECT_BRIEF.json` plan
6. Wait ~2 hours for a deployed, working application

The intake is now conversational: the agent asks 3–4 questions at a time, summarizes after each group, and only proceeds when you confirm. No more long forms to fill out up front.

## What Gets Generated

- **Backend API**: Node.js/Express 5 (or Fastify/FastAPI) — containerized on ECS Fargate
- **Admin panel**: React 19 + Vite + TailwindCSS 4 + shadcn/ui — deployed on AWS S3 + CloudFront (within AWS stack) or Cloudflare Pages (within Cloudflare/Edge stack)
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
├── PHILOSOPHY.md               ← Start here (agents)
├── brain/                      ← Cross-project learning system
│   ├── BRAIN.md                ← How the brain works
│   ├── patterns/               ← Battle-tested solutions by problem type
│   ├── lessons/                ← Post-project learnings
│   ├── metrics/                ← Success tracking (registry.json)
│   └── improvements/           ← Factory improvement queue
├── updater/                    ← Self-maintenance system
│   ├── PREFLIGHT.md            ← Run before every session
│   ├── UPDATER.md              ← Weekly version check process
│   ├── AUTO_UPDATE.md          ← Patch/minor/major update rules
│   ├── tests/                  ← Stack regression tests
│   └── update.yml              ← GitHub Actions: weekly automated check
├── intake/                     ← Onboarding new projects
│   ├── INTERACTIVE.md          ← Conversational intake protocol (primary)
│   ├── ACCESS.md               ← Credentials template
│   ├── ACCESS_VALIDATION.md    ← Deep credential verification
│   └── PROJECT_BRIEF.schema.json ← JSON schema for validating intake output
├── agents/                     ← Role cards for each agent type
│   ├── ROSTER.md               ← All agents, models, parallel execution
│   ├── LIMITS.md               ← Rate limits, token budgets, model selection
│   ├── ORCHESTRATOR.md
│   ├── IMPLEMENTER.md
│   ├── REVIEWER.md
│   ├── TEST.md                 ← Test Agent role card
│   ├── INFRA.md
│   └── PIPELINE.md             ← Handoff protocol and file formats
├── stacks/                     ← Stack patterns and options
│   └── observability/          ← Monitoring integration
├── skills/                     ← Deep technical guides per tool
│   ├── DISCOVERY.md            ← How to find new skills
│   └── SKILLS.md               ← Master skill index
├── security/                   ← Security checklists and patterns
├── workflows/                  ← End-to-end process flows
│   ├── GENERATION.md           ← Master 7-phase workflow
│   ├── RECOVERY.md             ← Disaster recovery procedures
│   └── POST_HANDOFF.md         ← Optional health monitoring
└── templates/                  ← Files agents fill in
```

## Design Principle

This factory is built on one insight: **AI agents fail when they guess**. Every file in this repo exists to eliminate guessing — by telling agents exactly what pattern to use, what to verify, when to stop and ask, and what done looks like.

The result is consistent, production-quality output regardless of which AI model runs the generation.
