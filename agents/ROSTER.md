# Agent Roster

All agents involved in project generation, their roles, when they're spawned, and how they communicate.

---

## Agent Types

| Agent | Model | Role | When spawned |
|---|---|---|---|
| **Orchestrator** | Claude (Watson) | Planning, coordination, memory, GitHub ops | Always — root session |
| **Implementer** | Codex / GPT-4o | Code writing, file edits, execution | For any implementation task |
| **Reviewer** | Claude | Code review, security audit, pattern validation | After each implementation phase |
| **Infra Agent** | Codex | OpenTofu-only infrastructure changes | When infra modules need changes |
| **UI Agent** | Claude | Design token extraction, component scaffolding | When Figma/design provided |

---

## Role Boundaries

These boundaries are strict. Role violations cause inconsistency.

```
Orchestrator  → Plans, coordinates, never implements
Implementer   → Implements, never architects
Reviewer      → Reviews, never implements
Infra Agent   → Infrastructure only, never app code
UI Agent      → Design system only, no business logic
```

---

## Parallel Execution Model

Independent layers are always parallelized. The Orchestrator spawns them simultaneously.

```
Orchestrator
    │
    ├── [Phase 2] UI Agent (design tokens) ─────────────────────────┐
    │                                                                 │ blocks
    ├── [Phase 4] Infra Agent (tofu apply) ────────────────────────┐ │
    │                                                                │ │
    │   AFTER Phase 2 and 4 complete:                               ▼ ▼
    │
    ├── [Phase 5, parallel]:
    │   ├── spawns → Implementer (backend)   ─┐
    │   ├── spawns → Implementer (admin)      ├── all three in parallel
    │   └── spawns → Implementer (mobile)    ─┘
    │
    │   AFTER all Phase 5 complete:
    │
    └── [Phase 6] Reviewer Agent ──────────────────────────────────────►
```

**What can run in parallel**: Backend + admin + mobile implementation  
**What cannot**: Design tokens before implementation; infra before design tokens are known; review after all implementation

---

## Agent Communication Protocol

Agents do not communicate directly. All communication goes through files.

```
1. Orchestrator writes plan → plans/[task-name].plan.md
2. Orchestrator spawns Implementer with: "Read plans/[task-name].plan.md and execute it"
3. Implementer executes, writes → plans/[task-name].results.md
4. Orchestrator reads results file
5. Orchestrator writes review request → plans/[task-name].review-request.md
6. Orchestrator spawns Reviewer with: "Read plans/[task-name].review-request.md and review"
7. Reviewer writes → REVIEW.md
8. Orchestrator reads REVIEW.md and acts
```

**File naming**: All plan/results files go in `plans/` in the project root (not this factory repo).

---

## Spawning Instructions

When spawning a subagent, always include:

1. **Role context**: "You are an Implementer agent. Read agents/IMPLEMENTER.md first."
2. **Task file**: "Your task is in plans/[name].plan.md"
3. **Factory reference**: "Reference patterns from [path to this factory]/skills/ and stacks/"
4. **Boundaries**: "Do not make architecture decisions. If blocked, write to results file with status BLOCKED."

Example spawn message:
```
You are an Implementer agent for the [project-name] project.

1. Read /path/to/factory/agents/IMPLEMENTER.md
2. Read plans/backend-auth.plan.md
3. Execute the plan exactly as written
4. Write results to plans/backend-auth.results.md

Do not deviate from the plan. If you encounter a blocker, write BLOCKED status and stop.
```

---

## Rate Limits at a Glance

Full details in `agents/LIMITS.md` — read it before spawning.

| Model | Max output/turn | Safe context in | Max parallel |
|---|---|---|---|
| Claude Sonnet (Tier 2) | 8,192 tokens | 40,000 tokens | 3 agents |
| GPT-4o (Tier 2) | 16,384 tokens | 50,000 tokens | 3 agents |
| GPT-4o-mini (Tier 1) | 16,384 tokens | 50,000 tokens | 3 agents |
| Gemini Flash (free) | — | 1,000,000 tokens | 1 agent |

**Retry on 429**: exponential backoff — 5s → 15s → 30s → 60s → 120s → BLOCKED  
**Task sizing**: one layer per Implementer, one module per Infra agent, <10k output tokens  
**Parallel cap**: never spawn more than 3 agents at once

See `agents/LIMITS.md` for error classification, context window budget, and escalation signals.

---

## When to Add a New Agent Type

Not every task needs a specialized agent. Before creating a new agent type:

1. Can the Orchestrator do it? (planning, coordination, simple research)
2. Can the Implementer do it? (any code or file change)
3. Can the Infra Agent do it? (any Terraform/OpenTofu change)

Only add a new agent type if the work is large enough to justify it AND has strict role boundaries that prevent overlap with existing agents.

Current candidates for future agents:
- **Migration Agent**: Database migration runner (currently handled by Implementer)
- **Test Agent**: Writes test suites from completed implementations
- **Security Agent**: Dedicated security scan and penetration test sim
