# Project: [NAME]

Generated: [DATE]  
Orchestrator: [agent model]  
Factory version: ai-project-factory @ [commit]

---

## Brief

| Field | Value |
|---|---|
| **Name** | [project name] |
| **Slug** | [lowercase-hyphen-slug] |
| **Purpose** | [one-line description] |
| **Audience** | [target audience] |
| **Language** | [primary user language] |

### Core Features
1. [feature 1]
2. [feature 2]
3. [feature 3]
4. [feature 4]
5. [feature 5]

### User Roles
- `user`: [description]
- `admin`: [description]
- `[role]`: [description]

### Auth
- Method: Email + password
- Tokens: JWT (15m access, 7d refresh)

### Real-time
- [ ] None required
- [ ] WebSockets (describe)
- [ ] Server-Sent Events (describe)

### File Uploads
- [ ] None
- [ ] Images only
- [ ] Documents
- [ ] Any type

### Third-party Integrations
- [service]: [purpose]

---

## Stack Selected

| Layer | Technology | Reason |
|---|---|---|
| **Backend** | [e.g., Node.js + Express 5] | [brief justification] |
| **Admin** | [e.g., React 19 + Vite + shadcn/ui] | |
| **Mobile** | [e.g., Flutter + Riverpod] | [or "N/A"] |
| **Database** | [e.g., PostgreSQL 16 on RDS] | |
| **Container** | [e.g., AWS ECR + ECS Fargate] | |
| **DNS/CDN** | [e.g., Cloudflare] | |
| **Admin deploy** | [e.g., Cloudflare Pages] | |
| **Infra as code** | OpenTofu | Default |
| **CI/CD** | GitHub Actions | Default |
| **Secrets** | AWS Secrets Manager | Default |

Stack combo: [Full-stack Mobile / Web-only SaaS / Edge-first]

---

## Design

| Field | Value |
|---|---|
| **Primary color** | [hex or "generated"] |
| **Secondary color** | [hex or "generated"] |
| **Accent color** | [hex or "generated"] |
| **Style** | [description from Q-023] |
| **Typography** | [font family] |
| **Dark mode** | [Required / Optional / No] |
| **Figma file** | [URL or "N/A"] |

---

## Infrastructure

| Field | Value |
|---|---|
| **AWS Region** | [e.g., us-east-1] |
| **Scale tier** | [MVP / Growth / Enterprise] |
| **Budget tier** | [Minimal / Standard / Production] |
| **Staging env** | [Yes / No] |

---

## Domain

| Field | Value |
|---|---|
| **Domain** | [example.com] |
| **API URL** | https://api.[domain] |
| **Admin URL** | https://admin.[domain] |
| **App URL** | https://app.[domain] |
| **DNS provider** | Cloudflare |
| **www redirect** | [www → apex / apex → www / None] |

---

## Repository

| Field | Value |
|---|---|
| **GitHub org/user** | [github-username-or-org] |
| **Repo name** | [project-slug] |
| **Visibility** | Private |
| **Branch protection** | PR required, CI must pass |

---

## Timeline Estimate

| Phase | Description | Duration |
|---|---|---|
| 0 | Repository setup | ~5 min |
| 1 | Design system | ~10 min |
| 2 | Infrastructure | ~20 min |
| 3 | Implementation (parallel) | ~45 min |
| 4 | Code review | ~15 min |
| 5 | Database migrations | ~5 min |
| 6 | CI/CD verification | ~15 min |
| 7 | Handoff | ~5 min |
| **Total** | | **~2 hours** |

---

## Approval

```
[ ] Human has read and understood this plan
[ ] Stack selection is accepted
[ ] Domain and subdomain structure is confirmed
[ ] Timeline is acceptable
[ ] Human types "approved" to start generation
```

**Status**: ⏳ Awaiting approval
