# Ingest Reference (Brownfield)

Reverse-engineer an existing codebase into a c3-skill SOT structure.

## When to Use

- Existing codebase with no `.c3/` directory
- User says "audit this codebase", "reverse-engineer", "build SOT from existing code"

## Warning

This is a best-effort archaeological process. The agent maps what it can infer from code structure.
Human review is mandatory before the SOT is treated as authoritative.

## Steps

### Step 1: Scope Assessment

```bash
find $DERIVED_REPO -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.go" \) \
  | grep -v node_modules | grep -v dist | grep -v .next \
  | wc -l
```

Report file count to user. Estimate complexity: <100 files = small, 100-500 = medium, 500+ = large.

### Step 2: Init SOT

```bash
cd $SOT_REPO
bash $C3X init
```

### Step 3: Identify Containers

Scan top-level directories and major package boundaries:
```bash
ls $DERIVED_REPO/src/ 2>/dev/null || ls $DERIVED_REPO/
```

Each logical subsystem (e.g., `frontend/`, `api/`, `worker/`, `shared/`) becomes a Container.

```bash
bash $C3X add container <slug> --c3-dir $SOT_REPO/.c3
```

### Step 4: Identify Components

For each container, scan for major modules/features:
- React: major page or feature directories
- Node/Go: service files, route handlers, domain modules
- Each becomes a Component

```bash
bash $C3X add component <slug> --container c3-N --c3-dir $SOT_REPO/.c3
```

### Step 5: Scaffold Code Map

```bash
bash $C3X codemap --c3-dir $SOT_REPO/.c3
```

This generates `.c3/code-map.yaml` stubs for every component. Fill in glob patterns:

```yaml
c3-101:  # UserAuth component
  - src/auth/**/*.ts
  - src/middleware/auth.ts
_exclude:
  - "**/*.test.ts"
  - "**/*.spec.ts"
  - dist/**
```

### Step 6: Identify Cross-Cutting Refs

Look for: shared utilities, error handling patterns, API contracts, auth middleware.
Each becomes a Ref:

```bash
bash $C3X add ref <slug> --c3-dir $SOT_REPO/.c3
```

### Step 7: Wire Dependencies

```bash
bash $C3X wire c3-NNN cite ref-$PATTERN --c3-dir $SOT_REPO/.c3
```

### Step 8: Validate

```bash
bash $C3X check --c3-dir $SOT_REPO/.c3
bash $C3X coverage --c3-dir $SOT_REPO/.c3
```

### Step 9: Human Review

Notify user with:
```
🔍 Brownfield Ingest Complete

Discovered:
- {N} containers
- {N} components
- {N} cross-cutting refs
- Coverage: {N}% of source files mapped

Review the architecture at: http://localhost:{PREV_PORT}

⚠️ This is a machine-generated map. Please review and correct before approving as authoritative SOT.
```

### Step 10: Approval & Lock

Once human approves the ingest:
```bash
cd $SOT_REPO
git add -A
git commit -m "feat: initial SOT — reverse-engineered from derived repo"
```

SOT is now authoritative. From this point, all changes go through the draft → approve → merge workflow.
