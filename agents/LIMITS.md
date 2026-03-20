# AI Agent Rate Limits & Token Budgets

Every Orchestrator reads this before spawning any agent.  
Every Implementer reads this before starting work.

---

## Model Rate Limits (as of 2025)

### Anthropic Claude (claude-sonnet-4-x / claude-3-7-sonnet)

| Tier | Requests/min | Input tokens/min | Output tokens/min | Context window |
|---|---|---|---|---|
| Free | 5 | 25,000 | 5,000 | 200k |
| Pro (personal) | 50 | 80,000 | 16,000 | 200k |
| API — Tier 1 | 50 | 40,000 | 8,000 | 200k |
| API — Tier 2 | 1,000 | 80,000 | 16,000 | 200k |
| API — Tier 3 | 2,000 | 160,000 | 32,000 | 200k |
| API — Tier 4 | 4,000 | 400,000 | 80,000 | 200k |

**Practical limits for this factory (assume Tier 2 unless told otherwise)**:
- Max output per turn: **8,192 tokens** — use this as your task size upper bound
- Safe context to pass to a subagent: **40,000 input tokens** (leaves room for output)
- If a task requires reading >50KB of files: **split into two agent calls**
- Daily token budget varies by tier; do not spam retries — they burn quota

### OpenAI GPT-4o / Codex

| Tier | Requests/min | Tokens/min | Context window |
|---|---|---|---|
| Free | 3 | 40,000 | 128k |
| Tier 1 | 60 | 60,000 | 128k |
| Tier 2 | 500 | 200,000 | 128k |
| Tier 3 | 3,500 | 800,000 | 128k |
| Tier 4 | 10,000 | 2,000,000 | 128k |

**Practical limits**:
- Max output per turn: **16,384 tokens**
- Recommended task size: completable in one turn with **<10,000 output tokens**
- Context: pass max **50,000 input tokens** per call

### OpenAI GPT-4o-mini

| Tier | Requests/min | Tokens/min | Context window |
|---|---|---|---|
| Free | 3 | 40,000 | 128k |
| Tier 1 | 500 | 200,000 | 128k |
| Tier 2 | 2,000 | 2,000,000 | 128k |

**Use for**: small file edits, simple transforms, low-stakes tasks. Not for code review or planning.

### Google Gemini 2.0 Flash

| Tier | Requests/min | Tokens/min | Context window |
|---|---|---|---|
| Free | 15 | 1,000,000 | 1M |
| Pay-as-you-go | 2,000 | 4,000,000 | 1M |

**Use for**: tasks requiring large context windows (reading entire codebase at once).

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

## Model Selection by Task

| Task type | Recommended model | Why |
|---|---|---|
| Orchestration, planning, coordination | Claude Sonnet | Best reasoning, long context, nuanced decisions |
| Code implementation (new files, edits) | GPT-4o / Codex | Best at precise code generation and diffs |
| Code review (security, patterns) | Claude Sonnet | Better at nuanced pattern analysis and risk |
| Infrastructure (OpenTofu HCL) | GPT-4o | Good at structured config generation |
| Design token extraction | Claude Sonnet | Better at visual/creative interpretation |
| Debugging (root cause analysis) | Claude Sonnet | Better at reasoning through unexpected behavior |
| Simple file edits (<50 lines changed) | GPT-4o-mini | Cost-efficient, fast for small tasks |
| Large context (reading whole codebase) | Gemini Flash | 1M context window |

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
