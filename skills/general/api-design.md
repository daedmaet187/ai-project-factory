# API Design — REST Conventions

All backend APIs follow these conventions. Every new endpoint must conform.

---

## URL Structure

```
/api/[resource]                    GET (list), POST (create)
/api/[resource]/:id                GET (read), PATCH (update), DELETE (remove)
/api/[resource]/:id/[sub-resource] Nested resource
```

**Rules**:
- Lowercase and hyphenated: `/api/user-profiles` not `/api/userProfiles`
- Plural nouns: `/api/users` not `/api/user`
- No verbs in URLs: `/api/users/:id` not `/api/getUser/:id`
- No file extensions: `/api/users` not `/api/users.json`

---

## HTTP Methods

| Method | Use for | Success code | Body |
|---|---|---|---|
| GET | Read (list or single) | 200 | No body |
| POST | Create | 201 | Resource data |
| PATCH | Partial update | 200 | Changed fields only |
| PUT | Full replace | 200 | Complete resource |
| DELETE | Remove | 204 | No body |

---

## Response Format

### Success responses

```json
// GET /api/users — list
{
  "users": [...],
  "total": 47,
  "limit": 20,
  "offset": 0
}

// GET /api/users/:id — single resource
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "user",
  "createdAt": "2024-01-15T10:00:00Z"
}

// POST /api/users — created resource
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "user",
  "createdAt": "2024-01-15T10:00:00Z"
}
```

**Rules**:
- camelCase field names
- ISO 8601 timestamps (with timezone `Z`)
- UUIDs as strings
- Boolean fields explicit: `isActive` not `active`
- Nested resources only one level deep in list responses

### Error responses

```json
// 400 Validation error
{
  "error": "Validation failed",
  "code": "VALIDATION_ERROR",
  "details": {
    "email": ["Invalid email address"],
    "password": ["Too short"]
  }
}

// 404 Not found
{
  "error": "User not found",
  "code": "NOT_FOUND"
}

// 401 Unauthorized
{
  "error": "Unauthorized"
}

// 500 Server error (never expose internals)
{
  "error": "Internal server error"
}
```

---

## Pagination

All list endpoints support pagination:

```
GET /api/users?limit=20&offset=0
GET /api/habits?limit=50&offset=100&sort=desc&search=morning
```

Standard query params:
- `limit`: max items returned (1–100, default 20)
- `offset`: skip N items (default 0)
- `sort`: `asc` or `desc` (default `desc` — newest first)
- `search`: text search on relevant fields

Response always includes `total`:
```json
{ "users": [...], "total": 237, "limit": 20, "offset": 0 }
```

---

## Filtering

Use query parameters for filtering. Keep it simple.

```
GET /api/users?role=admin
GET /api/habits?userId=uuid&completed=true
```

Avoid complex filter syntax at the URL level. If filtering becomes complex, use POST with a filter body to a separate endpoint:

```
POST /api/habits/search
{ "filters": { "tags": ["morning", "health"], "streak_min": 7 } }
```

---

## Versioning

If breaking changes are needed, version at the URL level:

```
/api/v1/users
/api/v2/users
```

Start with `/api/` (no version) for v1. Add `/api/v2/` only when breaking changes are needed.

**Do not** version with headers or query params — harder to test and debug.

---

## Common Mistakes

```
❌ GET /api/deleteUser/123       (verb in URL)
✅ DELETE /api/users/123

❌ POST /api/user/update/123     (verb in URL, singular resource)
✅ PATCH /api/users/123

❌ GET /api/users/123/getHabits  (verb in URL)
✅ GET /api/users/123/habits

❌ POST /api/users/123           (wrong method for update)
✅ PATCH /api/users/123

❌ { "success": true, "data": { "user": {...} } }  (unnecessary wrapper)
✅ { "id": "...", "email": "..." }  (direct resource)
```

---

## Health Check Endpoint

Every service must have:

```
GET /health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:00:00Z",
  "version": "1.0.0"
}
```

This endpoint:
- Is not behind auth middleware
- Returns 200 if healthy
- Returns 503 if unhealthy (DB unreachable, etc.)
- Is polled by ECS health checks and Cloudflare health monitoring
