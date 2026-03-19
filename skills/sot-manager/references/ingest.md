# Ingest Reference (Brownfield)

Reverse-engineer an existing codebase into the full sot-template SOT structure.

> **Preferred path:** Delegate to `project-adopt` skill — it handles the full pipeline
> including A2UI JSONL generation. Use this reference only when running sot-manager
> directly without project-adopt, or for incremental re-ingestion of an existing SOT.

## When to Use

- Existing codebase with no `.c3/` directory
- User says "audit this codebase", "reverse-engineer", "build SOT from existing code"
- Incremental update: new features added to derived repo, SOT needs to catch up

## Warning

This is a best-effort archaeological process. The agent maps what it can infer from code structure.
Human review is mandatory before the SOT is treated as authoritative.

---

## Steps

### Step 1: Delegate to project-adopt (preferred)

If `project-adopt` skill is available:
```
Trigger: "adopt this project" with PROJECT_PATH=$DERIVED_REPO and SOT_REPO=$SOT_REPO
```

project-adopt runs the full 4-phase pipeline (analyze → scaffold sot-template → A2UI JSONL → verify).
Skip to Step 9 (human review) after it completes.

### Step 2: Scope Assessment (if running standalone)

```bash
find $DERIVED_REPO -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.go" \) \
  | grep -v node_modules | grep -v dist | grep -v .next \
  | wc -l
```

Complexity: <100 = small, 100-500 = medium, 500+ = large.

### Step 3: Scaffold from sot-template

```bash
SOT_TEMPLATE="https://github.com/thanh-dong/sot-template.git"
git clone --depth 1 $SOT_TEMPLATE $SOT_REPO
cd $SOT_REPO && rm -rf .git && git init
find . -type f \( -name "*.md" -o -name "*.mdx" -o -name "*.json" \) \
  | xargs sed -i 's/\[Product Name\]/<project-name>/g'
```

Then: `bash $C3X init`

### Step 4: Identify Containers

Scan top-level directories and major package boundaries:
```bash
ls $DERIVED_REPO/src/ 2>/dev/null || ls $DERIVED_REPO/
```

Each logical subsystem becomes a Container. Always use sot-template naming:
- `c3-1-frontend` — client-side app
- `c3-2-backend` — server + business logic
- `c3-3-ui-layer` — design system + UI specs (if separate)

```bash
bash $C3X add container <slug> --c3-dir $SOT_REPO/.c3
```

### Step 5: Identify Components

For each container, scan major modules/features. Each becomes a Component.

```bash
bash $C3X add component <slug> --container c3-N --c3-dir $SOT_REPO/.c3
```

### Step 6: Add All 5 Refs

Always create all 5 — they're present in sot-template already, fill content from code:

```bash
# These exist from sot-template clone — fill from codebase:
# .c3/refs/ref-auth-pattern.md       ← from auth middleware / token logic
# .c3/refs/ref-error-handling.md     ← from error handlers / toast system
# .c3/refs/ref-ui-design-system.md   ← from theme/tokens/design system
# .c3/refs/ref-data-model.md         ← from Prisma/Zod/TypeScript types
# .c3/refs/ref-testing-strategy.md   ← from package.json test tools

bash $C3X wire c3-NNN cite ref-<slug> --c3-dir $SOT_REPO/.c3
```

### Step 7: Fill docs/api + docs/infra

- `docs/api/index.md` — document endpoints from route files / OpenAPI spec
- `docs/infra/env.md` — document env vars from `.env.example` + `process.env` grep

### Step 8: A2UI JSONL Generation

**For each frontend feature**, run the 5-pass extraction.
Full spec: `/home/node/.openclaw/workspace/skills/project-adopt/references/a2ui.md`

Quick reference:
1. Route inventory (framework-specific patterns)
2. Component tree from JSX return blocks
3. State extraction from `isLoading`/`isError`/XState patterns
4. Navigation graph from `router.push`/`navigate`/`<Link>`
5. AC synthesis in Given/When/Then

Output: `docs/ui/a2ui/<feature>.screens.jsonl`, `docs/ui/a2ui/<feature>.flow.jsonl`, `docs/ui/a2ui/design-system.jsonl`

### Step 9: Scaffold Code Map

```bash
bash $C3X codemap --c3-dir $SOT_REPO/.c3
```

Fill in glob patterns per component.

### Step 10: Validate

```bash
bash $C3X check --c3-dir $SOT_REPO/.c3
bash $C3X coverage --c3-dir $SOT_REPO/.c3
```

Validate JSONL:
```bash
for f in $SOT_REPO/docs/ui/a2ui/*.jsonl; do
  while IFS= read -r line; do
    echo "$line" | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))" \
      > /dev/null 2>&1 || echo "✗ Invalid JSON in $f: $line"
  done < "$f"
done
```

### Step 11: Human Review

```
🔍 Brownfield Ingest Complete

Discovered:
  • <N> containers, <N> components, 5 refs
  • A2UI: <N> features, <N> screens, <N> flows
  • API: <N> endpoints documented
  • Env vars: <N> documented
  • Coverage: <N>%

⚠️ Machine-generated map — review before marking as authoritative SOT.
Preview: http://localhost:<PREV_PORT>
```

### Step 12: Approval & Lock

Once human approves:
```bash
cd $SOT_REPO
git add -A
git commit -m "feat: initial SOT — reverse-engineered from <project-name>

- c3: <N> containers, <N> components, 5 refs
- A2UI JSONL: <feature-list>
- Coverage: <N>%"
git push -u origin main
```

SOT is now authoritative. All future changes go through draft → approve → merge.
