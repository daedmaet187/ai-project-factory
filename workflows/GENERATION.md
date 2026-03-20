# Generation Workflow — End-to-End Project Generation

This is the master workflow. After intake is approved, execute phases in this exact order.

---

## Pre-Generation (Orchestrator runs before any phase)

### Step 1: Run Preflight

Follow `updater/PREFLIGHT.md`. All four steps must pass.  
If PREFLIGHT FAILED → resolve the issue and re-run before continuing.  
Do not start intake until preflight passes.

### Step 2: Run Interactive Intake

Follow `intake/INTERACTIVE.md`.  
Output: `intake/PROJECT_BRIEF.json` with `"approved": true`

**Do not start Phase 0 until `PROJECT_BRIEF.json` exists and has `"approved": true`.**

Validate the JSON against `intake/PROJECT_BRIEF.schema.json` before marking intake complete:
```bash
# Validate PROJECT_BRIEF.json against schema (requires ajv-cli or equivalent)
npx ajv-cli validate -s intake/PROJECT_BRIEF.schema.json -d intake/PROJECT_BRIEF.json \
  && echo "✅ PROJECT_BRIEF.json is valid" \
  || echo "❌ Validation failed — fix before proceeding"
```

### Step 3: Read rate limit rules

Read `agents/LIMITS.md` now, before writing any plans or spawning any agents.

---

## Pre-Conditions

Before starting Phase 0:
- Preflight passed ✅
- `intake/PROJECT_BRIEF.json` generated and `approved: true` ✅
- `intake/ACCESS.md` credentials validated ✅
- Stack selected (from PROJECT_BRIEF.json) ✅

---

## Phase 0: Repository Setup (Orchestrator)

```
0.1 Create GitHub repository
    Command: gh repo create [org/project-name] --private --description "[one-liner]"
    
0.2 Initialize local structure
    - Create monorepo directory structure:
      project-name/
      ├── backend/
      ├── admin/
      ├── mobile/ (if applicable)
      ├── infra/
      ├── migrations/
      ├── plans/    ← Orchestrator creates this
      ├── docs/
      │   └── decisions/   ← For ADRs
      ├── .github/
      │   └── workflows/
      ├── PROJECT.md     ← Copy from approved plan
      ├── HANDOFF.md     ← Populated in Phase 9
      └── .gitignore

0.3 Create .gitignore
    - Include: .env, .env.local, *.tfvars (except .example), *.pem, *.key,
               node_modules/, .dart_tool/, build/, __pycache__/,
               .terraform/, *.tfstate (state goes in S3)

0.4 Set up branch protection
    Command: gh api repos/[owner]/[repo]/branches/main/protection --method PUT
    Rules: require PR, require CI pass before merge

0.5 Set GitHub Secrets
    Command: gh secret set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
             CF_API_TOKEN, CF_ACCOUNT_ID, FIGMA_TOKEN (if applicable)

0.6 Set GitHub Variables (non-sensitive config)
    Command: gh variable set AWS_REGION, ECR_REPOSITORY, ECS_CLUSTER,
             ECS_SERVICE, API_DOMAIN, API_URL, CF_PAGES_PROJECT

0.7 Initial commit (empty structure + .gitignore)
    git commit -m "chore: initialize project structure"
    git push -u origin main
```

**Checkpoint**: Confirm with human that repo exists and is accessible. Show URL.

---

## Phase 1: Design System (UI Agent)

*Skip if: Figma not provided AND description is "default/minimal"*

```
1.1 Spawn UI Agent with:
    - Design input: Figma file key, OR color palette, OR style description
    - Output locations: design-tokens.json (project root), admin/src/index.css,
      mobile/lib/core/theme/

1.2 UI Agent generates design-tokens.json following stacks/mobile/figma-integration.md

1.3 UI Agent generates:
    - admin/src/index.css with @theme CSS variables
    - mobile/lib/core/theme/app_colors.dart
    - mobile/lib/core/theme/app_theme.dart

1.4 UI Agent commits: feat(design): generate design system from [source]
```

**CHECKPOINT**: UI Agent shows Orchestrator the color palette and typography. Human confirms before continuing.

---

## Phase 2: Infrastructure (Infra Agent)

```
2.1 Orchestrator writes plan: plans/infra-initial.plan.md
    - Stack: [from PROJECT.md]
    - Pattern reference: stacks/infra/aws-ecs-fargate.md
    - Modules to create: networking, compute, database, secrets, dns
    - Variables from: PROJECT.md (region, scale_tier, domain, project_name)

2.2 Spawn Infra Agent:
    - Read: plans/infra-initial.plan.md
    - Read: stacks/infra/aws-ecs-fargate.md
    - Read: skills/stack/opentofu.md
    - Execute OpenTofu module creation

2.3 Infra Agent runs:
    cd infra
    tofu init
    tofu validate
    tofu plan -out=tfplan.out 2>&1 | tee plan-output.txt

2.4 Infra Agent writes plan output to plans/infra-initial.results.md (PENDING status)
```

