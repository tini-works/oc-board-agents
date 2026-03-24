---
name: json-render-adapter
description: Read json-render/ UI specs (catalog.json, theme.json, actions.json, specs/) and generate a self-contained React adapter library using @json-render/react + @json-render/shadcn. Output is consumed directly by the board server via Bun.build().
user-invocable: true
argument-hint: "[output-dir]"
---

# Generate JSON Render v2 Adapter

Read `json-render/` UI specifications and generate a **self-contained** React adapter library that renders them using `@json-render/react` + `@json-render/shadcn`. The output directory is consumed directly by the board server (which bundles it on-the-fly with `Bun.build()` + `tailwindcss`).

## Input

The working directory must contain:

### Required — `json-render/`

Everything needed to generate the adapter lives in this directory:

- `catalog.json` — Component type definitions with prop JSON schemas. **Drives component generation.** Each type key becomes a React component. Each prop's enum values become Tailwind class maps.
- `actions.json` — All action identifiers with descriptions. **Drives action handler generation.**
- `theme.json` — Design tokens: colors, typography, spacing, radius, shadows, dark mode. **Drives the CSS theme file.**
- `specs/` — Per-screen JSON specs (element trees with root, elements map, children, event bindings). **These are what gets rendered.**

### Optional — `spec.sft.yaml`

If present, used for:
- Screen layout types (public / authenticated / admin) — for generating shell wrappers
- App-level regions (Sidebar, NowPlayingBar, PageHeader) — for shell structure
- Per-screen regions, states, actions — for enriching specs with `state`, `repeat`, `visible`

If absent, specs render as-is without shell wrappers or enrichment.

### Optional — `.c3/`

If present, only used for:
- `.c3/README.md` — app name for branding text in shell
- Layout shell component doc — sidebar nav items

Not required. Does not affect code generation. All rendering logic comes from `json-render/`.

## Output

Generate a `json-render-adapter/` directory (or the directory specified by argument) with these files:

### `lib/render/components.tsx`

For each type in `catalog.json`, create a React component function.

**CRITICAL: Define a local `BaseProps` interface — do NOT import `BaseComponentProps` from `@json-render/react`:**

```tsx
import type { ReactNode } from "react";

type P = Record<string, any>;
interface BaseProps {
  props: P;
  children?: ReactNode;
  emit: (event: string) => void;
  on: (event: string) => { bound: boolean };
  bindings?: Record<string, string>;
}

function Stack({ props: p, children }: BaseProps) {
  return <div className={cx("flex", ...)}>{children}</div>;
}
```

**How to generate each component:**

1. Read the type's prop schema from `catalog.json`
2. For each enum prop, create a prop-to-Tailwind mapping constant (e.g. `GAP_MAP`, `BTN_VARIANT_MAP`)
3. Map Tailwind classes using `theme.json` token names — NOT hardcoded hex colors:
   - Colors from theme.json → Tailwind custom classes (e.g. `bg-surface`, `text-txt-primary`, `bg-sfm-accent`)
   - Spacing, radius, shadows → Tailwind scale values
4. Container types (those with `children` in their schema) render `{children}` as React children
5. Leaf types render their content from props (e.g. `props.content`, `props.label`)
6. Wire `emit("press")` / `emit("change")` to onClick/onChange for interactive types (Button, Input, Tabs, etc.)
7. Handle both old prop names (from `catalog.json`) AND shadcn prop names for compatibility:
   - `content` OR `text` for text content
   - `headers` OR `columns` for table headers
   - `items` OR `tabs` for tab items
   - `activeTab` OR `value` for selected tab
   - `variant` OR `type` for alert type

**Prop-to-Tailwind mapping rules:**
- Gap: `none→gap-0, xs→gap-1, sm→gap-2, md→gap-4, lg→gap-6, xl→gap-8`
- Padding: `none→p-0, sm→p-2, md→p-4, lg→p-6`
- Rounded: `none→rounded-none, sm→rounded-sm, md→rounded-md, lg→rounded-lg, xl→rounded-xl, 2xl→rounded-2xl, full→rounded-full`
- Text size: map to Tailwind text scale (`text-xs`, `text-sm`, `text-base`, `text-xl`, etc.)
- For enum props not in standard Tailwind scale, use arbitrary values: `text-[11px]`, `tracking-[1px]`

