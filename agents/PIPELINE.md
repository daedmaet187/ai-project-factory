# Agent Pipeline — Handoff Protocol

This document defines the exact file formats agents use to communicate. Use these formats exactly — deviation breaks the pipeline.

---

## Overview

```
Orchestrator writes plan → Implementer reads and executes → writes results
Orchestrator reads results → writes review request → Reviewer reads and reviews → writes review
Orchestrator reads review → acts (fix loop or accept)
```

All files live in `plans/` in the **project root** (not this factory repo).

---

## Plan File Format

**Written by**: Orchestrator  
**Read by**: Implementer (or Infra Agent)  
**Filename**: `plans/[layer]-[feature].plan.md`  
**Example**: `plans/backend-auth.plan.md`

```markdown
# Implementation Plan: [descriptive task name]

**Agent**: Implementer / Infra Agent
**Layer**: backend / admin / mobile / infra
**Priority**: Can run parallel with [other task] / Must run after [other task]
**Created**: [ISO timestamp]

---

## Context

[1–3 sentences explaining why this task exists and what it enables.
Example: "This task creates the JWT authentication system. All other protected
endpoints depend on the auth middleware created here."]

---

## Files to Read First

Before writing any code, read these files completely:

- `src/routes/users.js` — existing route pattern to follow
- `src/middleware/rateLimiter.js` — how rate limiting is applied
- `skills/stack/express5.md` — Express 5 async error handling
- `skills/stack/zod.md` — input validation patterns
- `skills/general/jwt-auth.md` — JWT implementation pattern

---

## Task Description

[Precise, unambiguous description. If something can be interpreted two ways, resolve it here.]

Create the authentication system with these endpoints:

1. `POST /api/auth/register` — create new user account
   - Body: `{ email: string, password: string, name: string }`
   - Returns: `{ user: UserObject, accessToken: string, refreshToken: string }`
   - Error: 409 if email already exists

2. `POST /api/auth/login` — authenticate existing user
   - Body: `{ email: string, password: string }`
   - Returns: `{ user: UserObject, accessToken: string, refreshToken: string }`
   - Error: 401 if credentials invalid

3. `POST /api/auth/refresh` — get new access token using refresh token
   - Body: `{ refreshToken: string }`
   - Returns: `{ accessToken: string }`

4. `POST /api/auth/logout` — invalidate refresh token
   - Requires: valid access token in Authorization header
   - Returns: `{ success: true }`

Create auth middleware at `src/middleware/auth.js`:
- Validates JWT in Authorization header
- Attaches `req.user` with `{ id, email, role }`
- Returns 401 if token missing or invalid

---

## Pattern Reference

Follow the exact same pattern as `src/routes/users.js` for:
- Route file structure
- Error handling
- Response format
- Middleware application

For JWT implementation, follow `skills/general/jwt-auth.md`.

---

## Acceptance Criteria

- [ ] POST /api/auth/register creates user and returns tokens
- [ ] POST /api/auth/login returns tokens for valid credentials
- [ ] POST /api/auth/login returns 401 for invalid credentials
- [ ] POST /api/auth/refresh returns new access token
- [ ] POST /api/auth/logout invalidates refresh token
- [ ] Auth middleware attaches req.user for valid tokens
- [ ] Auth middleware returns 401 for missing/invalid tokens
- [ ] All request bodies validated with Zod schemas
- [ ] Passwords hashed with bcrypt (cost factor 12)
- [ ] Access token TTL: 15 minutes
- [ ] Refresh token TTL: 7 days
- [ ] No secrets hardcoded (JWT_SECRET from process.env, sourced from Secrets Manager)

---

## Files to Create/Modify

| File | Action | Description |
|---|---|---|
| `src/routes/auth.js` | Create | Auth route handlers |
| `src/schemas/auth.js` | Create | Zod validation schemas |
| `src/middleware/auth.js` | Create | JWT validation middleware |
| `src/routes/index.js` | Modify | Register auth router at /api/auth |

---

## Verification Commands

Run these exactly. Confirm actual output matches expected.

```bash
# Server must start
node src/index.js &
sleep 2

# Health check
curl -s http://localhost:3000/health | jq '.status'
# Expected: "ok"

# Register new user
curl -s -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!","name":"Test User"}' | jq '.accessToken'
# Expected: non-null string (JWT)