**CHECKPOINT**: Orchestrator reads the plan output. Summarizes for human:
```
Infrastructure plan:
- 23 resources to add
- 0 resources to change  
- 0 resources to destroy

New resources include: VPC, 2 private subnets, 2 public subnets, NAT gateway,
ECS cluster, ECR repository, RDS PostgreSQL, ALB, Secrets Manager secret, 
CloudFront distribution, Cloudflare DNS records.

Estimated cost: ~$65/mo (MVP tier)

Type 'apply infra' to proceed.
```

```
2.5 On human approval:
    tofu apply tfplan.out

2.6 Infra Agent captures outputs:
    - ECR_URL: [output]
    - ALB_DNS: [output]
    - RDS_ENDPOINT: [output]
    - API_URL: https://[api_subdomain].[domain]
    
    Writes to: plans/infra-initial.results.md (DONE status)
    Commits: feat(infra): provision AWS infrastructure via OpenTofu

2.7 Deploy observability module
    - Included in the main tofu apply above (observability is a module in infra/main.tf)
    - Confirm SNS email subscription was sent to alert_email:
      aws sns list-subscriptions-by-topic --topic-arn [sns_topic_arn]
      → Should show PendingConfirmation for the alert email
    - ⚠️  Human must click the confirmation email before CloudWatch alarms can fire
    - Note dashboard URL from tofu output:
      tofu output observability_dashboard_url
```

**CHECKPOINT**: Orchestrator verifies:
```bash
aws ecr describe-repositories --repository-names [project-name]-api
aws ecs describe-clusters --clusters [project-name]-production
aws rds describe-db-instances --db-instance-identifier [project-name]-production
aws secretsmanager describe-secret --secret-id /[project]/production/app
```
All must return expected results before Phase 3 starts.

---

## Phase 3: Implementation (Parallel Implementer Agents)

Spawn all three simultaneously:

```
3.1 Orchestrator writes three plan files:
    - plans/backend-initial.plan.md
    - plans/admin-initial.plan.md
    - plans/mobile-initial.plan.md

    Each plan includes:
    - API contract (endpoint list from PROJECT.md features)
    - Stack reference files to read
    - Design token reference (from Phase 1)
    - ECR URL and RDS endpoint from Phase 2 outputs
    - Acceptance criteria for the full feature set
    - Verification commands

3.2 Spawn simultaneously:
    - Backend Implementer (reads plans/backend-initial.plan.md)
    - Admin Implementer (reads plans/admin-initial.plan.md)
    - Mobile Implementer (reads plans/mobile-initial.plan.md)

3.3 Wait for all three results files to appear:
    - plans/backend-initial.results.md
    - plans/admin-initial.results.md
    - plans/mobile-initial.results.md

3.4 Orchestrator reads each results file:
    - Any BLOCKED? → Write fix plans, re-spawn blocked layer
    - All DONE? → Proceed to Phase 4
```

**Each Implementer follows**: agents/IMPLEMENTER.md (self-review checklist, verification gates)

---

## Phase 4: Code Review (Reviewer Agent)

```
4.1 Orchestrator writes review request: plans/review-full.review-request.md

4.2 Spawn Reviewer Agent:
    - Read: plans/review-full.review-request.md
    - Review: all three layers
    - Output: REVIEW.md

4.3 Orchestrator reads REVIEW.md:

    If CRITICAL issues exist:
    - Write fix plans for each critical
    - Spawn Implementer(s) for fixes
    - Re-spawn Reviewer on changed files
    - Repeat until no CRITICALs

    If only WARNINGS:
    - Present warnings to human
    - Human decides: fix now (write plan + spawn) or create issues for later
    
    If PASS:
    - Proceed to Phase 5
```

---

## Phase 5: Database Migration (Orchestrator + Implementer)

```
5.1 Orchestrator writes migration plan: plans/db-migrations.plan.md
    - List migration files to run
    - Connection details from Secrets Manager
    - Expected schema after migration (table list)

5.2 Spawn Implementer to run migrations:
    cd project-root
    DATABASE_URL=$(aws secretsmanager get-secret-value \
      --secret-id /[project]/production/app \
      --query 'SecretString' --output text | jq -r '.DATABASE_URL')
    ./scripts/migrate.sh

5.3 Verify schema:
    psql "$DATABASE_URL" -c "\dt"  # List tables
    # Expected tables: users, refresh_tokens, [feature tables]

5.4 Commit migrations: feat(db): run initial schema migrations
```

---

## Phase 6: CI/CD Verification (Orchestrator)

