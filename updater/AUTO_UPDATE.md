# Auto-Update Rules

Defines what the factory can update automatically vs what requires human approval.

---

## Update Classification

| Version Change | Risk | Action |
|---|---|---|
| Patch (1.2.3 → 1.2.4) | Low | Auto-merge after tests pass |
| Minor (1.2.3 → 1.3.0) | Medium | Create PR, human approves |
| Major (1.2.3 → 2.0.0) | High | Create issue with migration guide, human leads |

---

## Auto-Update Process

### 1. Detection (Weekly Cron)

The existing `update.yml` workflow detects version changes.

### 2. Classification

For each outdated package:

```
current_version = documented version in stacks/*.md
latest_version = fetched from npm/pub.dev/GitHub

if major(latest) > major(current):
    classification = MAJOR_BUMP
elif minor(latest) > minor(current):
    classification = MINOR_BUMP
else:
    classification = PATCH_BUMP
```

### 3. Action by Classification

**PATCH_BUMP**:
1. Create branch `auto-update/[package]-[version]`
2. Update version in relevant stacks/*.md file
3. Run regression test for that stack (see `updater/tests/`)
4. If tests pass → create PR with `auto-merge` label
5. If tests fail → create issue instead

**MINOR_BUMP**:
1. Fetch changelog from package repository
2. Check for deprecations or behavior changes
3. Create branch and PR with:
   - Version bump in stacks/*.md
   - Changelog summary in PR description
   - Label: `needs-review`
4. Human must approve and merge

**MAJOR_BUMP**:
1. Fetch migration guide from package docs
2. Create issue with:
   - Title: "Major version: [package] v[old] → v[new]"
   - Body: migration guide summary, breaking changes list
   - Label: `breaking-change`
3. Human must:
   - Review breaking changes
   - Update patterns in stacks/*.md and skills/*.md
   - Update regression tests
   - Close issue when migration complete

---

## Regression Tests

Before any auto-update merges, run the relevant regression test:

| Stack | Test file | What it verifies |
|---|---|---|
| Express | `tests/test-express.sh` | App starts, /health responds |
| React/Vite | `tests/test-react-vite.sh` | Build succeeds, no TS errors |
| Flutter | `tests/test-flutter.sh` | Analyze passes, build succeeds |
| OpenTofu | `tests/test-opentofu.sh` | Validate passes |

---

## Changelog Sources

| Package | Changelog URL |
|---|---|
| Express | https://github.com/expressjs/express/releases |
| React | https://github.com/facebook/react/releases |
| Vite | https://github.com/vitejs/vite/releases |
| TailwindCSS | https://github.com/tailwindlabs/tailwindcss/releases |
| Flutter | https://docs.flutter.dev/release/release-notes |
| flutter_riverpod | https://pub.dev/packages/flutter_riverpod/changelog |
| go_router | https://pub.dev/packages/go_router/changelog |
| OpenTofu | https://github.com/opentofu/opentofu/releases |

---

## Manual Override

To skip auto-update for a specific package (e.g., known compatibility issue):

Add to `updater/skip-updates.json`:
```json
{
  "skip": [
    {
      "package": "package-name",
      "until": "2026-06-01",
      "reason": "Waiting for ecosystem compatibility"
    }
  ]
}
```

The auto-update workflow checks this file before processing.
