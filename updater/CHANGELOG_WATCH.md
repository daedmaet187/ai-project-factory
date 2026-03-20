# Changelog Watch

How to monitor framework changelogs for breaking changes and deprecations.

---

## Watched Packages

These packages have active changelog monitoring:

| Package | Ecosystem | Release Feed |
|---|---|---|
| express | npm | GitHub Releases API |
| react | npm | GitHub Releases API |
| vite | npm | GitHub Releases API |
| tailwindcss | npm | GitHub Releases API |
| @tanstack/react-query | npm | GitHub Releases API |
| flutter_riverpod | pub.dev | pub.dev API |
| go_router | pub.dev | pub.dev API |
| opentofu | GitHub | GitHub Releases API |

---

## Monitoring Process

### GitHub Releases API

```bash
# Fetch latest release for a GitHub repo
curl -s "https://api.github.com/repos/[owner]/[repo]/releases/latest" | jq '{
  tag: .tag_name,
  published: .published_at,
  body: .body
}'
```

### pub.dev API

```bash
# Fetch package info including changelog
curl -s "https://pub.dev/api/packages/[package]" | jq '{
  version: .latest.version,
  published: .latest.published
}'

# Changelog is in the package tarball — fetch separately if needed
```

---

## Breaking Change Detection

When a new release is detected, scan the release notes for:

**Keywords indicating breaking changes**:
- "BREAKING"
- "breaking change"
- "removed"
- "deprecated"
- "migration required"
- "no longer supports"

**Keywords indicating deprecations**:
- "deprecated"
- "will be removed"
- "use X instead"

If detected, classify as MAJOR_BUMP even if semver says minor.

---

## Notification

When a watched package has a new release:

1. **Patch/Minor with no breaking keywords**: Log only, include in weekly report
2. **Minor with deprecation keywords**: Create issue with `deprecation` label
3. **Major or breaking keywords**: Create issue with `breaking-change` label

---

## Weekly Summary

The `update.yml` workflow generates a summary of all version changes detected. This is created as a GitHub issue every Monday.