```
6.1 Trigger all workflows manually:
    gh workflow run backend-deploy.yml --ref main
    gh workflow run admin-deploy.yml --ref main
    # Mobile CI only (no auto-deploy for mobile)

6.2 Monitor all workflows:
    gh run list --limit 10
    gh run watch [run-id]

6.3 On workflow failure:
    gh run view [run-id] --log-failed
    Write fix plan → Spawn Implementer → Re-trigger

6.4 Verify live endpoints:
    # API health
    curl -s https://api.[domain]/health | jq '.status'
    # Expected: "ok"

    # Auth endpoint accessible
    curl -s -o /dev/null -w "%{http_code}" \
      -X POST https://api.[domain]/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"email":"invalid","password":"invalid"}'
    # Expected: 401 (not 404, 500, or connection error)

    # Admin panel loads
    curl -s -o /dev/null -w "%{http_code}" https://admin.[domain]/
    # Expected: 200

6.5 Verify observability
    # All CloudWatch alarms in OK state (not INSUFFICIENT_DATA or ALARM)
    aws cloudwatch describe-alarms \
      --alarm-name-prefix [project_name] \
      --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue}' \
      --output table
    # Expected: all alarms show OK

    # CloudTrail is actively logging
    aws cloudtrail get-trail-status \
      --name [project_name]-[environment]-trail \
      --query '{IsLogging:IsLogging,LatestDelivery:LatestDeliveryTime}'
    # Expected: IsLogging: true

    # Confirm a /health hit generated a structured log entry in CloudWatch
    aws logs filter-log-events \
      --log-group-name /ecs/[project_name]-[environment]-api \
      --filter-pattern '{ $.url = "/health" }' \
      --limit 1
    # Expected: JSON log entry with url, statusCode, responseTime fields

    # Verify Sentry project is receiving events (check dashboard manually):
    # https://sentry.io → [org] → [project] → Issues
    # Send a test error: curl -X POST https://api.[domain]/api/test-error (if test route exists)
```

**CHECKPOINT**: Show human:
```
✅ Backend CI/CD: passing
✅ Admin CI/CD: passing  
✅ API health: ok
✅ Auth endpoint: responding (401 for invalid creds — correct)
✅ Admin panel: loading (200)
✅ CloudWatch alarms: all in OK state ([N] alarms)
✅ CloudTrail: IsLogging: true
✅ CloudWatch logs: JSON entries appearing for API requests
⚠️  Sentry: confirm manually at sentry.io that project is receiving events
⚠️  SNS alerts: human must click confirmation email ([alert_email]) before alarms fire

All systems green. Proceeding to handoff.
```

---

## Phase 7: Handoff (Orchestrator → Human)

```
7.1 Orchestrator creates first admin user:
    curl -s -X POST https://api.[domain]/api/auth/register \
      -H "Content-Type: application/json" \
      -d '{"email":"admin@[domain]","password":"[generated]","name":"Admin","role":"admin"}'
    
    Store admin credentials in Secrets Manager:
    aws secretsmanager put-secret-value \
      --secret-id /[project]/production/admin \
      --secret-string '{"email":"admin@[domain]","password":"[generated]"}'

7.2 Write HANDOFF.md
    Template: templates/HANDOFF.template.md (see below)

7.3 Present HANDOFF.md to human

7.4 Write lessons file
    - Create brain/lessons/[project-slug].md following brain/BRAIN.md template
    - Record: blockers hit, patterns invented, review findings, suggestions
    - Update brain/metrics/registry.json with new project entry
    - Set brain_processed: false (Brain Agent will process later)

    Template:
    ```
    # Lessons: [Project Name]

    **Project**: [name]
    **Completed**: [ISO date]
    **Stack**: [list]
    **Duration**: [hours]

    ## What Went Well
    - [list]

    ## Blockers Encountered
    | Blocker | Resolution | Time Lost |
    |---|---|---|

    ## Patterns Invented
    (Any new patterns not in existing skills)

    ## Review Findings
    - CRITICALs found: [N]
    - WARNINGs deferred: [N]

    ## Suggestions for Factory
    - [list]

    ## Metrics
    - Commits: [N]
    - CI runs to green: [N]
    - Human interventions: [N]
    ```
```

---

## HANDOFF.md Content

```markdown
# Project Handoff: [Project Name]

Generated: [DATE]
Generated by: AI Project Factory

## Live URLs

| Service | URL | Status |
|---|---|---|
| API | https://api.[domain] | ✅ Live |
| Admin Panel | https://admin.[domain] | ✅ Live |
| Health Check | https://api.[domain]/health | ✅ Responding |

## First Login

Admin panel: https://admin.[domain]
- Email: admin@[domain]
- Password: [in Secrets Manager: /[project]/production/admin]

## GitHub

Repository: https://github.com/[org]/[project]
Actions: https://github.com/[org]/[project]/actions

## AWS Resources

| Resource | Name | Region |
|---|---|---|
| ECS Cluster | [project]-production | [region] |
| RDS Instance | [project]-production | [region] |
| ECR Repository | [project]-api | [region] |
| Secrets | /[project]/production/app | [region] |

## What Was Built

[List of features from PROJECT.md]

## Known Limitations / Tech Debt

[From REVIEW.md warnings that were deferred]

## Next Steps

[ ] Test all user-facing flows manually
[ ] Set up custom error monitoring (Sentry recommended)
[ ] Review and implement REVIEW.md warnings
[ ] Run load test before marketing launch
[ ] Set up CloudWatch alarms for error rate and latency
[ ] Configure DB read replica when traffic grows

## Stack Summary

[From PROJECT.md stack selection]
```