**Color class naming convention** (derived from theme.json — uses `--sfm-*` CSS variable names):
- Page/surface colors → `bg-page`, `bg-surface`, `bg-surface-elevated`, `bg-surface-hover`
- Accent colors → `bg-sfm-accent`, `bg-sfm-accent-hover`, `bg-sfm-accent-soft`, `text-sfm-accent`
- Text colors → `text-txt-primary`, `text-txt-secondary`, `text-txt-muted`, `text-txt-inverse`
- Status colors → `text-status-green`, `bg-status-blue`, etc.
- Border → `border-border`
- shadcn standard → `bg-background`, `text-foreground`, `bg-card`, `bg-primary`, `text-muted-foreground`, etc.

**CRITICAL: Export as `silentiumComponents` (not `appComponents`):**

```tsx
export const silentiumComponents = { Stack, Grid, Card, ... };
```

### `lib/render/catalog.ts`

Generate a `defineCatalog()` call.

**CRITICAL imports — `defineCatalog` is from `@json-render/core`, NOT `@json-render/react`:**

```typescript
import { defineCatalog } from "@json-render/core";
import { schema } from "@json-render/react/schema";
import { shadcnComponentDefinitions } from "@json-render/shadcn/catalog";
import { z } from "zod";

export const catalog = defineCatalog(schema, {
  components: { ...shadcnComponentDefinitions },
  actions: {
    "action-name": {
      params: z.object({ /* inferred from action context */ }),
      description: "from actions.json",
    },
  },
});
```

### `lib/render/registry.tsx`

Generate a `defineRegistry()` call.

**CRITICAL: Import `silentiumComponents` from `./components` (not `appComponents`):**

```typescript
import { defineRegistry } from "@json-render/react";
import { shadcnComponents } from "@json-render/shadcn";
import { catalog } from "./catalog";
import { silentiumComponents } from "./components";

export const { registry } = defineRegistry(catalog, {
  components: {
    ...shadcnComponents,           // fallback for Dialog, Drawer, Carousel, etc.
    ...silentiumComponents,        // custom components override shadcn
  },
  actions: { /* stub handler for each action */ },
});

export const actionHandlers: Record<string, (params: Record<string, unknown>) => void> = {
  /* same stubs, for JSONUIProvider */
};
```

### `lib/render/usage.tsx`

Generate a `SpecRenderer` wrapper component:

```tsx
import { JSONUIProvider, Renderer } from "@json-render/react";
import type { Spec } from "@json-render/core";
import { registry, actionHandlers } from "./registry";

export function SpecRenderer({ spec }: { spec: Spec }) {
  return (
    <JSONUIProvider registry={registry} initialState={spec.state ?? {}} handlers={actionHandlers}>
      <Renderer spec={spec} registry={registry} />
    </JSONUIProvider>
  );
}
```

### `lib/render/shell.tsx`

Generate a `ShellRenderer` component that wraps specs in app chrome based on the screen's layout type. This is what the board renders inside its iframe.

Read `spec.sft.yaml` (if present) or `json-render/specs/` filenames to determine screen list and layout types. Each screen gets a layout type:
- **`public`** — centered layout, no sidebar (e.g. login, radio)
- **`authenticated`** — sidebar nav + page header + now-playing bar (e.g. dashboard, admin pages)

```tsx
import type { Spec } from "@json-render/core";
import { SpecRenderer } from "./usage";

interface ScreenDef {
  name: string;
  route: string;
  tags: string[];
  layout: "public" | "authenticated";
  description: string;
}

const SCREEN_DEFS: Record<string, ScreenDef> = {
  login: { name: "Login", route: "/login", tags: ["public"], layout: "public", description: "..." },
  dashboard: { name: "Dashboard", route: "/", tags: ["authenticated"], layout: "authenticated", description: "..." },
  // ... one entry per spec file
};

export function ShellRenderer({ spec, screenKey }: { spec: Spec; screenKey: string }) {
  const screenDef = SCREEN_DEFS[screenKey];
  if (!screenDef) return <div className="h-full overflow-auto bg-background p-6"><SpecRenderer spec={spec} /></div>;
  if (screenDef.layout === "public") return <PublicShell spec={spec} />;
  return <AuthenticatedShell spec={spec} screenDef={screenDef} />;
}
```

