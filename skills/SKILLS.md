# Skills Index — Master Reference

Two categories: general agent skills (OpenClaw library) and stack-specific technical guides.

---

## General Agent Skills (OpenClaw Library)

These are meta-skills that govern how agents behave. Read the relevant one before starting major work.

| Skill | When to use | Path |
|---|---|---|
| `writing-plans` | Before any multi-step task — write the plan first | `~/.agents/skills/writing-plans/SKILL.md` |
| `systematic-debugging` | Before any bug fix — diagnose before fixing | `~/.agents/skills/systematic-debugging/SKILL.md` |
| `verification-before-completion` | Before any commit — run checks, show evidence | `~/.agents/skills/verification-before-completion/SKILL.md` |
| `dispatching-parallel-agents` | Backend/admin/mobile are independent — spawn in parallel | `~/.agents/skills/dispatching-parallel-agents/SKILL.md` |
| `github` | CI/CD monitoring, PR status, issue creation | `~/.npm-global/lib/node_modules/openclaw/skills/github/SKILL.md` |
| `github-actions-generator` | Writing or modifying CI/CD workflows | `~/.openclaw/workspace/skills/github-actions-generator/SKILL.md` |
| `database-operations` | SQL design, migrations, index optimization | `~/.openclaw/workspace/skills/database-operations/SKILL.md` |
| `cloudflare` | DNS management, Pages deployment, API operations | `~/.openclaw/workspace/skills/cloudflare-integration/SKILL.md` |
| `domain-dns-ops` | Domain setup, nameserver changes, subdomain config | `~/.openclaw/workspace/skills/domain-dns-ops/SKILL.md` |
| `brainstorming` | Before any new feature design — explore options first | `~/.agents/skills/brainstorming/SKILL.md` |

---

## Stack-Specific Technical Skills

These are deep technical guides for specific tools. Every implementer must read the relevant one before starting.

### Backend Skills

| Skill file | Covers | Read when |
|---|---|---|
| `skills/stack/express5.md` | Express 5 patterns, async errors, ESM | Writing any backend route or middleware |
| `skills/stack/zod.md` | Schema validation patterns, refinements | Adding any input validation |
| `skills/general/jwt-auth.md` | JWT implementation, refresh flow | Building auth system |
| `skills/general/secrets-management.md` | Secrets Manager patterns | Handling any credentials |
| `skills/general/error-handling.md` | Centralized error patterns | Setting up error handling |
| `skills/general/api-design.md` | REST conventions, response formats | Designing any new endpoint |

### Frontend Skills

| Skill file | Covers | Read when |
|---|---|---|
| `skills/stack/tailwindcss4.md` | TailwindCSS 4 migration, CSS-native config | Any admin frontend work |
| `skills/stack/shadcn.md` | shadcn/ui patterns, forms, tables | Building admin UI components |
| `skills/stack/react-query.md` | TanStack Query patterns, caching | Data fetching in admin |

### Mobile Skills

| Skill file | Covers | Read when |
|---|---|---|
| `skills/stack/riverpod.md` | Provider types, state patterns, testing | Any Flutter state management |
| `skills/stack/go_router.md` | Navigation, auth redirect, deep linking | Any Flutter routing |

### Infrastructure Skills

| Skill file | Covers | Read when |
|---|---|---|
| `skills/stack/opentofu.md` | Module patterns, state, secrets | Any infrastructure changes |
| `skills/stack/github-actions.md` | CI/CD pipeline patterns | Any workflow changes |

---

## Skill Reading Rules

1. **Read the skill before starting the work** — not after running into a problem
2. **One skill per task** — pick the most specific one
3. **Skills document patterns** — if your implementation looks nothing like the skill, you're probably guessing
4. **Supplement, don't replace** — skills don't replace reading existing project code; do both

---

## Adding New Skills

When you encounter a recurring pattern that isn't documented:

1. Write it as a new skill file in `skills/stack/` or `skills/general/`
2. Include: common patterns (with code), anti-patterns (with code), debugging tips
3. Add it to this index
4. Reference it in the appropriate stack file

Good skills candidates:
- Patterns you had to figure out through trial and error
- Gotchas that caught you (or could have caught you)
- Patterns that differ significantly from "obvious" implementations
