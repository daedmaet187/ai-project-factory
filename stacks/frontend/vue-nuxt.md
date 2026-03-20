# Frontend Stack: Vue 3 + Nuxt 4

Use when: team prefers Vue, or existing Vue codebase to integrate with.

---

## When to Choose Vue/Nuxt

- Team has Vue expertise
- Migrating from Vue 2/Nuxt 2 project
- Preference for Options API or Composition API with `<script setup>`
- Need Nuxt's built-in SSR without Next.js

**Otherwise**: React + Vite or Next.js has more ecosystem support, more shadcn/ui-equivalent components, and broader hiring market.

---

## Project Structure

```
nuxt.config.ts
app.vue
pages/
├── index.vue
├── login.vue
└── users/
    ├── index.vue
    └── [id].vue
components/
└── [feature]/
composables/
├── useAuth.ts
└── useUsers.ts
server/
└── api/           ← Nuxt server routes (if not using separate backend)
```

---

## nuxt.config.ts

```typescript
export default defineNuxtConfig({
  modules: ['@nuxtjs/tailwindcss', '@pinia/nuxt', '@nuxt/ui'],
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_URL
    }
  }
})
```

---

## Composable Pattern (equivalent to React hooks)

```typescript
// composables/useUsers.ts
export function useUsers() {
  const { data, pending, error } = useFetch('/api/users', {
    baseURL: useRuntimeConfig().public.apiBase
  })
  return { users: data, loading: pending, error }
}
```

---

## Key Differences from React

| Concept | Vue/Nuxt | React/Next |
|---|---|---|
| State management | Pinia | Zustand / Redux |
| Data fetching | useFetch (Nuxt) | TanStack Query |
| Component style | `<script setup>` SFC | JSX/TSX |
| Routing | file-based (Nuxt) | App Router (Next) or React Router |
| UI components | Nuxt UI | shadcn/ui |

---

**Note**: This stack is supported but has fewer patterns documented in this factory. If detailed guidance is needed beyond this file, write an ADR and reference external docs.