**Public shell**: centered content with `max-w-md`, `bg-background`.

**Authenticated shell**:
- Left sidebar (`w-[200px]`, `bg-card`) with app brand + nav links (derived from screen list)
- Page header (`border-b`, `bg-card`) with screen name + description
- Content area (`flex-1 overflow-auto p-6`) with `<SpecRenderer />`
- Now-playing bar (`h-[72px]`, `border-t`, `bg-card`) with mock playback controls

### `styles/theme.css`

Read `theme.json` and generate a **complete, self-contained** Tailwind v4 CSS file.

**CRITICAL structure — the file must include ALL of these sections in order:**

```css
@import url('https://fonts.googleapis.com/css2?family=...from+theme.json...');
@import "tailwindcss";
@import "tw-animate-css";

@source "../node_modules/@json-render/shadcn/dist/**/*.mjs";

@custom-variant dark (&:is([data-theme="dark"] *));

@theme inline {
  /* 1. Radius scale (shadcn) */
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
  /* ... */

  /* 2. shadcn color aliases — REQUIRED for shadcn components to work */
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-destructive-foreground: var(--destructive-foreground);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --color-chart-1: var(--chart-1);
  /* ... chart-2 through chart-5 */

  /* 3. App-specific color tokens (from theme.json) */
  --color-page: var(--sfm-page);
  --color-surface: var(--sfm-surface);
  --color-surface-elevated: var(--sfm-surface-elevated);
  --color-surface-hover: var(--sfm-surface-hover);
  --color-sfm-accent: var(--sfm-accent);
  --color-sfm-accent-hover: var(--sfm-accent-hover);
  --color-sfm-accent-secondary: var(--sfm-accent-secondary);
  --color-sfm-accent-soft: var(--sfm-accent-soft);
  --color-txt-primary: var(--sfm-txt-primary);
  --color-txt-secondary: var(--sfm-txt-secondary);
  --color-txt-muted: var(--sfm-txt-muted);
  --color-txt-inverse: var(--sfm-txt-inverse);
  --color-status-green: var(--sfm-status-green);
  /* ... other status colors */
  --color-overlay: var(--sfm-overlay);

  /* 4. Fonts, spacing, shadows from theme.json */
  --font-sans: 'DM Sans', sans-serif;
  --font-serif: 'DM Serif Display', serif;
  --font-mono: ui-monospace, ...;
  --spacing-bar-height: 72px;
  --shadow-2xs: ...;
  /* ... */
}

/* Light theme — :root */
:root {
  --radius: 0.375rem;

  /* shadcn variables */
  --background: #f7f5f0;   /* from theme.json page-bg */
  --foreground: #1d1d1f;   /* from theme.json text-primary */
  --card: ...;
  --primary: ...;
  /* ... all shadcn vars */

  /* App-specific variables (backing the @theme registrations) */
  --sfm-page: #f7f5f0;
  --sfm-surface: #fcf9f2;
  --sfm-txt-primary: #1d1d1f;
  /* ... all app tokens */
}

/* Dark theme */
[data-theme="dark"] {
  --background: #1c1917;
  --foreground: #f5f5f4;
  /* ... all shadcn + app vars with dark values */
}

/* Also support .dark class */
.dark {
  /* same as [data-theme="dark"] */
}

/* Base layer */
@layer base {
  * { @apply border-border outline-ring/50; }
  body { @apply bg-background text-foreground; }
}

button { cursor: pointer; }

/* Component chrome */
.preview-box { ... }
::-webkit-scrollbar { ... }
@keyframes vinyl-spin { ... }
.spin-animation { animation: vinyl-spin 3s linear infinite; }
```

**CRITICAL CSS variable naming — use `--sfm-page`, `--sfm-txt-primary`, NOT `--sfm-page-bg`, `--sfm-text-primary`:**

