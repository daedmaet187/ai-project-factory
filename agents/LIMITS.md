# AI Agent Rate Limits & Token Budgets

Every Orchestrator reads this before spawning any agent.  
Every Implementer reads this before starting work.

---

## Model Capabilities & Selection

### Available Models

| Model | Alias | Context | Max Output | Best For |
|---|---|---|---|---|
| Claude Opus | `anthropic/claude-opus-4-5` | 200k | 8,192 | Complex reasoning, planning, review, architecture |
| Claude Sonnet | `anthropic/claude-sonnet-4-6` | **1M** | 8,192 | Large context, bulk analysis, design, documentation |
| Codex | `openai/gpt-5.3-codex` | 128k | 16,384 | Code generation, precise edits, structured output |
| GPT-4o | `openai/gpt-4o` | 128k | 16,384 | Alternative to Codex, good at code |
| Gemini Flash | `google/gemini-flash-lite-latest` | **1M** | — | Cost-efficient, massive context reads |

### When to Use Each Model

**Claude Opus** — the thinker:
- Orchestrator planning and coordination
- Reviewer security audits and code review
- Debugging complex multi-system issues
- Any decision requiring nuanced trade-off analysis
- Architecture decisions, ADR writing

**Claude Sonnet** — the workhorse with big context:
- UI Agent (large Figma file analysis)
- Brain Agent (reading many lesson files)
- Any task requiring >200k context
- Bulk analysis (reading entire directories)
- When you need to "see everything at once"

**Codex (gpt-5.3-codex)** — the coder:
- Implementer work (new files, edits)
- Test Agent (generating test suites)
- Infra Agent (OpenTofu HCL)
- Any task that's "write code following this pattern"
- Precise, structured output

**Gemini Flash** — the cheap reader:
- Reading massive codebases for context
- Simple transformations
- Fallback when other models rate-limited
- Low-stakes bulk tasks

### Model Selection by Agent Role

| Agent | Primary Model | When to Switch |
|---|---|---|
| Orchestrator | Opus | Sonnet if need to read >200k context |
| Implementer | Codex | — |
| Reviewer | Opus | Sonnet if reviewing very large PRs |
| Test Agent | Codex | — |
| Infra Agent | Codex | — |
| UI Agent | Sonnet | Opus if complex design decisions |
| Brain Agent | Sonnet | Opus for pattern extraction requiring judgment |

---

## Model Rate Limits

### Anthropic Claude (Opus & Sonnet)

| Tier | Requests/min | Input tokens/min | Output tokens/min |
|---|---|---|---|
| Free | 5 | 25,000 | 5,000 |
| Pro (personal) | 50 | 80,000 | 16,000 |
| API — Tier 1 | 50 | 40,000 | 8,000 |
| API — Tier 2 | 1,000 | 80,000 | 16,000 |
| API — Tier 3 | 2,000 | 160,000 | 32,000 |
| API — Tier 4 | 4,000 | 400,000 | 80,000 |

**Practical limits (assume Tier 2)**:
- Max output per turn: **8,192 tokens**
- Safe context for Opus: **~150,000 tokens** (leaves room for output)
- Safe context for Sonnet: **~800,000 tokens** (1M context, leave buffer)
- If task exceeds model context → switch model or split task

### OpenAI Codex / GPT-4o

| Tier | Requests/min | Tokens/min | Context window |
|---|---|---|---|
| Free | 3 | 40,000 | 128k |
| Tier 1 | 60 | 60,000 | 128k |
| Tier 2 | 500 | 200,000 | 128k |
| Tier 3 | 3,500 | 800,000 | 128k |
| Tier 4 | 10,000 | 2,000,000 | 128k |

**Practical limits**:
- Max output per turn: **16,384 tokens** (higher than Claude!)
- Safe context: **~100,000 tokens**
- Codex excels at code generation — prefer it for Implementer/Test Agent

### Google Gemini Flash

| Tier | Requests/min | Tokens/min | Context window |
|---|---|---|---|
| Free | 15 | 1,000,000 | 1M |
| Pay-as-you-go | 2,000 | 4,000,000 | 1M |

**Use for**: massive context reads, cost-efficient fallback.

---

## Retry & Backoff Protocol

When an agent hits a rate limit (HTTP 429) or transient timeout:

```
1. Do NOT retry immediately — you will get another 429
2. Exponential backoff:
   - Attempt 1 failed → wait 5 seconds
   - Attempt 2 failed → wait 15 seconds
   - Attempt 3 failed → wait 30 seconds
   - Attempt 4 failed → wait 60 seconds
   - Attempt 5+ failed → wait 120 seconds, then ESCALATE
3. After 5 retries with no success:
   - Write status BLOCKED to results file
   - Include: error code, attempts made, total wait time
   - Notify Orchestrator
   - STOP — do not retry further
4. Orchestrator decision options: wait longer, split task, switch model
```

