# Design Ingestion — Figma to Code

How to convert a Figma design file into usable design tokens for all layers.

There are three methods. Use the first one that applies.

---

## Method 1: Figma API (Recommended — when FIGMA_TOKEN + FIGMA_FILE_KEY provided)

**When to use**: Human provided Figma credentials in ACCESS.md.

**Process**:

1. Orchestrator spawns UI Agent with Figma credentials
2. UI Agent fetches the Figma file via API:

```bash
# Fetch Figma file
curl -s "https://api.figma.com/v1/files/${FIGMA_FILE_KEY}" \
  -H "X-Figma-Token: ${FIGMA_TOKEN}" > figma-file.json

# Fetch styles (colors, typography)
curl -s "https://api.figma.com/v1/files/${FIGMA_FILE_KEY}/styles" \
  -H "X-Figma-Token: ${FIGMA_TOKEN}" > figma-styles.json
```

3. UI Agent extracts design tokens from the response and writes `design-tokens.json`
4. UI Agent generates layer-specific theme files from tokens

**What to extract from Figma JSON**:
- `document.children` → frames and pages
- `styles` → fill styles (colors), text styles (typography)
- Fill styles: extract `color.r, .g, .b` → convert to hex
- Text styles: extract `fontFamily`, `fontSize`, `fontWeight`, `lineHeight`

**Example extraction**:
```python
# Parse fills from styles
for style_id, style in figma_styles.items():
    if style['styleType'] == 'FILL':
        color = style['document']['fills'][0]['color']
        hex_color = '#{:02x}{:02x}{:02x}'.format(
            int(color['r'] * 255),
            int(color['g'] * 255),
            int(color['b'] * 255)
        )
        # Map style name to token: "Primary/500" → primary
```

---

## Method 2: shadcn/ui Theme Config (admin/web only)

**When to use**: Human provided a shadcn/ui theme URL or direct hex palette.

**Input formats**:
- shadcn themes gallery URL → fetch CSS variables from page
- Hex values directly: `primary: #6366F1, secondary: #8B5CF6, accent: #F59E0B`
- Style description: "dark mode first, purple primary, minimal"

**Output**:
```css
/* src/index.css */
@theme {
  --color-primary: oklch(55% 0.2 264);       /* #6366F1 converted */
  --color-primary-foreground: oklch(98% 0 0);
  --color-secondary: oklch(60% 0.15 280);    /* #8B5CF6 */
  --color-accent: oklch(75% 0.18 70);        /* #F59E0B */
}
```

**Converting hex to oklch** (preferred for TailwindCSS 4):
```javascript
// Use this Node.js snippet
import { converter } from 'culori'
const toOklch = converter('oklch')
const result = toOklch('#6366F1')
// → { mode: 'oklch', l: 0.55, c: 0.2, h: 264 }
// Format: oklch(55% 0.2 264)
```

---

## Method 3: Description-Based Generation

**When to use**: No Figma, no palette provided. Human described the style.

UI Agent generates a complete design system from the style description in Q-023.

**Input** (from intake Q-023): `"Clean, minimal, enterprise B2B — navy primary, subtle grays, professional feel"`

**Generation process**:

1. Choose a primary color matching description
2. Derive the full palette using color theory:
   - Primary: navy blue (e.g., `#1E3A5F`)
   - Secondary: medium blue (`#2563EB`)
   - Accent: subtle amber (`#D97706`) — for CTA/highlights
   - Neutral scale: slate grays
   - Semantic: standard success/warning/error

3. Choose typography matching description:
   - Enterprise/professional → Inter or Geist
   - Playful/consumer → Outfit or Nunito
   - Bold/editorial → DM Sans Bold

4. Output design tokens

---

## Token File Format (Source of Truth)

Write this file to `design-tokens.json` in the project root. All layers read from this.