| theme.json token | CSS variable | @theme registration |
|---|---|---|
| `page-bg` | `--sfm-page` | `--color-page: var(--sfm-page)` |
| `text-primary` | `--sfm-txt-primary` | `--color-txt-primary: var(--sfm-txt-primary)` |
| `text-secondary` | `--sfm-txt-secondary` | `--color-txt-secondary: var(--sfm-txt-secondary)` |
| `text-muted` | `--sfm-txt-muted` | `--color-txt-muted: var(--sfm-txt-muted)` |
| `surface` | `--sfm-surface` | `--color-surface: var(--sfm-surface)` |
| `accent-primary` | `--sfm-accent` | `--color-sfm-accent: var(--sfm-accent)` |

### `specs/` — Enriched JSON specs (not copies)

Read each `json-render/specs/*.json` and generate an **enriched** version in the output `specs/` directory. The output specs are transformed — not raw copies — with `@json-render/react` engine features that make them interactive previews.

**All enrichments are mandatory.** Apply every applicable transformation to every spec:

1. **Add `state` block** — analyze the spec's elements and infer initial state values. Every interactive element implies state:
   - Input/Textarea → string state for its value
   - Switch/Checkbox → boolean state for checked
   - Tabs → string state for active tab
   - Alert with empty content → string state for error message
   - Button with "loading" semantics → boolean state for isLoading
   - Lists/tables → array state with 2-3 sample items (realistic data, not placeholders)

2. **Add `repeat`** — where elements have empty `children: []` and represent list containers (song queues, user lists, history items), add:
   ```json
   "repeat": { "statePath": "/songs", "key": "id" }
   ```
   And populate the state array with realistic sample data matching the app domain.

3. **Add `$state` / `$bindState` refs** — replace static prop values with state bindings:
   - Input values → `{ "$bindState": "/form/fieldName" }` (two-way)
   - Text displaying counts/values → `{ "$state": "/count" }` (one-way)
   - String interpolation → `{ "$template": "${/count} of ${/limit} items" }`

4. **Add `$item` refs** — inside repeat scopes, replace static text with item references:
   - `"text": "Song Title"` → `"text": { "$item": "title" }`
   - Badge showing votes → `"text": { "$item": "votes" }`

5. **Add `visible`** — conditional visibility for:
   - Error alerts → `"visible": { "$state": "/errorMessage", "neq": "" }`
   - Modals/drawers → `"visible": { "$state": "/showModal", "eq": true }`
   - Empty states → `"visible": { "$state": "/items", "eq": [] }`
   - Auth-gated content → `"visible": { "$state": "/isAdmin", "eq": true }`

6. **Add `$cond`** — conditional prop values:
   - Button labels → `{ "$cond": { "$state": "/isLoading", "eq": true }, "$then": "Loading...", "$else": "Submit" }`
   - Badge variants → `{ "$cond": { "$item": "hasVoted", "eq": true }, "$then": "default", "$else": "secondary" }`

7. **Enrich `on` bindings** — add `params` with `$state` / `$item` references:
   - `"on": { "press": { "action": "toggle-vote", "params": { "songId": { "$item": "id" } } } }`
   - `"on": { "press": { "action": "submit-song", "params": { "url": { "$state": "/songInput" } } } }`

## Process

1. **Read `json-render/`** — `catalog.json`, `actions.json`, `theme.json`, all `specs/*.json`
2. **Read `spec.sft.yaml`** (if exists) — screen list, layout types, regions, shell structure
3. **Read `.c3/README.md`** (if exists) — app name for branding
4. **Analyze catalog.json** — categorize each type (container vs leaf), identify prop enums that map to Tailwind scale, identify which props are content vs styling
5. **Analyze theme.json** — extract all tokens, determine shadcn variable mapping, identify custom namespaces (surfaces, accents, text colors, status colors)
6. **Generate `styles/theme.css`** — complete Tailwind v4 CSS: `@import "tailwindcss"` + `@import "tw-animate-css"` + `@source` for shadcn + `@custom-variant dark` + `@theme inline` + `:root` + `[data-theme="dark"]` + `.dark` + `@layer base` + component chrome
7. **Generate `lib/render/components.tsx`** — local `BaseProps` interface + one React component per catalog type + export as `silentiumComponents`
8. **Generate `lib/render/catalog.ts`** — `defineCatalog` from `@json-render/core` (NOT react) + `schema` from `@json-render/react/schema` + shadcn base + actions from actions.json
9. **Generate `lib/render/registry.tsx`** — `defineRegistry` wiring `silentiumComponents` (NOT appComponents) + action stubs + export `actionHandlers`
10. **Generate `lib/render/usage.tsx`** — `SpecRenderer` wrapper with `JSONUIProvider`
11. **Generate `lib/render/shell.tsx`** — `ShellRenderer` with `SCREEN_DEFS` per screen, public vs authenticated layout shells
12. **Enrich `specs/`** — read each `json-render/specs/*.json`, apply ALL enrichments (state, $state, $bindState, $item, $cond, $template, visible, repeat, action params), write enriched versions to output `specs/`. Do NOT just copy — every spec must be transformed.

