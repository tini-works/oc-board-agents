# Onboard Reference

Initialize a new SOT repository from scratch (greenfield).

## Precondition

SOT_REPO directory exists but has no `.c3/`. If `.c3/` already exists → ask: re-onboard or cancel?

## Steps

### Step 1: Clarify Product Context

Ask (or assume if ASSUMPTION_MODE):
- Product name and type (mobile app, web API, monolith, microservices?)
- High-level system boundaries (what are the major containers?)
- Tech stack (optional — helps name components)

### Step 2: Init c3 Structure

```bash
cd $SOT_REPO
bash $C3X init
```

Creates: `.c3/README.md`, `.c3/adr/`, `.c3/refs/`, `.c3/recipes/`

### Step 3: Draft Context Document (c3-0)

Edit `.c3/README.md` — fill in:
- System name, goal, primary users
- Container table (high-level system parts)
- Tech stack

### Step 4: Scaffold Containers & Components

For each major container:
```bash
bash $C3X add container <slug> --c3-dir $SOT_REPO/.c3
bash $C3X add component <slug> --container c3-N --c3-dir $SOT_REPO/.c3
```

### Step 5: Scaffold docs/ for prev-cli

```bash
mkdir -p $SOT_REPO/docs
cp -r .c3/ $SOT_REPO/docs/architecture/  # or symlink
```

Or configure prev-cli to serve directly from `.c3/` with `.prev.yaml`:
```yaml
theme: system
contentWidth: constrained
```

### Step 6: Validation

```bash
bash $C3X check --c3-dir $SOT_REPO/.c3
```

All must pass before proceeding.

### Step 7: Initial Commit

```bash
cd $SOT_REPO
git add -A
git commit -m "chore: init SOT with c3 structure"
```

### Step 8: Inject CLAUDE.md

Add to SOT repo root:
```markdown
# Architecture Source of Truth
This repo is the SOT for [Product Name]. Governed by c3-skill.
All changes must be drafted by OpenClaw, validated with `c3x check`, and approved by a human before merging.
Do not edit main branch directly. Use OpenClaw's draft workflow.
```

### Step 9: Capabilities Reveal

```
SOT initialized. Your architecture toolkit:

| Command | What it does |
|---|---|
| "draft: add X feature" | Propose new architecture change |
| "visualize" | Open prev-cli docs review |
| "approved" | Merge draft + trigger handoff |
| "audit" | Check SOT + Derived repo for drift |
| "what's the current architecture" | Query SOT state |
```
