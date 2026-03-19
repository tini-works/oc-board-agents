---
name: project-adopt
description: |
  Adopt an existing codebase by analyzing its structure and automatically generating
  a full SOT repository conforming to sot-template structure.
  Use when: user says "adopt this project", "create SOT for my codebase",
  "analyze and document this project", "reverse-engineer architecture",
  "onboard this repo into SOT", "build architecture docs from existing code",
  or provides a project path and asks for SOT / architecture documentation.
  Handles the full pipeline: analyze → propose → scaffold full sot-template → A2UI JSONL → validate → handoff.
  Works standalone (no pre-configured SOT repo needed). Produces a ready-to-use
  SOT repo (sot-template structure) that sot-manager skill can then manage for ongoing changes.
---

# Project Adopt

Adopt an existing project into the full sot-template structure in one guided flow.

Output must match `sot-template` exactly — including `docs/ui/a2ui/` JSONL specs,
`docs/api/`, `docs/infra/env.md`, all 5 refs, and the handoff schema.

## Paths

| Keyword | Phase | Reference |
|---------|-------|-----------|
| analyze, scan, inspect, "what's in", "tell me about" | **Analyze only** | `references/analyze.md` |
| adopt, onboard, "create SOT", "build SOT", "scaffold SOT" | **Full pipeline** (all 4 phases) | all refs |
| scaffold, "create c3", "build c3 docs" | **Scaffold only** (skip analyze) | `references/scaffold.md` |
| verify, validate, "check SOT", handoff | **Verify only** | `references/verify.md` |

---

## Quick Config

At session start, check if config is already in TOOLS.md. If not, ask user for:

| Var | Description | Default |
|-----|-------------|---------|
| `PROJECT_PATH` | Path to the existing codebase | **(required)** |
| `SOT_REPO` | Where to create the SOT repo | `<project-path>-sot` (sibling dir) |
| `DERIVED_REPO` | Same as PROJECT_PATH usually | same as `PROJECT_PATH` |
| `C3X` | c3x script path | `/home/node/.openclaw/workspace/skills/c3/bin/c3x.sh` |
| `GITHUB_TOKEN` | For creating GitHub remote (optional) | from TOOLS.md |

If user says "just do it" or denies questions → `ASSUMPTION_MODE = true`, use defaults.

---

## Full Pipeline

### Phase 1 — Analyze
```bash
bash <skill-dir>/scripts/analyze_project.sh $PROJECT_PATH
```
Deep-scan entry points, detect framework + router + state + styling, identify containers/components/refs.
→ Present proposal → **wait for confirmation** (unless ASSUMPTION_MODE).
Details: `references/analyze.md`

### Phase 2 — Scaffold
Clone sot-template, init c3, create containers/components/refs, fill code-map.
Scaffold all docs: `docs/api/`, `docs/infra/env.md`, `docs/decisions/`.
→ Run `c3x check` — must pass before phase 3.
Details: `references/scaffold.md`

### Phase 3 — A2UI JSONL Generation
Convert existing frontend implementation into A2UI JSONL specs.
5 sub-passes per feature: route inventory → component tree → state extraction → navigation graph → AC synthesis.
Produces: `docs/ui/a2ui/<feature>.screens.jsonl` + `docs/ui/a2ui/<feature>.flow.jsonl` + `design-system.jsonl`.
Details: `references/scaffold.md` (A2UI section)

### Phase 4 — Verify & Handoff
Present final SOT map + coverage. Emit handoff JSON conforming to `handoffs/SCHEMA.md`. Save config to TOOLS.md.
Details: `references/verify.md`

---

## Key Tools

```bash
# Analyze script
bash /home/node/.openclaw/workspace/skills/project-adopt/scripts/analyze_project.sh <path>

# c3 CLI (all operations)
C3X=/home/node/.openclaw/workspace/skills/c3/bin/c3x.sh
bash $C3X init
bash $C3X add container <slug> --c3-dir <sot>/.c3
bash $C3X add component <slug> --container c3-N --c3-dir <sot>/.c3
bash $C3X add ref <slug> --c3-dir <sot>/.c3
bash $C3X codemap --c3-dir <sot>/.c3
bash $C3X check --c3-dir <sot>/.c3
bash $C3X coverage --c3-dir <sot>/.c3
bash $C3X list --c3-dir <sot>/.c3 --compact
```

---

## Hard Rules

1. **Never scaffold without a confirmed proposal** — always show the architecture map first
2. **`c3x check` must pass** before showing results to user
3. **Never commit to SOT main directly** — init commit is the only exception (initial adopt)
4. **Inject CLAUDE.md** into derived repo — so future agents know about the SOT
5. **Save config to TOOLS.md** after successful adopt — enables sot-manager to continue

---

## After Adoption

The SOT is now authoritative. Tell the user:
- Future architecture changes → use **sot-manager** skill (draft → approve → merge)
- Code queries → `/c3 query`
- Impact assessment → `/c3 sweep`
- Coverage check → `c3x coverage`

## ASSUMPTION_MODE

First "just do it" / denial of question → `ASSUMPTION_MODE = true`.
- No more questions
- Use defaults, mark with `[ASSUMED]`
- Proceed at full speed
