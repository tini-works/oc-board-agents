# Scaffold Phase

## Prerequisites
- Architecture proposal confirmed (or ASSUMPTION_MODE active)
- `FRAMEWORK_CONTEXT` from analyze phase available
- Route inventory from analyze phase available
- SOT repo path known
- `C3X=/home/node/.openclaw/workspace/skills/c3/bin/c3x.sh`

---

## Step 1: Scaffold from sot-template

Clone sot-template as the SOT repo base — do NOT use bare `c3x init` alone.

```bash
SOT_TEMPLATE="https://github.com/thanh-dong/sot-template.git"

# Option A: clone template (preferred)
git clone --depth 1 $SOT_TEMPLATE <sot-repo-path>
cd <sot-repo-path>
rm -rf .git
git init
git remote add origin <new-github-url>   # if GitHub configured

# Option B: if repo already exists, copy template structure
rsync -av --exclude='.git' <sot-template-local>/ <sot-repo-path>/
```

Then replace all `[Product Name]` placeholders:
```bash
find <sot-repo-path> -type f \( -name "*.md" -o -name "*.mdx" -o -name "*.yaml" -o -name "*.json" \) \
  | xargs sed -i 's/\[Product Name\]/<project-name>/g'
```

---

## Step 2: Initialize c3

```bash
cd <sot-repo-path>
bash $C3X init
```

Edit `.c3/README.md` (Context doc):
- Product name, goal, primary users
- Container table (fill in from proposal)
- Tech stack table (fill in from FRAMEWORK_CONTEXT)
- Update cross-cutting refs table — add `ref-data-model` and `ref-testing-strategy`

---

## Step 3: Create Containers

```bash
bash $C3X add container <slug> --c3-dir <sot-repo>/.c3
```

Edit each container `README.md`:
- `purpose:` what this container does
- `tech:` stack from FRAMEWORK_CONTEXT
- `repo_path:` relative path in derived repo

---

## Step 4: Create Components

```bash
bash $C3X add component <slug> --container c3-N --c3-dir <sot-repo>/.c3
```

For frontend components, add `## Screens` section listing routes (from route inventory).
For backend components, add `## API Dependencies` listing endpoints.

---

## Step 5: Add All 5 Refs

Always create all 5 refs. Copy from sot-template if not already present:

```bash
# These should already exist from sot-template clone — verify and fill content:
# .c3/refs/ref-auth-pattern.md
# .c3/refs/ref-error-handling.md
# .c3/refs/ref-ui-design-system.md
# .c3/refs/ref-data-model.md       ← fill entities from analyze phase
# .c3/refs/ref-testing-strategy.md ← fill stack-specific tools

# Wire refs to components:
bash $C3X wire c3-NNN cite ref-<slug> --c3-dir <sot-repo>/.c3
```

**Fill `ref-data-model.md`** from data model extracted in analyze phase (Prisma schema, Zod, TypeScript types).

**Fill `ref-testing-strategy.md`** with the actual test tools found in `package.json`:
- Jest / Vitest / Playwright → replace the template placeholders

---

## Step 6: Fill docs/api/index.md

From API contracts extracted in analyze phase, document each endpoint:

```markdown
### POST /api/v1/auth/login
**Auth:** none
**Request:** `{ email: string, password: string }`
**Response:** `{ token: string, refreshToken: string, user: User }`
**Errors:** TOKEN_INVALID(401), VALIDATION_ERROR(400)
```

If OpenAPI spec exists, extract and convert automatically.
If tRPC: list each procedure as an "endpoint" with input/output types.

---

## Step 7: Fill docs/infra/env.md

From `.env.example` and `process.env.*` grep in analyze phase:
- List all variables with type (required/optional), example value, description
- Never include real secret values

---

## Step 8: Fill code-map.yaml

```bash
bash $C3X codemap --c3-dir <sot-repo>/.c3
```

Fill glob patterns per component. Example:
```yaml
c3-101-auth:
  sources:
    - src/app/(auth)/**
    - src/components/auth/**
    - src/lib/auth.ts
  status: mapped
c3-201-auth-service:
  sources:
    - src/api/auth/**
    - src/middleware/auth.ts
  status: mapped
_exclude:
  - "**/*.test.ts"
  - "**/*.spec.ts"
  - dist/**
  - node_modules/**
```

---

## Step 9: A2UI JSONL Generation

Run 5 sub-passes per feature (grouped from route inventory in analyze phase).

### 9a — Component tree extraction

For each screen file (route → file mapping from FRAMEWORK_CONTEXT.router):

```bash
# Find screen file from route
# app-dir:        app/<route>/page.tsx
# pages-dir:      pages/<route>.tsx
# expo-router:    app/<route>/index.tsx or app/(group)/<route>.tsx
# react-nav:      src/screens/<ScreenName>.tsx
```

Read the screen file. Extract:
1. The JSX `return()` block
2. All **capitalized** JSX elements (components) in top-to-bottom order → `layout.children`
3. For each component: find its import, read its props interface/type

Map TypeScript prop types to JSONL types:
```
string | String         → "string"
number | Number         → "number"
boolean | Boolean       → "boolean"
() => void | Handler    → "fn"
ReactNode | JSX.Element → "node"
T | undefined           → "T|null"
T | null                → "T|null"
```

### 9b — State extraction

Scan each screen file for state signals:

