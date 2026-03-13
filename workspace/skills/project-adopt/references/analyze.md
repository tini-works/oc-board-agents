# Analyze Phase

## Goal
Build a complete mental model of the existing codebase before proposing any SOT structure.
Capture framework context needed for A2UI JSONL generation in Phase 3.
Never scaffold without completing this phase first.

## Step 1: Run the analyzer script

```bash
bash <skill-dir>/scripts/analyze_project.sh <project-path>
```

Capture the full output. This gives: file counts, language breakdown, framework detection,
top-level structure, and complexity estimate.

## Step 2: Framework Detection (FRAMEWORK_CONTEXT)

Produce a `FRAMEWORK_CONTEXT` object — used in Phase 3 A2UI generation.

**Router detection:**

| Signal | Framework | Router |
|--------|-----------|--------|
| `next` in deps + `app/` dir | Next.js | `app-dir` |
| `next` in deps + `pages/` dir | Next.js | `pages-dir` |
| `expo` + `app/` + `_layout.tsx` | Expo Router | `expo-router` |
| `@react-navigation/native` | React Native | `react-navigation` |
| `react-router-dom` | React | `react-router` |
| `vue-router` | Vue | `vue-router` |
| `nuxt` | Nuxt | `nuxt-router` |
| `flutter` in pubspec.yaml | Flutter | `go-router` (check pubspec) |

**State management detection:**

| Signal | State library |
|--------|--------------|
| `zustand` in deps | `zustand` |
| `@reduxjs/toolkit` | `redux-toolkit` |
| `jotai` | `jotai` |
| `recoil` | `recoil` |
| `xstate` | `xstate` — treat as ground truth for states |
| `useState` only, no store | `local` |

**Styling detection:**

| Signal | Styling |
|--------|---------|
| `tailwindcss` in deps | `tailwind` |
| `nativewind` in deps | `nativewind` |
| `styled-components` or `@emotion` | `css-in-js` |
| React Native `StyleSheet` imports | `stylesheet` |
| `@mui/material` | `mui` |

**Output:**
```json
{
  "framework": "next|expo|react-native|vue|flutter|nuxt",
  "router": "app-dir|pages-dir|expo-router|react-navigation|react-router|vue-router",
  "state": "zustand|redux-toolkit|xstate|jotai|local",
  "styling": "tailwind|nativewind|css-in-js|stylesheet|mui",
  "language": "ts|js",
  "hasTests": true,
  "hasOpenAPI": false,
  "hasPrisma": true,
  "hasZod": true
}
```

## Step 3: Deep-scan entry points & module boundaries

```bash
# Barrel exports reveal module boundaries
find <project>/src -name "index.ts" -o -name "index.js" | head -20

# Routing files reveal major features
find <project> -name "*.routes.*" -o -name "*router*" -o -name "routes.ts" \
  | grep -v node_modules | head -20

# API schemas / contracts
find <project> -name "*.prisma" -o -name "*.graphql" -o -name "openapi.*" \
  | grep -v node_modules

# Env vars used
grep -r "process\.env\." <project>/src --include="*.ts" --include="*.js" \
  | grep -oP 'process\.env\.\K[A-Z_]+' | sort -u
```

## Step 4: Read key files for context

Always read (in order, stop when you have enough):
1. `README.md` — high-level purpose
2. `package.json` — dependencies reveal architecture
3. Main entry point — reveals app structure
4. DB schema file (Prisma, SQL, etc.) — reveals domain model
5. `.env.example` — reveals external services + required vars
6. Type definitions (`src/types/`, `*.types.ts`) — reveals data model

## Step 5: Identify Containers

Rules:
- Each **deployable unit** → 1 container
- Each **major technical layer** with its own package.json → 1 container
- Monorepo packages → typically 1 container each

**Naming:** `c3-1-frontend`, `c3-2-api`, `c3-3-worker`, `c3-4-shared`

## Step 6: Identify Components (features within containers)

For each container, identify major feature groups:
- React/Next/Expo apps: major page groups or feature directories
- API: domain handlers, service layers, route groups
- Shared: util modules, UI component libraries

**Naming:** `c3-101-auth`, `c3-102-dashboard`, `c3-201-user-service`, etc.

## Step 7: Identify Cross-Cutting Refs

Scan for patterns across multiple containers. Always produce these 5:

| Ref | When to include |
|-----|----------------|
| `ref-auth-pattern` | Any auth middleware, token logic, or login screens |
| `ref-error-handling` | Any error handler, toast system, error boundaries |
| `ref-ui-design-system` | Any UI framework, design tokens, component library |
| `ref-data-model` | Always — even if just a User entity |
| `ref-testing-strategy` | Always — even if no tests exist yet |

## Step 8: Route Inventory (feeds Phase 3 A2UI)

Based on `FRAMEWORK_CONTEXT.router`, enumerate all routes now:

| Router | Where to look |
|--------|--------------|
| `app-dir` | Every `page.tsx` under `app/` → strip `/page.tsx` for route |
| `pages-dir` | Every file under `pages/` except `_app`, `_document`, `api/` |
| `expo-router` | Every `(name).tsx` / `index.tsx` under `app/` |
| `react-navigation` | Find all `Stack.Screen`, `Tab.Screen`, `Drawer.Screen` declarations |
| `react-router` | Find `createBrowserRouter` or `<Route path=` |
| `vue-router` | Find routes array in router config |

Group routes by feature → each group = one `<feature>.screens.jsonl` file.

## Deliver a Proposal Summary

Before scaffolding, present to user:

```
📋 Architecture Proposal for <project-name>

Size: <SMALL|MEDIUM|LARGE|XLARGE> (<N> source files)
Language: <language(s)>
Framework: <framework> / Router: <router> / State: <state> / Styling: <styling>

Proposed SOT Structure:
├── c3-1-<name>    (<description>)
│   ├── c3-101-<component>
│   └── c3-102-<component>
├── c3-2-<name>    (<description>)
│   └── c3-201-<component>
└── Refs: ref-auth-pattern, ref-error-handling, ref-ui-design-system,
          ref-data-model, ref-testing-strategy

A2UI JSONL — features to generate:
  - <feature-1>: <N> routes → <feature-1>.screens.jsonl + <feature-1>.flow.jsonl
  - <feature-2>: <N> routes → ...

Shall I proceed? (or tell me what to change)
```

Wait for explicit confirmation before moving to scaffold phase.
Exception: ASSUMPTION_MODE active → proceed with [ASSUMED] tags.
