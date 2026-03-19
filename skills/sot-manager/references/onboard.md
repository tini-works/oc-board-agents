# Onboard Reference

Initialize a new SOT repository from scratch (greenfield) using sot-template as the base.

## Precondition

SOT_REPO directory exists but has no `.c3/`. If `.c3/` already exists → ask: re-onboard or cancel?

## Steps

### Step 1: Clarify Product Context

Ask (or assume if ASSUMPTION_MODE):
- Product name and type (mobile app, web API, monolith, microservices?)
- High-level system boundaries (what are the major containers?)
- Tech stack (optional — helps name components)

### Step 2: Scaffold from sot-template

Clone sot-template as the SOT repo base — do NOT start from scratch.

```bash
SOT_TEMPLATE="${SOT_TEMPLATE_REPO:-https://github.com/thanh-dong/sot-template.git}"

# Clone template into SOT_REPO
git clone --depth 1 $SOT_TEMPLATE $SOT_REPO
cd $SOT_REPO
rm -rf .git
git init

# Replace all [Product Name] placeholders
find . -type f \( -name "*.md" -o -name "*.mdx" -o -name "*.yaml" -o -name "*.json" \) \
  | xargs sed -i "s/\[Product Name\]/$PRODUCT_NAME/g"
```

> **Note:** `SOT_TEMPLATE_REPO` is read from the environment or TOOLS.md config.
> Default: `https://github.com/thanh-dong/sot-template.git`

This gives you out of the box:
- Full `.c3/` skeleton with all 5 refs pre-created
- `docs/` structure: architecture, api, frontend, ui/a2ui, infra, decisions
- `handoffs/SCHEMA.md` — handoff payload contract
- `active-crs.json` — CR state tracker
- GitHub Actions — approval + webhook workflows
- `.prev.yaml` — docs visualization config

### Step 3: Init c3 Structure

```bash
cd $SOT_REPO
bash $C3X init
```

### Step 4: Draft Context Document (c3-0)

Edit `.c3/README.md` — fill in:
- System name, goal, primary users
- Container table (high-level system parts)
- Tech stack (from product context gathered in Step 1)
- Update cross-cutting refs table — all 5 refs are already listed, verify they're correct

### Step 5: Scaffold Containers & Components

For each major container:
```bash
bash $C3X add container <slug> --c3-dir $SOT_REPO/.c3
bash $C3X add component <slug> --container c3-N --c3-dir $SOT_REPO/.c3
```

### Step 6: Fill the 5 Refs

The refs are already present from sot-template. Fill in product-specific content:

| Ref | What to fill |
|-----|-------------|
| `ref-auth-pattern.md` | Token schema, refresh strategy, storage rules |
| `ref-error-handling.md` | HTTP codes, error code enum, frontend display rules |
| `ref-ui-design-system.md` | Design tokens (colors, spacing, typography), component hierarchy |
| `ref-data-model.md` | Domain entities, field types, relationships |
| `ref-testing-strategy.md` | Test tools (from package.json), coverage targets, DoD checklist |

Wire refs to components:
```bash
bash $C3X wire c3-NNN cite ref-<slug> --c3-dir $SOT_REPO/.c3
```

### Step 7: Scaffold docs/

The `docs/` structure is already present from sot-template. Fill placeholders:

- `docs/api/index.md` — add initial endpoint stubs if known
- `docs/infra/env.md` — add known env variables
- `docs/architecture/index.mdx` — update Mermaid diagram for this product

### Step 8: Scaffold Code Map

```bash
bash $C3X codemap --c3-dir $SOT_REPO/.c3
```

For greenfield: leave all entries as `status: stub` — they'll be filled after implementation.

### Step 9: Validation

```bash
bash $C3X check --c3-dir $SOT_REPO/.c3
```

All must pass before proceeding.

### Step 10: Initial Commit

```bash
cd $SOT_REPO
git add -A
git commit -m "feat: init SOT for $PRODUCT_NAME (from sot-template)"

# If GitHub configured:
git remote add origin <github-url>
git push -u origin main
```

### Step 11: Inject CLAUDE.md into Derived Repo (if exists)

```bash
cat >> $DERIVED_REPO/CLAUDE.md << 'EOF'

# Architecture
This project uses a SOT repo for architecture governance.
SOT repo: <sot-repo-path>
For architecture questions, changes, audits → use `/c3` skill or `sot-manager` skill.
File lookup: `c3x lookup <file-or-glob>` maps files to components + refs.
EOF
```

### Step 12: Capabilities Reveal

```
✅ SOT initialized for <Product Name>

Structure:
  .c3/          ← architecture graph (c3-skill)
  docs/         ← human-readable docs (prev-cli)
  docs/ui/a2ui/ ← A2UI JSONL specs (agent-rendered UI)
  handoffs/     ← Coder Agent payloads

Your architecture toolkit:

| Command | What it does |
|---|---|
| "draft: add X feature" | Propose architecture change → CR |
| "visualize" | Open prev-cli docs preview |
| "approved" | Merge draft + trigger handoff |
| "audit" | Check SOT + Derived repo for drift |
| "what's the architecture?" | Query SOT state |
| "adopt this project" | Reverse-engineer existing code → SOT artifacts |
```
