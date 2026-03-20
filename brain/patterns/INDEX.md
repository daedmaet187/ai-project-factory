# Pattern Index

Quick lookup for common problems. Each pattern has a dedicated file with full implementation details.

---

## By Problem Type

| Problem | Pattern | File |
|---|---|---|
| User authentication with JWT | JWT Auth Flow | `auth.md` |
| Refresh token rotation | Secure Token Refresh | `auth.md` |
| Role-based access control | RBAC Middleware | `auth.md` |
| File upload to S3 | Presigned URL Upload | `file-uploads.md` |
| Image resizing on upload | Lambda Image Processor | `file-uploads.md` |
| Real-time notifications | WebSocket + Redis PubSub | `realtime.md` |
| Live data updates | Server-Sent Events | `realtime.md` |
| Background job processing | BullMQ + Redis | `background-jobs.md` |
| Scheduled tasks | ECS Scheduled Tasks | `background-jobs.md` |
| Multi-tenant data isolation | Row-Level Security | `multi-tenancy.md` |
| Tenant-specific subdomains | Dynamic Routing | `multi-tenancy.md` |

---

## By Stack

### Node.js/Express Patterns
- `auth.md` — JWT, refresh tokens, RBAC
- `file-uploads.md` — S3 presigned URLs, multipart handling
- `realtime.md` — Socket.io integration
- `background-jobs.md` — BullMQ workers

### Flutter Patterns
- `auth.md` — Secure token storage, auto-refresh
- `realtime.md` — WebSocket provider, StreamBuilder patterns
- `file-uploads.md` — Image picker + upload progress

### React/Admin Patterns
- `auth.md` — Auth context, protected routes
- `realtime.md` — useWebSocket hook, optimistic updates
- `file-uploads.md` — Drag-drop upload component

---

## Recently Updated

| Pattern | Last Updated | Validated With |
|---|---|---|
| — | — | — |

(This section auto-populates as patterns are validated)