```json
{
  "_meta": {
    "generated": "2024-01-15T10:00:00Z",
    "source": "figma | manual | generated",
    "figmaFile": "abc123def456"
  },
  "colors": {
    "primary": "#6366F1",
    "primaryForeground": "#FFFFFF",
    "secondary": "#8B5CF6",
    "secondaryForeground": "#FFFFFF",
    "accent": "#F59E0B",
    "accentForeground": "#000000",
    "background": "#FFFFFF",
    "foreground": "#0F172A",
    "surface": "#F8FAFC",
    "muted": "#F1F5F9",
    "mutedForeground": "#64748B",
    "border": "#E2E8F0",
    "error": "#EF4444",
    "errorForeground": "#FFFFFF",
    "success": "#22C55E",
    "warning": "#F59E0B"
  },
  "typography": {
    "fontFamily": "Inter",
    "fontFamilyMono": "JetBrains Mono",
    "scale": {
      "xs": 12,
      "sm": 14,
      "base": 16,
      "lg": 18,
      "xl": 20,
      "2xl": 24,
      "3xl": 30,
      "4xl": 36
    },
    "weights": {
      "normal": 400,
      "medium": 500,
      "semibold": 600,
      "bold": 700
    },
    "lineHeight": {
      "tight": 1.25,
      "normal": 1.5,
      "relaxed": 1.75
    }
  },
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 16,
    "lg": 24,
    "xl": 32,
    "2xl": 48,
    "3xl": 64
  },
  "radius": {
    "sm": 4,
    "md": 8,
    "lg": 12,
    "xl": 16,
    "full": 9999
  }
}
```

---

## Flutter ThemeData from Tokens

UI Agent generates this file from `design-tokens.json`:

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
      surface: AppColors.surface,
      onSurface: AppColors.foreground,
      error: AppColors.error,
      onError: AppColors.errorForeground,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400),
      labelMedium: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),  // radius.md
      ),
    ),
  );
}
```

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Generated from design-tokens.json
  static const primary = Color(0xFF6366F1);
  static const primaryForeground = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF8B5CF6);
  static const secondaryForeground = Color(0xFFFFFFFF);
  static const accent = Color(0xFFF59E0B);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8FAFC);
  static const foreground = Color(0xFF0F172A);
  static const muted = Color(0xFFF1F5F9);
  static const mutedForeground = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const error = Color(0xFFEF4444);
  static const errorForeground = Color(0xFFFFFFFF);
  static const success = Color(0xFF22C55E);
}
```

---

## TailwindCSS 4 from Tokens

UI Agent generates the `@theme` block in `src/index.css`:

```css
/* Generated from design-tokens.json */
@theme {
  --color-primary: #6366F1;
  --color-primary-foreground: #FFFFFF;
  --color-secondary: #8B5CF6;
  --color-accent: #F59E0B;
  --color-background: #FFFFFF;
  --color-foreground: #0F172A;
  --color-surface: #F8FAFC;
  --color-muted: #F1F5F9;
  --color-muted-foreground: #64748B;
  --color-border: #E2E8F0;
  --color-destructive: #EF4444;
  --color-success: #22C55E;
  
  --font-sans: 'Inter', ui-sans-serif, system-ui;
  --font-mono: 'JetBrains Mono', ui-monospace;
  
  --radius: 0.5rem;       /* radius.md = 8px */
  --radius-sm: 0.25rem;
  --radius-lg: 0.75rem;
}
```

---

## Checkpoint After Design Token Generation

Before any Implementer starts, UI Agent must show Orchestrator:

```
Design tokens generated from [source]:

Primary:    ████ #6366F1 (Indigo)
Secondary:  ████ #8B5CF6 (Purple)  
Accent:     ████ #F59E0B (Amber)
Background: ████ #FFFFFF
Text:       ████ #0F172A

Font: Inter
Radius: 8px (moderate)

Files written:
- design-tokens.json
- admin/src/index.css (Tailwind theme)
- mobile/lib/core/theme/app_colors.dart
- mobile/lib/core/theme/app_theme.dart

Do these look right? Say 'confirmed' to start implementation.
```

**Do not proceed to Phase 5 until Orchestrator confirms design tokens.**