## Important Rules

- **Read data, generate code** — the skill reads catalog.json/theme.json/actions.json and generates tailored output. It does NOT copy hardcoded templates.
- **Theme from data** — all color classes, font families, spacing values come from reading theme.json. Different projects with different theme.json files get different output.
- **Catalog from data** — the components.tsx is generated by reading catalog.json type definitions. Different catalogs produce different component sets.
- **Actions from data** — the catalog.ts action definitions come from actions.json. Different action sets produce different handler stubs.
- **Prop compat** — generated components should accept both the project's original prop names (from catalog.json) AND shadcn standard prop names, so specs work in either format.
- **Specs are transformed, not copied** — output specs must be enriched with state, bindings, conditionals, and repeat. Raw copies of input specs are not acceptable.
- **Pluggable output** — the output files are designed to be bundled by the consuming project. They import from `@json-render/core`, `@json-render/react`, `@json-render/shadcn` which must be available in the target project's node_modules.
- **Self-contained** — the output directory must contain everything needed: lib/, specs/, styles/. No references to sibling directories.

## Common mistakes to avoid

These caused real bugs in production — do NOT repeat them:

| Mistake | Correct |
|---|---|
| `import { defineCatalog } from "@json-render/react"` | `import { defineCatalog } from "@json-render/core"` |
| `import type { BaseComponentProps } from "@json-render/react"` | Define local `BaseProps` interface in components.tsx |
| `export const appComponents = { ... }` | `export const silentiumComponents = { ... }` |
| `import { appComponents } from "./components"` | `import { silentiumComponents } from "./components"` |
| CSS var `--sfm-page-bg` / `--sfm-text-primary` | `--sfm-page` / `--sfm-txt-primary` |
| Missing `@import "tw-animate-css"` in theme.css | Always include after `@import "tailwindcss"` |
| Missing `@source` for shadcn dist in theme.css | `@source "../node_modules/@json-render/shadcn/dist/**/*.mjs"` |
| Missing `@custom-variant dark` in theme.css | `@custom-variant dark (&:is([data-theme="dark"] *))` |
| Missing `@layer base` with `bg-background text-foreground` | Always include for body defaults |
| Missing shadcn color aliases in `@theme inline` | Must register `--color-background`, `--color-primary`, etc. |
| Missing `lib/render/shell.tsx` | Always generate — board uses ShellRenderer for iframe display |
| Empty `specs/` or raw copies of input specs | Always enrich specs with state, $state, $cond, visible, repeat |

## Dependencies (for target project)

```
@json-render/core    ^0.14.1
@json-render/react   ^0.14.1
@json-render/shadcn  ^0.14.1
zod                  ^4
tailwindcss          ^4
tw-animate-css       ^1
```

## Target project integration

The consuming project (e.g. the board server) needs to:

1. Install the npm dependencies above
2. Point `PREV_JSON_RENDER_DIR` to the generated `json-render-adapter/` directory
3. The board server will:
   - Symlink its `node_modules` into the json-render-adapter dir for package resolution
   - Bundle `lib/render/` with `Bun.build()` (entry: shell.tsx → usage.tsx → registry → components)
   - Compile Tailwind CSS from `styles/theme.css` using the `tailwindcss` CLI
   - Serve per-screen HTML with the bundled JS/CSS and spec JSON