---

## Task Sizing Rules

The Orchestrator uses these when writing plans. Concrete targets prevent token limit failures.

### For Implementer tasks (GPT-4o / Codex)

- **One task = one layer** (backend OR admin OR mobile — never all three in one task)
- **One task = one feature group** (auth OR products OR file-upload — not the entire app in one turn)
- **File length limit**: if a new file will be >200 lines, split: write scaffold first, then fill logic
- **Context passed**: only the files directly needed (3–5 files max), not the whole codebase
- **Target output**: task should produce **<10,000 tokens** of new/changed code
- If estimated output exceeds 10,000 tokens → split the task before spawning

### For Reviewer tasks (Claude)

- **One review call = one layer** (backend layer, then admin layer, then mobile layer)
- **Context**: pass only the changed files from that layer, not all project files
- **Target output**: review report fits in one turn (**<4,000 tokens**)

### For Infra tasks (Codex / Claude)

- **One task = one OpenTofu module** (networking, compute, database — not all modules at once)
- **Context**: pass only the relevant module files and the `stacks/infra/*.md` guide
- **Never pass full `infra/` directory** — select only what the task needs

### For Orchestrator tasks (Claude)

- **Plan writing**: write one phase plan per turn (not all 9 phases at once)
- **File reading**: read max **5 files per turn** before acting on them
- **Progress reports**: write summaries, not full file contents, when reporting to human

---

## Context Window Management

When building context for a subagent task:

```
Budget: 80,000 input tokens (safe limit for Tier 2 Claude)

Allocate:
  System / role card:           ~2,000 tokens
  Task description:             ~1,000 tokens
  Factory patterns/skills:      ~5,000 tokens
  Files to read (context):     ~20,000 tokens max
  Previous results / memory:    ~5,000 tokens
  ─────────────────────────────────────────────
  Total passed to agent:       ~33,000 tokens
  Buffer for agent output:     ~47,000 tokens remaining
```

**Rule**: If the files-to-read budget exceeds 20,000 tokens, identify the 3–4 most relevant files only. Do not pass the whole codebase.

**How to estimate**: 1 token ≈ 4 characters ≈ 0.75 words. A 200-line file ≈ ~2,500 tokens.

---

## Parallel Agent Limits

When spawning multiple agents simultaneously:

- **Maximum 3 parallel agents at once** (backend + admin + mobile is the designed maximum)
- **On free tier**: stagger spawning by 5 seconds to avoid burst rate limits
- **If one parallel agent fails** (rate limit): the others continue; failed agent retries with backoff
- **Orchestrator tracks** which parallel tasks completed (results file present) vs pending (no file yet)
- **Never spawn a 4th parallel agent** before one of the 3 finishes

---

## Model Selection Summary

See "Model Capabilities & Selection" at the top of this file for full guidance.

**Quick reference**:
- **Opus** → Orchestrator, Reviewer (complex reasoning, security analysis)
- **Sonnet** → UI Agent, Brain Agent, large context tasks (1M window)
- **Codex** → Implementer, Test Agent, Infra Agent (code generation)
- **Gemini Flash** → bulk reads, fallback (cost-efficient)

---

## Error Classification

When an agent fails, classify the error before deciding how to respond:

| HTTP Error | Classification | Action |
|---|---|---|
| 429 Too Many Requests | Rate limit | Exponential backoff → retry (see protocol above) |
| 408 / 504 Timeout | Transient network | Retry once after 10 seconds |
| 400 Bad Request | Task/prompt error | Do NOT retry — fix the task description, then retry |
| 401 / 403 Unauthorized | Auth/key error | STOP — report to Orchestrator, do not retry |
| 500 / 503 Service Error | Provider outage | Wait 60s, retry once; if still failing — escalate |
| Context length exceeded | Task too large | Split task, reduce context, retry |
| Output truncated mid-response | Token output limit | Split task — ask for continuation in next call |
| Wrong output format | Prompt ambiguity | Clarify instructions, retry once only |

---

## Signals an Agent Must Stop and Escalate

An agent **MUST stop** and report BLOCKED to Orchestrator (do not retry) if:

- Same error **5+ times** in a row after backoff attempts
- Output is **consistently truncated** across multiple attempts (task is too large — must split)
- A **required file is missing** (e.g., plan file not found, schema file absent)
- A **security decision is required** (found a vulnerability, ambiguous auth requirement)
- A **destructive operation** is about to execute (`tofu destroy`, `DROP TABLE`, `rm -rf`)
- **Human confirmation is needed** (ambiguous requirement in the plan)
- **Breaking API change detected** — implementation would break existing client contracts

When writing a BLOCKED result, always include:
1. What error/condition triggered the stop
2. How many attempts were made
3. What was completed before blocking
4. What is needed to unblock
