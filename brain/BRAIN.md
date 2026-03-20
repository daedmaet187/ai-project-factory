# Factory Brain — Cross-Project Learning System

The Factory Brain is the factory's long-term memory. It learns from every project generated, accumulates patterns that work, and identifies improvements needed.

---

## How It Works

```
Project Generated → Lessons Captured → Patterns Extracted → Factory Improved
```

1. **After every project handoff**, the Orchestrator writes a lessons file
2. **Periodically**, a Brain Agent reviews lessons and extracts learnings
3. **Patterns that work** get added to `patterns/`
4. **Improvements needed** get queued in `improvements/queue.md`
5. **Skills get updated** when recurring gaps are identified

---

## Directory Structure

```
brain/
├── BRAIN.md              # This file — how the brain works
├── patterns/             # Battle-tested solutions indexed by problem type
│   ├── INDEX.md          # Pattern index with quick lookup
│   ├── auth.md           # Authentication patterns
│   ├── file-uploads.md   # File upload patterns
│   ├── realtime.md       # WebSocket/real-time patterns
│   ├── background-jobs.md # Worker/queue patterns
│   └── multi-tenancy.md  # Multi-tenant patterns
├── lessons/              # Post-project learnings
│   └── [project-slug].md # One file per completed project
├── metrics/              # Success tracking
│   └── registry.json     # All generated projects with outcomes
└── improvements/         # Factory improvement queue
    └── queue.md          # Pending improvements from real usage
```

---

## Lesson Capture (Orchestrator Responsibility)

After every project handoff (Phase 7 complete), the Orchestrator MUST write `brain/lessons/[project-slug].md`:

```markdown
# Lessons: [Project Name]

**Project**: [name]
**Completed**: [ISO date]
**Stack**: [backend] + [frontend] + [mobile] + [database] + [infra]
**Duration**: [hours from intake approval to handoff]

---

## What Went Well

- [Pattern/approach that worked smoothly]
- [Tool/library that exceeded expectations]

## Blockers Encountered

| Blocker | Resolution | Time Lost |
|---|---|---|
| [description] | [how it was fixed] | [hours] |

## Patterns Invented

If you had to create a pattern that wasn't in existing skills:

- **Pattern name**: [name]
- **Problem it solves**: [description]
- **Files created**: [list]
- **Should this become a skill?**: yes/no
- **Pattern code snippet**: (paste the key pattern here)

## Review Findings

From REVIEW.md:
- CRITICALs found: [count]
- CRITICALs that required significant rework: [list]
- WARNINGs deferred to issues: [count]

## Suggestions for Factory

- [Anything that should be added/changed in the factory based on this project]

## Metrics

- Total commits: [N]
- Lines of code generated: [N]
- CI/CD runs before green: [N]
- Human interventions required: [N]
```

---

## Pattern Library

`patterns/` contains battle-tested solutions. Unlike `skills/` (which are tool-specific), patterns are problem-specific.

### When to Add a Pattern

Add a pattern when:
- The same problem was solved 2+ times across different projects
- The solution is non-obvious (not just "read the docs")
- Future projects will likely need the same solution

### Pattern File Format

```markdown
# Pattern: [Name]

**Problem**: [One sentence describing the problem this solves]
**Applies to**: [Stack combinations where this works]
**Last validated**: [Date and stack versions]

---

## Solution

[Explanation of the approach]

### Backend Implementation

```javascript
// Code snippet
```

### Frontend Implementation

```typescript
// Code snippet
```

### Mobile Implementation

```dart
// Code snippet
```

---

## Gotchas

- [Common mistake #1]
- [Common mistake #2]

## See Also

- `skills/stack/[related].md`
- `stacks/[layer]/[related].md`
```

---

## Brain Agent (Periodic Review)

The Brain Agent runs periodically (manually triggered or via cron) to:

1. **Scan `lessons/`** for unprocessed lessons (check `metrics/registry.json` for `"brain_processed": false`)

2. **Extract recurring themes**:
   - Same blocker in 2+ projects → create a skill or pattern
   - Same suggestion in 2+ projects → add to improvements queue
   - Same CRITICAL finding in 2+ projects → update security checklist

3. **Update pattern library**:
   - If a lesson contains "Patterns Invented" with `should_become_skill: yes` → create the pattern file
   - If an existing pattern was used successfully → update "Last validated" date

4. **Update improvement queue**:
   - Add new items from lesson suggestions
   - Prioritize by frequency (items mentioned in multiple lessons = higher priority)

5. **Mark lessons as processed**:
   - Update `metrics/registry.json` with `"brain_processed": true`

---

## Metrics Registry

`metrics/registry.json` tracks all generated projects:

```json
{
  "projects": [
    {
      "slug": "project-slug",
      "name": "Project Name",
      "completed": "2026-03-20T15:00:00Z",
      "stack": {
        "backend": "nodejs-express",
        "frontend": "react-shadcn",
        "mobile": "flutter-riverpod",
        "database": "postgresql-rds",
        "infra": "aws-ecs-fargate"
      },
      "metrics": {
        "duration_hours": 4.5,
        "commits": 47,
        "lines_of_code": 12500,
        "ci_runs_to_green": 3,
        "human_interventions": 2,
        "criticals_found": 1,
        "criticals_reworked": 1
      },
      "health_check_url": "https://api.example.com/health",
      "brain_processed": false,
      "lesson_file": "brain/lessons/project-slug.md"
    }
  ],
  "totals": {
    "projects_completed": 1,
    "avg_duration_hours": 4.5,
    "avg_criticals": 1,
    "patterns_extracted": 0,
    "skills_created": 0
  }
}
```

---

## Improvement Queue

`improvements/queue.md` is the factory's backlog:

```markdown
# Factory Improvement Queue

Items are added from lesson analysis. Priority = frequency (how many projects mentioned this).

---

## High Priority (3+ mentions)

- [ ] **[Improvement]** — mentioned in: [project1], [project2], [project3]

## Medium Priority (2 mentions)

- [ ] **[Improvement]** — mentioned in: [project1], [project2]

## Low Priority (1 mention)

- [ ] **[Improvement]** — mentioned in: [project1]

---

## Completed

- [x] **[Improvement]** — completed [date], implemented in [commit/file]
```

---

## Integration with Generation Workflow

Update `workflows/GENERATION.md` Phase 7 to include:

```
7.4 Write lessons file
    - Create brain/lessons/[project-slug].md following brain/BRAIN.md template
    - Update brain/metrics/registry.json with new project entry
    - Set brain_processed: false (Brain Agent will process later)
```

---

## Brain Agent Trigger

The Brain Agent can be triggered:

1. **Manually**: "Run brain analysis" → Orchestrator spawns Brain Agent
2. **After N projects**: When `registry.json` has N unprocessed projects (configurable, default 3)
3. **Weekly**: Via GitHub Actions cron (see `brain/brain-review.yml`)

---

## Privacy Note

Lesson files should NOT contain:
- Actual secrets or credentials
- Customer data or PII
- Proprietary business logic details

Keep lessons focused on technical patterns and process improvements.
