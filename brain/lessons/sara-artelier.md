# Lessons: Sara Artelier Order System

**Project**: Sara Artelier
**Completed**: 2026-03-22
**Stack**: Node.js/Express, React/Vite/shadcn, PostgreSQL RDS, ECS Fargate, CloudFront, Cloudflare DNS
**Duration**: ~12 hours

---

## What Went Well

- Intake process produced a very clear project brief with no ambiguity
- Phone-based returning customer detection pattern worked first time
- OpenTofu infra validated clean (`tofu validate` passed)
- Deposit upload + S3 presigned URL flow worked correctly
- Bilingual AR/EN with RTL toggle worked via `dir` on `<html>` element
- Cairo font for Arabic glyphs was the right call (Playfair Display has no Arabic support)

---

## Blockers Encountered

| Blocker | Resolution | Time Lost |
|---|---|---|
| Orphaned VPC from failed local tofu apply (NAT Gateway cost) | Manual cleanup: delete NAT → subnets → route tables → VPC | ~45 min |
| ACM cert for CloudFront (us-east-1) couldn't be created before DNS exists | Request cert → add Cloudflare DNS validation record → wait for ISSUED → then create CloudFront | ~20 min |
| ACM cert for ALB (eu-central-1) had same chicken-and-egg issue | Same process: request → DNS validate → add HTTPS listener to ALB | ~20 min |
| CloudFront 403 on all SPA routes (no custom error response) | Add custom error responses (403/404 → /index.html 200) via AWS CLI | ~10 min |
| bcrypt in devDependencies, not dependencies | Move to dependencies, rebuild Docker image | ~15 min |
| Dockerfile built from `backend/` context, can't COPY `../migrations/` | Change CI to build from project root with `-f backend/Dockerfile` | ~20 min |
| ECS task missing IAM task role → no S3 access for deposit uploads | Create task role with S3 policy, register new task definition revision | ~15 min |
| API field name mismatch: backend snake_case vs frontend camelCase | Full audit of all dashboard pages — 5 pages needed fixing | ~45 min |
| RDS requires SSL — pg client fails with self-signed cert chain | Set `ssl: { rejectUnauthorized: false }` in pg Pool config | ~15 min |
| Settings SQL used `$2` with single param array | Fix to `$1` | ~5 min |
| terraform.tfstate committed to repo | Add to .gitignore (should have used S3 backend from day 1) | ~5 min |

---

## Agent Pipeline Issues (critical — do not repeat)

1. **Watson implemented code directly** — violated factory rules. Watson should only write plans and orchestrate. All code must go through Codex (Implementer).
2. **Phase 4b (Test Agent) skipped** — no real test suite was written. Only placeholder tests to satisfy vitest. This allowed the API field name bug to ship.
3. **Phase 7 (Handoff) skipped** — HANDOFF.md was left as placeholder until post-delivery correction.
4. **Brain Agent never run** — registry and lessons not recorded until post-delivery correction.
5. **PROJECT.md not updated** when stack decisions changed (region changed from me-south-1 to eu-central-1 mid-project).
6. **Reviewer ran but review was incomplete** — only sampled files, missed that ALL dashboard pages had the same camelCase bug.

---

## Patterns Invented

### Phone-based returning customer detection
Check if phone has any `completed` (delivered) order. If yes → skip deposit. If no → require deposit. Sara has manual override per phone in dashboard. Implementation: `customerCheck.js` service queries orders JOIN customers on phone.

### Cloudflare + AWS ALB SSL setup (no Cloudflare Full SSL)
For MVP with HTTP-only ALB: keep DNS record as DNS-only (no proxy), add ACM cert to ALB, add HTTPS listener. CloudFront gets its own ACM cert in us-east-1. This avoids the Cloudflare Flexible SSL limitations and gives proper end-to-end HTTPS.

### ECS migrations via one-off task
Run DB migrations as a Fargate one-off task (same task definition, override command to `node src/db/migrate.js`). No need for a separate container or external DB access. Pattern documented in HANDOFF.md.

---

## Review Findings

- CRITICALs found: 6
- CRITICALs fixed: 6 (all before shipping)
- WARNINGs deferred: 11 (tracked in HANDOFF.md tech debt section)
- Post-delivery bugs fixed: API field mapping (5 pages), settings SQL, bcrypt dep, migrations path, CORS, S3 task role

---

## Suggestions for Factory

1. **Add API contract test step to Phase 3** — after Implementer writes backend, generate a contract file (`api-contract.json`) listing all endpoints + response shapes. UI Agent must read this before writing any API calls. Would have prevented the camelCase/snake_case mismatch entirely.
2. **Add infra checklist: S3 backend for state** — `terraform.tfstate` should never be local. Add S3 backend setup as step 0 of Phase 2.
3. **Add "SSL bootstrap" to infra plan template** — ACM certs for ALB and CloudFront need DNS validation before the resources can be created. Document this ordering requirement explicitly.
4. **CloudFront custom error responses must be in infra** — SPA routing requires 403/404 → index.html. Add this to the CDN module template.
5. **ECS task role is separate from execution role** — currently the infra module only creates execution role. Add task role with S3 permissions as standard in compute module.
6. **Phase 7 must be mandatory** — Orchestrator should not be able to declare "done" without HANDOFF.md written and verified.
7. **Reviewer must test every route handler file**, not sample — or add a secondary pass specifically for API contract consistency.

---

## Metrics

- Commits: 18
- CI runs to green: 8 (backend: 4, admin: 3, infra: 1)
- Human interventions (bugs reported by user): 4 (login broken, settings not saving, orders not showing in dashboard, UI issues)
- Post-delivery fixes: 6 separate fix commits
