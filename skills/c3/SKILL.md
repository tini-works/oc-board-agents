---
name: c3
description: |
  Use when the user invokes /c3 or asks architecture questions about a codebase.
  Handles 6 operations: onboard (scaffold .c3/ docs), query (where is X, explain Y),
  audit (validate docs, check drift), change (add feature, implement X, refactor),
  ref (document a pattern or convention), sweep (what breaks if I change X).
  Trigger phrases: "/c3", "adopt C3", "onboard this project", "where is auth",
  "audit the architecture", "check the docs", "add a component", "add rate limiting",
  "implement feature X", "what breaks if I change X", "add a ref for X",
  "document this pattern", "impact assessment", "create architecture docs",
  ".c3 directory", "c3x", "C3 docs".
---

# C3

CLI: `bash /home/node/.openclaw/workspace/skills/c3/bin/c3x.sh <command> [args]`

| Command | Purpose |
|---------|---------|
| `init` | Scaffold `.c3/` |
| `list` | Topology (`--json`, `--flat`, `--compact`) |
| `check` | Structural validation (`--json`) |
| `add <type> <slug>` | Create entity (`--container`, `--feature`) |
| `codemap` | Scaffold `.c3/code-map.yaml` with stubs for all components + refs |
| `lookup <file-or-glob>` | File or glob → component + refs (`--json`) |
| `coverage` | Code-map coverage stats (JSON default) |

Types for `add`: `container`, `component`, `ref`, `adr`, `recipe`

---

## Intent Classification

| Keywords | Op | Reference |
|----------|----|-----------|
| adopt, init, scaffold, bootstrap, onboard, "create .c3", "set up architecture" | **onboard** | `references/onboard.md` |
| where, explain, how, diagram, trace, "show me", "what is", "list components" | **query** | `references/query.md` |
| audit, validate, "check docs", drift, "docs up to date", "verify docs" | **audit** | `references/audit.md` |
| add, change, fix, implement, refactor, remove, migrate, provision, design | **change** | `references/change.md` |
| pattern, convention, "create ref", "update ref", "list refs", standardize | **ref** | `references/ref.md` |
| impact, "what breaks", assess, sweep, "is this safe" | **sweep** | `references/sweep.md` |
| recipe, "trace end-to-end", "cross-cutting flow", "how does X flow" | **query** (read) / **change** (create) | `references/query.md` / `references/change.md` |

---

## Dispatch

1. Classify op (ambiguous → `AskUserQuestion` with 6 options)
2. Load `references/<op>.md`
3. Execute (use Task tool for parallelism)

---

## Precondition

Before every op except onboard:
```bash
bash /home/node/.openclaw/workspace/skills/c3/bin/c3x.sh list --json
```
Fails/empty → route to **onboard**

---

## ASSUMPTION_MODE

First `AskUserQuestion` denial → `ASSUMPTION_MODE = true` for session.
- Never call `AskUserQuestion` again
- High-impact: state assumption, mark `[ASSUMED]`
- Low-impact: auto-proceed

---

## Shared Rules

**Run `c3x check` frequently** — after creating/editing any `.c3/` doc. It catches broken YAML frontmatter, missing required sections, bad entity references, and codemap issues. Treat errors (`✗`) as blockers.

**HARD RULE — ADR is the unit of change:**
Every **change** operation MUST start with `c3x add adr <slug>` as its FIRST action.
No code reads, no file edits, no exploration before the ADR exists.
(Exception: **ref-add** creates its adoption ADR at completion — see `references/ref.md`.)
The ADR is an ephemeral work order — it drives what to update, then gets hidden.
`c3x list` and `c3x check` exclude ADRs by default; use `--include-adr` to see them.

**Stop immediately if:**
- No ADR exists for current change → `c3x add adr <slug>` NOW
- Guessing intent → `AskUserQuestion` (skip if ASSUMPTION_MODE)
- Jumping to component → start Context down
- Updating docs without code check

**File Context — MANDATORY before reading or altering any file:**
```bash
bash /home/node/.openclaw/workspace/skills/c3/bin/c3x.sh lookup <file-path>
bash /home/node/.openclaw/workspace/skills/c3/bin/c3x.sh lookup 'src/auth/**'   # glob for directory-level context
```
Returned refs = hard constraints, every one MUST be honored.
Run the moment any file path surfaces. Use glob when working across a directory.
No match = uncharted, proceed with caution.

**Layer Navigation:** Context → Container → Component

**File Structure:**
```
.c3/
├── README.md                    # Context (c3-0)
├── adr/adr-YYYYMMDD-slug.md
├── refs/ref-slug.md
├── recipes/recipe-slug.md
└── c3-N-name/
    ├── README.md                # Container
    └── c3-NNN-component.md
```

---

## Operations

### onboard
No `.c3/` or re-onboard. `c3x init` → discovery → inject CLAUDE.md → show capabilities.
Details: `references/onboard.md`

### query
`c3x list` → match entity → Read doc → explore code.
Details: `references/query.md`

### audit
`c3x check` → `c3x list --json` → semantic phases. Output: PASS/WARN/FAIL table.
Details: `references/audit.md`

### change
ADR first (`c3x add adr`) → `c3x list --json` → `c3x lookup` each file → fill ADR (impact, work breakdown) → approve → execute → `c3x check`.
Provision gate: implement now or `status: provisioned`.
Details: `references/change.md`

### ref
Modes: Add / Update / List / Usage.
Details: `references/ref.md`

### sweep
`c3x list --json` → affected entities → parallel assessment → synthesize. Advisory only.
Details: `references/sweep.md`

---

## CLAUDE.md Injection (onboard)

```markdown
# Architecture
This project uses C3 docs in `.c3/`.
For architecture questions, changes, audits, file context -> `/c3`.
Operations: query, audit, change, ref, sweep.
File lookup: `c3x lookup <file-or-glob>` maps files/directories to components + refs.
```

## Capabilities Reveal (onboard)

```
## Your C3 toolkit is ready

| Command | What it does |
|---------|-------------|
| `/c3` query | Ask about architecture |
| `/c3` audit | Validate docs |
| `/c3` change | Modify architecture |
| `/c3` ref | Manage patterns |
| `/c3` sweep | Impact assessment |
| `/c3` recipe | Trace cross-cutting concern end-to-end |
| `c3x lookup <file-or-glob>` | File or directory → components + governing refs |
| `c3x coverage` | See what's mapped, excluded, unmapped |

Just say `/c3` + what you want.
```
