# TailwindCSS 4 — Migration and Usage Guide

TailwindCSS 4 is a complete rewrite with CSS-native configuration. Read this before any frontend styling work.

---

## What's Different in v4

| v3 | v4 |
|---|---|
| `tailwind.config.js` | No config file — CSS-native |
| `@tailwind base/components/utilities` | `@import "tailwindcss"` |
| `theme.extend.colors` in JS | `@theme { --color-name: value }` in CSS |
| PostCSS plugin | Vite plugin (faster) |
| `tailwindcss/colors` import | Not needed — define your own |
| JIT mode (default in v3) | Always JIT |

---

## Installation (Vite)

```bash
npm install tailwindcss @tailwindcss/vite
```

```typescript
// vite.config.ts
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
})
```

**No `postcss.config.js` needed** — the Vite plugin replaces it.

---

## index.css — The New Config

```css
/* ONLY this import — replaces the three @tailwind directives */
@import "tailwindcss";

/* Theme customization */
@theme {
  /* Colors — use CSS custom properties */
  --color-primary: #6366F1;
  --color-primary-foreground: #FFFFFF;
  --color-secondary: #8B5CF6;
  --color-accent: #F59E0B;
  
  /* These become Tailwind utility classes automatically: */
  /* bg-primary, text-primary, border-primary, etc. */
  
  /* Full neutral scale */
  --color-background: #FFFFFF;
  --color-foreground: #0F172A;
  --color-muted: #F1F5F9;
  --color-muted-foreground: #64748B;
  --color-border: #E2E8F0;
  
  /* Semantic colors */
  --color-destructive: #EF4444;
  --color-success: #22C55E;
  --color-warning: #F59E0B;
  
  /* Typography */
  --font-sans: 'Inter', ui-sans-serif, system-ui;
  --font-mono: 'JetBrains Mono', ui-monospace;
  
  /* Border radius — accessible as rounded-{size} */
  --radius: 0.5rem;
  --radius-sm: 0.25rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
}

/* Dark mode variant */
@custom-variant dark (&:is(.dark *));
```

---

## Dark Mode

```css
/* In index.css — define custom variant */
@custom-variant dark (&:is(.dark *));
```

```typescript
// Toggle dark mode in React
document.documentElement.classList.toggle('dark')

// Usage in components
<div className="bg-background dark:bg-zinc-950 text-foreground dark:text-zinc-100">
```

---

## shadcn/ui Compatibility

shadcn/ui uses CSS custom properties with specific naming. The compatibility mapping:

```css
@theme {
  /* shadcn/ui expects these specific variable names */
  --background: 0 0% 100%;          /* ← shadcn uses HSL format */
  --foreground: 222.2 84% 4.9%;
  --primary: 221.2 83.2% 53.3%;
  --primary-foreground: 210 40% 98%;
  --secondary: 210 40% 96.1%;
  --secondary-foreground: 222.2 47.4% 11.2%;
  --muted: 210 40% 96.1%;
  --muted-foreground: 215.4 16.3% 46.9%;
  --accent: 210 40% 96.1%;
  --accent-foreground: 222.2 47.4% 11.2%;
  --destructive: 0 84.2% 60.2%;
  --destructive-foreground: 210 40% 98%;
  --border: 214.3 31.8% 91.4%;
  --input: 214.3 31.8% 91.4%;
  --ring: 221.2 83.2% 53.3%;
  --radius: 0.5rem;
  
  /* Dark mode */
  --dark-background: 222.2 84% 4.9%;
  /* etc. */
}
```

**Note**: shadcn/ui uses HSL format. When generating from hex design tokens, convert:
```javascript
// Convert hex to HSL CSS variable string
import { parse, formatHsl } from 'culori'
const hsl = formatHsl(parse('#6366F1'))  // "hsl(239 84% 67%)"
// Extract just the components: "239 84% 67%"
```

---

## Utility Classes — All v3 Classes Still Work

```html
<!-- Spacing, sizing, layout — unchanged from v3 -->
<div class="flex items-center gap-4 p-6 mx-auto max-w-7xl">

<!-- Colors — now use your custom color names -->
<button class="bg-primary text-primary-foreground hover:bg-primary/90 px-4 py-2 rounded-lg">

<!-- Responsive — unchanged -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">

<!-- Dark mode — with your @custom-variant -->
<div class="bg-background dark:bg-zinc-900 text-foreground">

<!-- Arbitrary values — still work -->
<div class="w-[42rem] top-[117px]">
```

---

## Typography with Custom Fonts

```css
/* In index.css — after @import */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

@theme {
  --font-sans: 'Inter', ui-sans-serif, system-ui;
}
```

Or self-host:
```css
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url('/fonts/inter.woff2') format('woff2');
}
```

---

## Anti-Patterns

```javascript
// ❌ WRONG — tailwind.config.js doesn't work in v4
// Don't create this file

// ❌ WRONG — old import syntax
// @tailwind base;
// @tailwind components;
// @tailwind utilities;

// ✅ CORRECT — single import
// @import "tailwindcss";

// ❌ WRONG — postcss plugin (v3 style)
// postcss.config.js: { plugins: { tailwindcss: {} } }

// ✅ CORRECT — Vite plugin only
// vite.config.ts: plugins: [tailwindcss()]

// ❌ WRONG — defining colors in vite.config.ts
// No theme() function in v4

// ✅ CORRECT — CSS custom properties in @theme {}
```

---

## Common v4 Issues

### Issue: Classes not applying
Check: Is `@import "tailwindcss"` the first line in your CSS?  
Check: Is `@tailwindcss/vite` plugin added in `vite.config.ts`?

### Issue: shadcn/ui components look unstyled
Check: shadcn expects HSL format CSS variables — not hex. Convert colors.

### Issue: Custom font not loading
Check: Font import must be before or inside `@import "tailwindcss"` scope.

### Issue: Dark mode not working
Check: `@custom-variant dark` defined? HTML root has `.dark` class?