| Code pattern | JSONL state | UI behavior |
|-------------|-------------|-------------|
| `isLoading \|\| isPending \|\| status==='loading'` | `loading` | disable actions, show spinner |
| `isError \|\| error !== null \|\| hasError` | `error` | show ErrorBanner |
| `!data \|\| data.length===0 \|\| isEmpty` | `empty` | show EmptyState |
| `isSuccess \|\| status==='success'` | `success` | show SuccessBanner |
| `isSubmitting` | `submitting` | disable form, show spinner |
| XState state names | use directly | map `.matches('state')` usage |
| Zustand boolean flags | derive from flag name | |

Map conditional renders to state behaviors:
```
{isLoading && <Spinner />}            → loading: { show: ["Spinner"] }
{!isLoading && <Button />}            → loading: { hide: ["Button"] }
disabled={isLoading}                  → loading: { disable: ["Button"] }
{error && <ErrorBanner msg={error} />}→ error: { show: ["ErrorBanner"] }
```

### 9c — Navigation graph

Scan each screen for outbound navigation:

| Framework | Patterns to find |
|-----------|----------------|
| Next.js | `router.push('/path')`, `router.replace(...)`, `<Link href=...>` |
| Expo Router | `router.push('/(tabs)/home')`, `<Link href=...>` |
| React Navigation | `navigation.navigate('Name')`, `navigation.replace(...)`, `navigation.goBack()` |
| React Router | `navigate('/path')`, `<Link to=...>` |

Per navigation call:
1. Trigger — which user action (onPress, onClick, onSubmit, useEffect condition)
2. Condition — what gates the navigation (`if (data)`, `onSuccess:`)
3. Effect — side effect alongside (toast message, store.reset(), etc.)

Group by user journey → one `flow` JSONL entry per journey.

### 9d — Design system extraction

Scan for tokens:
```bash
# Tailwind config
grep -A 50 'theme.*extend' tailwind.config.ts

# CSS variables
grep -r '\-\-color\|\-\-spacing\|\-\-font' src/ --include="*.css" | head -40

# Theme/tokens file
find src -name "theme.ts" -o -name "tokens.ts" -o -name "colors.ts" | head -5
```

Write `docs/ui/a2ui/design-system.jsonl`:
- One `token` line per design token found
- One `component` line per shared UI component in `src/components/ui/` or equivalent

### 9e — AC synthesis

Per screen, write minimum 3 AC in `Given/When/Then` format:
- One per flow step involving this screen
- One per non-idle state
- One per error condition

Fallback ACs if code doesn't reveal enough:
- `"Given loading, then [primary button] is disabled"`
- `"Given error, then user sees error message with retry option"`
- `"Given success, then user is navigated to [next screen]"`

### 9f — Write JSONL files

Per feature group, write:
- `docs/ui/a2ui/<feature>.screens.jsonl` — token + component + screen lines
- `docs/ui/a2ui/<feature>.flow.jsonl` — flow lines

JSONL rules:
- One valid JSON object per line
- No trailing commas, no comments, no blank lines
- Validate each line:
```bash
while IFS= read -r line; do
  echo "$line" | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))" || echo "INVALID: $line"
done < <feature>.screens.jsonl
```

---

## Step 10: Validate

```bash
bash $C3X check --c3-dir <sot-repo>/.c3
bash $C3X coverage --c3-dir <sot-repo>/.c3
```

Fix any `✗` errors. Aim for >70% coverage on MEDIUM/LARGE projects.

**A2UI checklist:**
- [ ] Every route from inventory has a `screen` JSONL entry
- [ ] Every screen's `layout.children` items exist as `component` JSONL entries
- [ ] Every flow references only screen IDs that exist
- [ ] All JSONL lines parse as valid JSON
- [ ] `design-system.jsonl` exists with at least color tokens

---

## Step 11: Inject CLAUDE.md into Derived Repo

```bash
cat >> <derived-repo>/CLAUDE.md << 'EOF'

# Architecture
This project uses a SOT repo for architecture governance.
SOT repo: <sot-repo-path>
For architecture questions, changes, audits → use `/c3` skill or `sot-manager` skill.
To adopt this project → use `project-adopt` skill.
File lookup: `c3x lookup <file-or-glob>` maps files to components + refs.
EOF
```

---

## Step 12: Initial Commit

```bash
cd <sot-repo-path>
git add -A
git commit -m "feat: initial SOT — adopted from <project-name>

- c3 structure: <N> containers, <N> components, 5 refs
- A2UI JSONL: <feature-list>
- API contracts: <N> endpoints
- Data model: <entity-list>"
git push -u origin main  # if GitHub configured
```

---

## Scaffold Complete Checklist

- [ ] sot-template structure cloned and placeholders replaced
- [ ] c3 context doc filled (product name, goal, containers, tech stack)
- [ ] All containers + components created and documented
- [ ] All 5 refs present: auth-pattern, error-handling, ui-design-system, data-model, testing-strategy
- [ ] `ref-data-model.md` filled with real entities from codebase
- [ ] `ref-testing-strategy.md` filled with real test tools from package.json
- [ ] `docs/api/index.md` filled with real endpoints
- [ ] `docs/infra/env.md` filled with real env vars
- [ ] `docs/ui/a2ui/<feature>.screens.jsonl` exists for each feature
- [ ] `docs/ui/a2ui/<feature>.flow.jsonl` exists for each feature
- [ ] `docs/ui/a2ui/design-system.jsonl` exists with tokens + shared components
- [ ] All JSONL files validate as valid JSON
- [ ] `code-map.yaml` filled with source globs
- [ ] `c3x check` passes (zero errors)
- [ ] `c3x coverage` >60%
- [ ] CLAUDE.md injected into derived repo
- [ ] Initial commit pushed
