# Factory Updater

Run this before executing any project generation. Purpose: ensure the factory's stack versions, patterns, and security practices are current.

## When to Run
- Before any new project generation (mandatory)
- Scheduled: weekly via GitHub Actions (see updater/update.yml)
- On-demand: any time you suspect stack docs are stale

## What It Checks
1. Package versions (npm, pub.dev, PyPI)
2. Security advisories for stack packages
3. Deprecation notices in framework docs
4. New official best practices from framework changelogs

## Process (Orchestrator executes this)

### Step 1: Check current versions in stacks/

Read the version pins in these files:
- stacks/backend/nodejs-express.md → Express, Zod, Node.js versions
- stacks/frontend/react-shadcn.md → React, Vite, Tailwind versions
- stacks/mobile/flutter-riverpod.md → Flutter, Riverpod, go_router versions
- stacks/infra/aws-ecs-fargate.md → AWS provider, OpenTofu versions

### Step 2: Fetch latest versions

Run these commands and capture output:
```bash
# npm packages — latest versions
npm view express version                    # Express
npm view zod version                        # Zod
npm view react version                      # React
npm view vite version                       # Vite
npm view tailwindcss version               # TailwindCSS
npm view @tanstack/react-query version      # React Query
npm view react-router-dom version           # React Router
npm view lucide-react version               # Lucide icons
npm view @tailwindcss/vite version          # Tailwind Vite plugin
npm view @vitejs/plugin-react version       # Vite React plugin

# Dart/Flutter packages
curl -s "https://pub.dev/api/packages/flutter_riverpod" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['latest']['version'])"
curl -s "https://pub.dev/api/packages/go_router" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['latest']['version'])"
curl -s "https://pub.dev/api/packages/dio" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['latest']['version'])"
curl -s "https://pub.dev/api/packages/riverpod_annotation" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['latest']['version'])"
curl -s "https://pub.dev/api/packages/flutter_animate" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['latest']['version'])"
curl -s "https://pub.dev/api/packages/shared_preferences" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['latest']['version'])"

# OpenTofu (GitHub releases)
curl -s "https://api.github.com/repos/opentofu/opentofu/releases/latest" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])"
```

### Step 3: Compare and flag changes

For each package, compare fetched version against documented version.
- If newer patch/minor version exists → mark as **UPDATE_AVAILABLE**
- If same version → mark as **CURRENT**
- If older (shouldn't happen) → mark as **ANOMALY**, flag for investigation

### Step 4: Check for breaking changes

For any UPDATE_AVAILABLE item:
- Check if major version bumped (e.g., 4.x → 5.x) → flag as **BREAKING_CHANGE_POSSIBLE**
- Check changelog URL (documented in stacks/ files) for breaking changes
- If BREAKING_CHANGE_POSSIBLE: read the "Migration Guide" section of that stack file

### Step 5: Generate update report

Write `updater/LAST_UPDATE_REPORT.md`:
```markdown
# Factory Update Report
Date: [ISO timestamp]
Run by: [agent or "scheduled"]

## Version Status

| Package | Documented | Latest | Status |
|---|---|---|---|
| Express | 5.2.1 | 5.x.x | ✅ Current / ⚠️ Update available / 🚨 Major bump |
| Zod | 3.22.0 | 3.x.x | ... |
| React | 19.0.0 | 19.x.x | ... |
| Vite | 6.0.0 | 6.x.x | ... |
| TailwindCSS | 4.0.0 | 4.x.x | ... |
| flutter_riverpod | 2.6.1 | x.x.x | ... |
| go_router | 14.6.2 | x.x.x | ... |
| OpenTofu | v1.9.0 | vx.x.x | ... |

## Actions Required
- [ ] Update stacks/backend/nodejs-express.md → Express x.y.z
- [ ] Update stacks/mobile/flutter-riverpod.md → flutter_riverpod x.y.z
- [ ] ... (only list items with UPDATE_AVAILABLE or BREAKING_CHANGE_POSSIBLE)

## Security Advisories
[Any npm audit findings or OSV advisories for documented versions]
[If none: "No security advisories found for documented versions."]

## Recommendation
PROCEED — all versions within acceptable range
or
UPDATE REQUIRED — update [items] before proceeding (breaking changes detected)
```

### Step 6: Decision

| Condition | Action |
|---|---|
| All **CURRENT** | Log "All versions current, proceeding." → continue to project generation |
| Only **UPDATE_AVAILABLE** (minor/patch) | Log updates found, proceed. Create task to update stacks/ docs later. |
| Any **BREAKING_CHANGE_POSSIBLE** | Show report to human. Ask: "Proceed with current docs, or update stack docs first?" Do not proceed until human decides. |
| Any **ANOMALY** | Flag and investigate before proceeding. |
