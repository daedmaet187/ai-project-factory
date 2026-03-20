# Migration Guide Template

When a major version bump is detected, generate a migration guide using this template.

---

## Migration Guide: [Package] v[old] → v[new]

**Generated**: [date]
**Package**: [package name]
**Ecosystem**: [npm/pub.dev]
**Affected files**: [list of stacks/*.md and skills/*.md files that reference this package]

---

## Breaking Changes

(Extracted from release notes)

1. **[Change title]**
   - Old behavior: [description]
   - New behavior: [description]
   - Migration: [what to change in code]

2. ...

---

## Deprecations

(Extracted from release notes)

1. **[Deprecated API]**
   - Deprecated in: v[version]
   - Removal planned: v[version] (if known)
   - Replacement: [new API to use]

---

## Files to Update

### stacks/

- [ ] `stacks/backend/nodejs-express.md` — update version pin, check code snippets
- [ ] ...

### skills/

- [ ] `skills/stack/[package].md` — update patterns if API changed
- [ ] ...

### brain/patterns/

- [ ] Check if any patterns use deprecated APIs

---

## Regression Test Updates

If APIs changed, update the regression test:

- [ ] `updater/tests/test-[stack].sh`

---

## Verification

After migration:

```bash
# Run the relevant regression test
./updater/tests/test-[stack].sh

# Expected: all checks pass
```

---

## Rollback Plan

If issues are discovered after migration:

1. Revert the PR that updated version pins
2. Pin to previous version in all affected files
3. Create issue documenting the incompatibility
4. Add to `updater/skip-updates.json` until resolved
