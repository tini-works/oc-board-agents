# Scaffold Phase

## Prerequisites
- Architecture proposal has been confirmed by user (or ASSUMPTION_MODE is active)
- SOT repo path is known (ask if not configured)
- `C3X` path is known: `/home/node/.openclaw/workspace/skills/c3/bin/c3x.sh`

## Step 1: Prepare SOT Repo

If SOT repo doesn't exist yet:
```bash
mkdir -p <sot-repo-path>
cd <sot-repo-path>
git init
```

If using GitHub, create repo via API:
```bash
curl -s -X POST https://api.github.com/user/repos \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"<project>-sot","description":"SOT for <project>","private":false}'
```

## Step 2: Initialize c3

```bash
cd <sot-repo-path>
bash $C3X init
```

Edit `.c3/README.md` (Context doc) to describe the project:
- What the system does
- Primary users
- Business domain
- Key technical decisions

## Step 3: Create Containers

For each container in the proposal:
```bash
bash $C3X add container <slug> --c3-dir <sot-repo>/.c3
```

Edit the generated container `README.md`:
- `purpose:` — what this container does
- `tech:` — stack (Next.js 14, Node 20, Python 3.12, etc.)
- `repo_path:` — relative path in derived repo (e.g., `apps/web`)
- `team:` — responsible team/person (if known)

## Step 4: Create Components

For each component in each container:
```bash
bash $C3X add component <slug> --container c3-N --c3-dir <sot-repo>/.c3
```

Edit the generated component doc:
- `purpose:` — feature responsibility
- `files:` — glob patterns pointing to derived repo files
- `status:` — `active` | `legacy` | `wip`
- Known boundaries and constraints

## Step 5: Add Cross-Cutting Refs

```bash
bash $C3X add ref <slug> --c3-dir <sot-repo>/.c3
```

For each ref, document:
- Pattern/convention being captured
- Which components it applies to
- Governing rules / constraints

Wire refs to components:
```bash
bash $C3X wire c3-NNN cite ref-<slug> --c3-dir <sot-repo>/.c3
```

## Step 6: Scaffold Code Map

```bash
bash $C3X codemap --c3-dir <sot-repo>/.c3
```

This generates `.c3/code-map.yaml`. Fill in glob patterns for each component
(paths are relative to the derived/implementation repo):

```yaml
c3-101:  # auth component
  - src/auth/**/*.ts
  - src/middleware/auth*.ts
c3-102:  # dashboard component
  - src/dashboard/**
_exclude:
  - "**/*.test.ts"
  - "**/*.spec.ts"
  - "**/*.d.ts"
  - dist/**
  - node_modules/**
```

## Step 7: Validate

```bash
bash $C3X check --c3-dir <sot-repo>/.c3
bash $C3X coverage --c3-dir <sot-repo>/.c3
```

Fix any `✗` errors before proceeding. Aim for >70% coverage on MEDIUM/LARGE projects.

## Step 8: Inject CLAUDE.md into Derived Repo

If the derived repo doesn't already have a CLAUDE.md:
```bash
cat >> <derived-repo>/CLAUDE.md << 'EOF'

# Architecture
This project uses C3 docs in a separate SOT repo.
SOT repo: <sot-repo-path>
For architecture questions, changes, audits → use `/c3` skill.
File lookup: `c3x lookup <file-or-glob>` maps files to components + refs.
EOF
```

## Step 9: Initial Commit

```bash
cd <sot-repo-path>
git add -A
git commit -m "feat: initial SOT — adopted from <project-name>"
```

If GitHub remote configured:
```bash
git remote add origin <github-url>
git push -u origin main
```

## Scaffold Complete Checklist

- [ ] c3 init done, Context doc filled
- [ ] All containers created + documented
- [ ] All components created + documented
- [ ] All cross-cutting refs created + wired
- [ ] Code map filled with glob patterns
- [ ] `c3x check` passes (zero errors)
- [ ] `c3x coverage` >60%
- [ ] CLAUDE.md injected into derived repo
- [ ] Initial commit pushed
