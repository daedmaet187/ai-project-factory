# Agent Roster

All agents involved in project generation, their roles, when they're spawned, and how they communicate.

---

## Agent Types

| Agent | Recommended Model | Role | When spawned |
|---|---|---|---|
| **Orchestrator** | Watson (Claude Sonnet) | Planning, coordination, memory, GitHub ops, checkpoints | Always — root session |
| **Architect** | Claude Opus | Architecture decisions, DB schema, API contracts, task decomposition | Phase 2 — before any code |
| **Implementer** | Codex (gpt-5.3-codex) via **ACP runtime** | Code writing, file edits, builds, tests, git push | Phase 3 — one per layer, parallel |
| **Reviewer** | Claude Opus | PR review, security audit, spec compliance | Phase 4 — after all implementation |
| **Infra Agent** | Codex (gpt-5.3-codex) via **ACP runtime** | Terraform/infra only | Phase 3 — parallel with implementers |
| **UI Agent** | Watson | Figma API extraction, design token file creation | Before Phase 3 if Figma provided |
| **Cleanup Agent** | Codex via **ACP runtime** | Design token correction, find-and-replace passes | After Phase 3 if tokens need fixing |
| **Brain Agent** | Claude Sonnet | Pattern extraction, lesson analysis, improvement queuing | On-demand or after N projects |

## ⚠️ CRITICAL: Codex Must Use ACP Runtime

**Codex via `subagent` runtime = LLM only. No file system access. Will NOT write files to disk.**

Always spawn Codex with:
```json
{ "runtime": "acp", "agentId": "codex" }
```

### ACP Prerequisites (must be configured once per machine):
```bash
openclaw plugins install acpx
openclaw config set plugins.entries.acpx.enabled true
openclaw config set acp.enabled true
openclaw config set acp.backend acpx
openclaw config set acp.defaultAgent codex
openclaw config set acp.allowedAgents '["codex","claude"]'
openclaw config set plugins.entries.acpx.config.permissionMode approve-all
openclaw config set plugins.entries.acpx.config.nonInteractivePermissions fail
npm install -g @openai/codex
# Set OPENAI_API_KEY in ~/.zshrc
openclaw gateway restart
```

### Smoke test before spawning:
```
sessions_spawn({ task: "Reply with exactly: ACP-CODEX-OK", runtime: "acp", agentId: "codex", mode: "run" })
```
Expected: response contains `ACP-CODEX-OK`

---

## Model Selection Guide

Choose the model based on the task characteristics, not the agent role. These are recommendations, not hard requirements.

### Claude Opus (anthropic/claude-opus-4-5)
**Best for**: Complex reasoning, architecture decisions, nuanced code review, security analysis, planning
**Context**: 200k tokens
**When to use**:
- Orchestrator work (planning, coordination, complex decisions)
- Reviewer work (needs to understand subtle bugs, security implications)
- Any task requiring deep reasoning over trade-offs
- Debugging complex issues with multiple interacting systems

### Claude Sonnet (anthropic/claude-sonnet-4-6)
**Best for**: Large context tasks, bulk analysis, design work, documentation
**Context**: 1M tokens
**When to use**:
- UI Agent (design token extraction from large Figma files)
- Brain Agent (analyzing multiple lesson files at once)
- Any task requiring reading large portions of the codebase
- Batch processing (reading all files in a directory, summarizing)
- When context > 200k tokens is needed

### Codex (openai/gpt-5.3-codex)
**Best for**: Code generation, precise edits, structured output, infrastructure code
**Context**: 128k tokens
**When to use**:
- Implementer work (writing new code, editing files)
- Test Agent (generating test suites)
- Infra Agent (writing OpenTofu HCL)
- Any task that's primarily "write code following this pattern"
- Tasks with clear specs where creativity isn't needed

### Gemini Flash (google/gemini-flash-lite-latest)
**Best for**: Cost-efficient simple tasks, massive context reads
**Context**: 1M tokens
**When to use**:
- Reading entire codebases for context
- Simple file transformations
- Low-stakes tasks where cost matters
- Fallback when other models are rate-limited

### Model Override

Agents can request a different model if the task demands it:

```
# In the plan file:
**Suggested model**: Claude Sonnet (task requires reading 15 files totaling ~300k tokens)
```

The Orchestrator decides the final model based on:
1. Task requirements (context size, reasoning complexity)
2. Current rate limits (fallback if primary model is limited)
3. Cost considerations (Codex for bulk code, Opus for critical decisions)

---

## Role Boundaries

These boundaries are strict. Role violations cause inconsistency.

```
Orchestrator  → Plans, coordinates, never implements
Implementer   → Implements, never architects
Reviewer      → Reviews, never implements
Test Agent    → Writes tests, never implements features
Infra Agent   → Infrastructure only, never app code
UI Agent      → Design system only, no business logic
```

---

## Pipeline Phases (Mandatory)

```
Phase 1 — Watson
  → Gather requirements, write BRIEF.md
  → CHECKPOINT: confirm brief with human before proceeding

Phase 2 — Opus (Architect)
  → Read brief → produce ARCHITECTURE.md, DB_SCHEMA.md, API_CONTRACTS.md,
    TASKS_*.md per layer, SECURITY.md, OPUS_DONE.md
  → CHECKPOINT: show Opus decisions + open questions to human, get answers

Phase 3 — Codex via ACP (Implementers, parallel)
  → One agent per layer: backend, admin, pwa, mobile, infra
  → Each reads plan files, implements, runs tests, commits, pushes
  → CHECKPOINT: show phase 3 results to human before spawning Opus review

Phase 4 — Opus (Reviewer)
  → Reads all committed code + plan files
  → Reviews: correctness, security, spec compliance, design tokens
  → Writes REVIEW.md with findings
  → CHECKPOINT: present findings to human, get go/fix decision

Phase 5 — Watson
  → GitHub ops: branch protection, secrets docs, HANDOFF.md
  → CHECKPOINT: explicit sign-off before declaring done
```

## Parallel Execution Model

```
Watson (Orchestrator)
    │
    ├── [Phase 2] Opus (Architect) — sequential, produces all plan files
    │
    │   AFTER Phase 2 + human checkpoint:
    │
    ├── [Phase 3, parallel — ALL via ACP runtime]:
    │   ├── Codex (backend)   ─┐
    │   ├── Codex (admin)      ├── all in parallel
    │   ├── Codex (pwa)        │
    │   ├── Codex (mobile)     │
    │   └── Codex (infra)     ─┘
    │
    │   AFTER all Phase 3 complete + human checkpoint:
    │
    ├── [Phase 4] Opus (Reviewer) — sequential, reviews all layers
    │
    └── [Phase 5] Watson — GitHub ops, HANDOFF.md
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

| Model | Context Window | Max output/turn | Best for |
|---|---|---|---|
| Claude Opus | 200k | 8,192 tokens | Complex reasoning, planning, review |
| Claude Sonnet | 1M | 8,192 tokens | Large context, bulk analysis, design |
| Codex (gpt-5.3-codex) | 128k | 16,384 tokens | Code generation, structured output |
| GPT-4o | 128k | 16,384 tokens | Alternative to Codex |
| Gemini Flash | 1M | — | Cost-efficient, massive context |

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
- **Security Agent**: Dedicated security scan and penetration test sim
- **Migration Agent**: Database migration runner (currently handled by Implementer)

See `agents/TEST.md` for the Test Agent role card (now active).
