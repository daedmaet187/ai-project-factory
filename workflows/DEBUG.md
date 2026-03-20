# Debugging Workflow — For AI Agents

Before touching any code to fix a bug, follow this workflow. Guessing wastes time.

---

## Step 1: Reproduce

You cannot fix what you cannot reproduce. First task: reproduce the bug consistently.

```
[ ] Get exact steps to reproduce (from human or error logs)
[ ] Reproduce in development environment
[ ] Confirm bug disappears when you think it's fixed
[ ] If can't reproduce: ask human for more details, or check live logs
```

---

## Step 2: Read the Logs

```bash
# Backend logs in CloudWatch
aws logs get-log-events \
  --log-group-name /ecs/[project]-production \
  --log-stream-name [task-id] \
  --limit 100

# Or filter for errors
aws logs filter-log-events \
  --log-group-name /ecs/[project]-production \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000)

# GitHub Actions failed run
gh run view [run-id] --log-failed
```

---

## Step 3: Form Hypothesis

Before changing code, write down:

1. **What is the observed behavior?**
2. **What is the expected behavior?**
3. **Where in the code does this diverge?**
4. **Why does it diverge?** (hypothesis)

If you have no hypothesis, you need more information. Keep reading logs and code.

---

## Step 4: Verify Hypothesis

Run a test before changing anything:

```bash
# Add temporary logging to confirm hypothesis
# Run the failing case
# Confirm the hypothesis is correct
```

Do not change production code to "see what happens." Debug in development first.

---

## Step 5: Fix

Write the minimal fix. Follow the skill `systematic-debugging` for complex bugs.

Rules:
- One change at a time
- Each change should have a clear rationale
- Don't fix unrelated issues in the same commit
- After fix: run the reproduction steps again — confirm bug is gone
- After fix: run the full test suite — confirm nothing regressed

---

## Step 6: Write the Fix Commit

```
fix(scope): brief description of what was wrong

Root cause: [what caused the bug]
Fix: [what was changed and why]
Tested: [how you verified the fix]
```

---

## Common Bug Categories

### 5xx API errors
1. Check CloudWatch logs for the exact error and stack trace
2. Look for: undefined, null reference, DB connection error, secret missing
3. Run locally with the same input

### 4xx that should be 2xx
1. Confirm auth token is valid (decode it at jwt.io)
2. Confirm the route and method match what's implemented
3. Check Zod schema validation — was input rejected?

### Deployment failures (ECS)
1. Check ECS service events: `aws ecs describe-services --cluster X --services Y`
2. Check task stopped reason: `aws ecs list-tasks --cluster X --desired-status STOPPED`
3. Check if new image was pushed: `aws ecr describe-images --repository-name X`

### CI/CD failures
1. `gh run view [id] --log-failed`
2. Common: missing env var/secret, wrong Docker build context, test DB not ready

### Flutter app crashes
1. Check stack trace in the error dialog or debug console
2. Look for null safety errors, unhandled async exceptions
3. Check if API responses changed shape (API might have updated)

### Design/style issues (admin)
1. Check if TailwindCSS 4 class is correct (v4 syntax vs v3)
2. Check if CSS custom property is defined in @theme
3. Check if shadcn/ui component needs reinstalling (npx shadcn@latest add)
