# Code Review Workflow — Between Agents

How Orchestrator requests reviews and how Reviewer delivers them.

---

## When to Request a Review

| Trigger | Who reviews | Scope |
|---|---|---|
| After Phase 3 (full generation) | Reviewer Agent | All three layers |
| After a feature is implemented | Reviewer Agent | Changed files only |
| After a critical bug fix | Reviewer Agent | Changed files + related code |
| Before going live | Reviewer Agent | Security-focused full review |

---

## Orchestrator: How to Request a Review

1. Write a review request file: `plans/[scope].review-request.md`
2. Spawn Reviewer with: "Read agents/REVIEWER.md, then read [review-request file], then review."
3. Wait for `REVIEW.md` to be written
4. Read and act on `REVIEW.md`

---

## Review Request File Format

```markdown
# Review Request: [scope description]

**Date**: [ISO date]
**Layers**: backend | admin | mobile | all
**Commits to review**: main branch since [date or commit hash]

## Files Changed

### Backend
- src/routes/auth.js (new)
- src/middleware/auth.js (new)
- src/schemas/auth.js (new)

### Admin  
- src/pages/auth/LoginPage.tsx (new)
- src/hooks/useAuth.ts (new)

### Mobile
- lib/features/auth/providers/auth_provider.dart (new)
- lib/features/auth/ui/screens/login_screen.dart (new)

## Focus Areas
[Optional: specific concerns to prioritize]
- Verify JWT refresh token rotation is implemented correctly
- Confirm rate limiting is applied to login endpoint

## Stack References
- skills/stack/express5.md
- skills/general/jwt-auth.md
- security/CHECKLIST.md (run this checklist)

## Output File
Write review to: REVIEW.md
```

---

## Orchestrator: Acting on Review Results

### No issues (PASS)
```
Merge to main if on feature branch.
Deploy per normal CI/CD.
Archive review: mv REVIEW.md docs/reviews/[date]-[scope].md
```

### Warnings only (PASS WITH WARNINGS)
```
Present warnings to human.
For each warning, decide:
  a) Fix now: write a plan, spawn Implementer
  b) Create issue: gh issue create --title "[WARN] ..." --label "tech-debt"
  c) Accept risk: document in ADR

After human decision: proceed to deploy.
```

### Critical issues (FAIL)
```
For each CRITICAL:
1. Write a focused fix plan (plans/[feature]-fix-[crit-id].plan.md)
2. Spawn Implementer with fix plan
3. Wait for results

After all criticals addressed:
- Write new review request scoped to changed files only
- Spawn Reviewer again
- Repeat until PASS
```

---

## Escalation (from REVIEW.md)

If Reviewer writes an ESCALATION section (architecture issue, not fixable at code level):

```
1. Stop deployment
2. Read the escalation carefully
3. Present to human with the options provided
4. Write ADR documenting the decision
5. Write new plan(s) based on chosen option
```

---

## Review Metrics

Track these across reviews to improve generation quality:

```markdown
# Review Summary Log
Date: [date]
Project: [name]
Scope: [full generation / feature / bugfix]

| Layer | CRITICALs | WARNINGs | NOTEs | Result |
|---|---|---|---|---|
| Backend | 0 | 2 | 1 | PASS WITH WARNINGS |
| Admin | 1 | 1 | 0 | FAIL → PASS after fix |
| Mobile | 0 | 0 | 2 | PASS |

Common issues found:
- Missing rate limiting on /auth/register (backend)
- Password returned in user list response (admin — CRITICAL)
```

Common issues should be added to `security/GAPS.md` so future generations catch them.
