# Analyze Phase

## Goal
Build a clear mental model of the existing codebase before proposing any SOT structure.
Never scaffold without completing this phase first.

## Step 1: Run the analyzer script

```bash
bash <skill-dir>/scripts/analyze_project.sh <project-path>
```

Capture the full output. This gives: file counts, language breakdown, framework detection,
top-level structure, and complexity estimate.

## Step 2: Deep-scan entry points & module boundaries

For each detected top-level directory, quickly check what it does:

```bash
# What's in each top-level dir?
ls <project>/<dir>/

# Check for barrel exports (reveals module boundaries)
find <project>/src -name "index.ts" -o -name "index.js" | head -20

# Check routing files (reveals major features for web apps)
find <project> -name "*.routes.*" -o -name "*router*" -o -name "routes.ts" \
  | grep -v node_modules | head -20

# Check for API schemas / contracts
find <project> -name "*.prisma" -o -name "*.graphql" -o -name "openapi.*" \
  | grep -v node_modules
```

## Step 3: Read key files for context

Always read (in order, stop when you have enough):
1. `README.md` — high-level purpose
2. `package.json` or equivalent — dependencies reveal architecture
3. Main entry point — reveals app structure
4. DB schema file (Prisma, SQL, etc.) — reveals domain model
5. Environment example (`.env.example`) — reveals external services

## Step 4: Identify Containers (top-level architectural units)

Rules for identifying containers:
- Each **deployable unit** → 1 container (frontend, API server, worker, etc.)
- Each **major technical layer** with its own package.json → 1 container
- Monorepo packages → typically 1 container each
- `shared/` or `packages/common` → 1 container (shared libs)

**Naming convention:** `c3-1-frontend`, `c3-2-api`, `c3-3-worker`, `c3-4-shared`

## Step 5: Identify Components (features within containers)

For each container, identify major feature groups:
- React apps: major page groups, feature directories (`/auth`, `/dashboard`, `/settings`)
- API: domain handlers, service layers, route groups
- Worker: job types, queue processors
- Shared: util modules, UI component libraries

**Naming:** `c3-101-auth`, `c3-102-dashboard`, `c3-201-user-service`, etc.

## Step 6: Identify Cross-Cutting Refs

Look for patterns that appear across multiple containers:
- Auth / session middleware
- Shared error handling
- Logging conventions
- API contract (OpenAPI, tRPC router)
- DB access patterns (repository pattern, etc.)
- Shared UI design system

Each → `ref-<slug>.md`

## Deliver a Proposal Summary

Before scaffolding, present to user:

```
📋 Architecture Proposal for <project-name>

Size: <SMALL|MEDIUM|LARGE|XLARGE> (<N> source files)
Language: <primary language(s)>
Frameworks: <list>

Proposed SOT Structure:
├── c3-1-<name>    (<description>)
│   ├── c3-101-<component>
│   └── c3-102-<component>
├── c3-2-<name>    (<description>)
│   ├── c3-201-<component>
│   └── c3-202-<component>
└── Cross-cutting refs:
    ├── ref-auth
    └── ref-error-handling

Shall I proceed with this structure? (or tell me what to change)
```

**Wait for explicit confirmation before moving to scaffold phase.**
Exception: ASSUMPTION_MODE is active → proceed with [ASSUMED] tags.