# Login with same credentials
curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!"}' | jq '.user.email'
# Expected: "test@example.com"

# Login with wrong password → 401
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"wrong"}'
# Expected: 401

# Lint
npm run lint
# Expected: exit 0
```

---

## Commit Message

```
feat(backend): add JWT authentication system

- POST /api/auth/register, /login, /refresh, /logout endpoints
- JWT middleware with req.user attachment
- Zod validation on all auth request bodies
- bcrypt password hashing (cost factor 12)
- Access token TTL: 15m, refresh token TTL: 7d
```
```

---

## Results File Format

**Written by**: Implementer (or Infra Agent)  
**Read by**: Orchestrator  
**Filename**: `plans/[layer]-[feature].results.md`

```markdown
# Implementation Results: [task name]

**Status**: DONE / BLOCKED / PARTIAL
**Commit**: [full commit hash]
**Branch**: [branch name]
**Completed**: [ISO timestamp]

---

## Changes Made

| File | Action | Description |
|---|---|---|
| `src/routes/auth.js` | Created | Auth route handlers (register, login, refresh, logout) |
| `src/schemas/auth.js` | Created | Zod schemas for all auth request bodies |
| `src/middleware/auth.js` | Created | JWT validation middleware |
| `src/routes/index.js` | Modified | Registered auth router at /api/auth |

---

## Verification Results

| Command | Expected | Actual | Pass? |
|---|---|---|---|
| `curl /health \| jq '.status'` | `"ok"` | `"ok"` | ✅ |
| Register → jq '.accessToken' | non-null JWT | `"eyJhbG..."` | ✅ |
| Login wrong password → HTTP status | `401` | `401` | ✅ |
| `npm run lint` | exit 0 | exit 0 | ✅ |

---

## Acceptance Criteria

- [x] POST /api/auth/register creates user and returns tokens
- [x] POST /api/auth/login returns tokens for valid credentials
- [x] POST /api/auth/login returns 401 for invalid credentials
- [x] POST /api/auth/refresh returns new access token
- [x] POST /api/auth/logout invalidates refresh token
- [x] Auth middleware attaches req.user for valid tokens
- [x] Auth middleware returns 401 for missing/invalid tokens
- [x] All request bodies validated with Zod schemas
- [x] Passwords hashed with bcrypt (cost factor 12)

---

## Notes

[Anything the Orchestrator should know that wasn't in the plan]

- Used `jsonwebtoken` v9 (already in package.json from previous session)
- Refresh token stored in `refresh_tokens` DB table (created migration 003_refresh_tokens.sql)
- Logout endpoint soft-invalidates by deleting the refresh token record
```

If BLOCKED:

```markdown
# Implementation Results: [task name]

**Status**: BLOCKED
**Blocked at**: [specific location]
**Completed**: [ISO timestamp]

---

## Blocker Description

[Clear explanation of what the problem is and why it prevents continuing]

---

## What Was Completed Before Blocking

- [x] src/routes/auth.js: created with register and login endpoints
- [ ] src/middleware/auth.js: NOT created — blocked here

---

## What Is Needed to Unblock

Option A: [description of what Orchestrator can do to unblock]
Option B: [alternative approach]

---

## No Changes Committed

[Or: "Partial work committed on branch [name], not merged"]
```

---

## Review Request Format

**Written by**: Orchestrator  
**Read by**: Reviewer  
**Filename**: `plans/[layer]-[feature].review-request.md`

```markdown
# Review Request: [layer/feature]

**Reviewer**: Reviewer Agent
**Layer**: backend / admin / mobile

## What to Review

- Plans completed: plans/backend-auth.plan.md, plans/backend-users.plan.md
- Commits to review: [commit range or list of commits]
- Files changed:
  - src/routes/auth.js
  - src/routes/users.js
  - src/middleware/auth.js
  - src/schemas/

## Focus Areas

[Optional: specific concerns the Orchestrator wants the Reviewer to prioritize]
- Pay special attention to the JWT refresh token rotation logic
- Verify rate limiting is applied to the login endpoint

## Stack References

- skills/stack/express5.md
- skills/general/jwt-auth.md
- security/CHECKLIST.md

## Output

Write review to: REVIEW.md
```
