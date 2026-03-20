# Preflight Checklist

Run this at the start of every session before doing anything else.  
Estimated time: 2 minutes.

---

## Step 1: Check update report age

Read `updater/LAST_UPDATE_REPORT.md`.

```bash
# Check if the report exists and its age
[ -f updater/LAST_UPDATE_REPORT.md ] \
  && echo "Report exists" \
  || echo "MISSING — run UPDATER.md process first"

# Check the date in the report (first Date: line)
grep "^Date:" updater/LAST_UPDATE_REPORT.md | head -1
```

**Decision**:
- Report doesn't exist → run `updater/UPDATER.md` process first before continuing
- Report is >7 days old → run `updater/UPDATER.md` process first before continuing
- Report is recent (≤7 days) → proceed to Step 2

---

## Step 2: Check security advisories

```bash
# Quick security scan of documented npm packages
# Run from the factory root or any project layer with a package-lock.json
npm audit --package-lock-only 2>/dev/null || echo "No package-lock to audit"

# Check if any advisories affect express (the core backend package)
curl -s "https://api.osv.dev/v1/query" \
  -H "Content-Type: application/json" \
  -d '{"package": {"name": "express", "ecosystem": "npm"}}' \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
vulns = data.get('vulns', [])
print(f'{len(vulns)} advisories found for express')
for v in vulns[:3]:
    print(f'  - {v.get(\"id\", \"?\")} : {v.get(\"summary\", \"no summary\")}')
"
```

**Decision**:
- New critical security advisory found → report to human immediately; do not proceed
- Minor advisories (already known) → log and proceed
- No advisories → proceed

---

## Step 3: Verify factory files are intact

```bash
# Run from the factory root directory (ai-project-factory/)
required_files=(
  "PHILOSOPHY.md"
  "intake/INTAKE.md"
  "intake/QUESTIONS.md"
  "intake/ACCESS.md"
  "agents/ORCHESTRATOR.md"
  "agents/IMPLEMENTER.md"
  "agents/REVIEWER.md"
  "agents/LIMITS.md"
  "workflows/GENERATION.md"
  "security/CHECKLIST.md"
  "updater/UPDATER.md"
  "updater/PREFLIGHT.md"
  "intake/INTERACTIVE.md"
  "intake/PROJECT_BRIEF.schema.json"
)

all_ok=true
for f in "${required_files[@]}"; do
  if [ -f "$f" ]; then
    echo "✅ $f"
  else
    echo "❌ MISSING: $f"
    all_ok=false
  fi
done

$all_ok && echo "" && echo "All factory files present." \
  || echo "" && echo "WARNING: Missing files detected. Do not proceed."
```

**Decision**:
- Any file missing → report to human; do not proceed until resolved
- All files present → proceed to Step 4

---

## Step 4: Confirm all clear

If all steps pass → print to console:

```
PREFLIGHT PASSED — Factory ready
Date: [ISO timestamp]
Update report age: [N] days
Security advisories: [none | N minor known]
Factory files: all present
```

If any step fails → print:

```
PREFLIGHT FAILED
Reason: [specific failure]
Action required: [what to fix]
Do NOT proceed with project generation until resolved.
```

Report status to human. Only proceed when PREFLIGHT PASSED.
