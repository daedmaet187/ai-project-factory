# Feature Workflow — Adding a Feature to an Existing Project

Use this workflow when adding a new feature to an already-generated project.

---

## Pre-Conditions

- Project is already live (HANDOFF.md exists)
- Feature request received from human (or GitHub issue)
- You are in the Orchestrator role

---

## Step 1: Read Before Planning

```
[ ] Read PROJECT.md — understand the current feature set and stack
[ ] Read MEMORY.md — any relevant context or previous decisions
[ ] Read the relevant stack guides for this feature's layer
[ ] Read any existing code that the feature will interact with
```

---

## Step 2: Feature Scope

Clarify with human before writing any plan:

1. **What does this feature do?** (User-facing behavior)
2. **Which layers does it touch?** (Backend / Admin / Mobile / All)
3. **Are there new DB tables or changes to existing?**
4. **Are there new API endpoints?**
5. **Are there new secrets needed?**

Summarize and confirm before proceeding.

---

## Step 3: Write the Plan

Use the skill `writing-plans` (`~/.agents/skills/writing-plans/SKILL.md`).

For multi-layer features, write separate plan files:
- `plans/[feature-name]-backend.plan.md`
- `plans/[feature-name]-admin.plan.md`
- `plans/[feature-name]-mobile.plan.md`

Each plan must include:
- Exact API contract changes (new/modified endpoints)
- New DB columns/tables (with migration file name)
- Files to read first
- Acceptance criteria
- Verification commands

---

## Step 4: Review Plan

Use the skill `brainstorming` to check: is there a simpler approach? Are there security implications? Does this introduce tech debt?

Present the plan to human. Get approval.

---

## Step 5: Implement (same as generation Phase 3)

1. Spawn independent layers in parallel
2. Each Implementer follows `agents/IMPLEMENTER.md`
3. Verify results files

---

## Step 6: Migration (if DB changes)

```bash
# Write migration file
# migrations/NNN_add_[feature].sql

# Run against production
DATABASE_URL=$(aws secretsmanager get-secret-value ...) ./scripts/migrate.sh
```

---

## Step 7: Review and Deploy

1. Spawn Reviewer for changed files
2. Fix CRITICALs
3. Push to main → CI/CD auto-deploys
4. Verify live endpoints

---

## Step 8: Update Memory

```
[ ] Update PROJECT.md — add feature to core features list
[ ] Write to memory/YYYY-MM-DD.md — what was built, any decisions made
[ ] Create GitHub issues for any WARNINGS deferred from review
```
