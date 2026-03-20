# Mobile Stack: React Native + Expo

Use when: team prefers JavaScript/TypeScript, or rapid prototyping is priority.

---

## When to Choose React Native vs Flutter

| Scenario | React Native + Expo | Flutter |
|---|---|---|
| JS/TS team | ✅ | ❌ |
| Rapid prototype | ✅ Expo Go | ❌ Requires build |
| Custom native UI (pixel-perfect) | ❌ | ✅ |
| Performance-critical animations | ❌ | ✅ |
| Existing React web code to share | ✅ | ❌ |
| Long-term maintenance | ✅ Large community | ✅ Strong community |

---

## Project Structure

```
app/
├── _layout.tsx             ← Expo Router root layout
├── (auth)/
│   └── login.tsx
├── (tabs)/
│   ├── _layout.tsx         ← Tab navigation
│   ├── index.tsx           ← Home tab
│   └── profile.tsx         ← Profile tab
components/
├── [feature]/
└── ui/                     ← Reusable UI components
hooks/
├── useAuth.ts
└── use[Feature].ts
lib/
├── api.ts                  ← Axios/fetch wrapper
└── storage.ts              ← expo-secure-store wrapper
```

---

## Key Setup

```bash
# Create project
npx create-expo-app --template

# Required packages
npx expo install expo-router expo-secure-store @tanstack/react-query axios
```

---

## Auth Token Storage

```typescript
// lib/storage.ts
import * as SecureStore from 'expo-secure-store'

// ALWAYS use SecureStore — never AsyncStorage for tokens
export const tokenStorage = {
  get: (key: string) => SecureStore.getItemAsync(key),
  set: (key: string, value: string) => SecureStore.setItemAsync(key, value),
  delete: (key: string) => SecureStore.deleteItemAsync(key),
}
```

---

## Navigation with Expo Router

Expo Router uses file-based routing (same concept as Next.js). Use `router.push('/path')` or `<Link href="/path">`.

```typescript
// ❌ WRONG — React Navigation imperative
navigation.navigate('Profile')

// ✅ CORRECT — Expo Router
import { router } from 'expo-router'
router.push('/profile')
```

---

## Key Differences from Flutter

| Concept | React Native | Flutter |
|---|---|---|
| State management | Zustand / Jotai | Riverpod |
| Navigation | Expo Router | go_router |
| Secure storage | expo-secure-store | flutter_secure_storage |
| HTTP client | axios / fetch | Dio |
| Code generation | tRPC / orval | freezed / json_serializable |

---

**Note**: Expo EAS Build is required for production builds (iOS requires signing certs). Configure in `eas.json`.
