# Handoff Reference

Package the approved SOT state into a machine-readable payload for Coder Agents in the Derived repo.

## When to Run

- Automatically after approve+merge
- Or manually: "handoff", "trigger implementation", "send to devs"

## Handoff Payload Format

Write to `$SOT_REPO/handoffs/handoff-YYYYMMDD-HHMMSS-{slug}.json`:

```json
{
  "schema": "sot-handoff.v1",
  "timestamp": "YYYY-MM-DDTHH:MM:SSZ",
  "slug": "feature-slug",
  "adr": "adr-YYYYMMDD-slug",
  "sotCommit": "<git-sha>",
  "scope": {
    "containers": ["c3-1-name", "c3-2-name"],
    "components": ["c3-101-component", "c3-102-component"],
    "refs": ["ref-pattern-name"],
    "adrs": ["adr-YYYYMMDD-slug"]
  },
  "structuralIndex": "<path-to-.c3/_index/structural.md>",
  "codeMapPath": "<path-to-.c3/code-map.yaml>",
  "tasks": [
    {
      "id": "task-001",
      "component": "c3-101-component",
      "title": "Implement offline SQLite cache",
      "acceptanceCriteria": ["...", "..."],
      "files": ["src/lib/cache.ts"],
      "refs": ["ref-error-handling"],
      "priority": "high"
    }
  ],
  "chub_ids": ["github/octokit", "stripe/api"],
  "constraints": [
    "All files must be mapped to a c3 component ID in code-map.yaml",
    "PR cannot merge if c3x coverage reports unmapped files",
    "No architectural changes may originate in the Derived repo"
  ]
}
```

## Steps

### Step 1: Read Current SOT Topology

```bash
bash $C3X list --json --c3-dir $SOT_REPO/.c3
```

Extract affected entities from the last merged ADR.

### Step 2: Extract chub_ids from Component Specs

For each component in scope, scan its `.c3/` doc for an `## External APIs` section:

```bash
grep -h "^\`[a-z].*\/.*\`" $SOT_REPO/.c3/**/*.md 2>/dev/null | sed "s/\`//g; s/ —.*//g" | sort -u
```

Collect all chub IDs found → populate `chub_ids` array in the handoff payload.

### Step 3: Generate Task Breakdown

For each affected component:
- Read the component doc to extract requirements and acceptance criteria
- Check `c3x lookup` for any existing code-map entries
- Create one task per component

### Step 4: Write Payload

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTFILE="$SOT_REPO/handoffs/handoff-${TIMESTAMP}-${SLUG}.json"
mkdir -p $SOT_REPO/handoffs
# write JSON payload to $OUTFILE
```

### Step 5: Commit Handoff

```bash
cd $SOT_REPO
git add handoffs/
git commit -m "handoff: $SLUG → derived repo [$(date +%Y-%m-%d)]"
git push origin main
```

### Step 6: Notify Derived Repo

Options (implement whichever applies):
- **File watcher:** Drop payload in a shared `handoffs/` directory the Derived repo watches
- **Webhook:** POST to Derived repo's orchestrator endpoint
- **Git trigger:** Push to SOT main triggers a CI action in Derived repo

### Step 7: Confirm to User

```
📦 Handoff complete: **{SLUG}**

Payload: handoffs/handoff-{TIMESTAMP}-{SLUG}.json
Tasks: {N} components ready for implementation
Structural index: .c3/_index/structural.md

Coder Agents in the Derived repo have been notified.
```

---

## Coder Agent Instructions (embed in handoff or send separately)

```markdown
# Implementation Instructions

Read the handoff payload at: handoffs/handoff-{TIMESTAMP}-{SLUG}.json

Rules:
1. Read .c3/_index/structural.md FIRST — this is your full context map
2. **Fetch API docs BEFORE writing code** — if `chub_ids` is present in the payload:
   ```bash
   /home/node/.npm-global/bin/chub get <chub_ids...> --lang js -o .context/
   ```
   Read the docs in `.context/` before writing any code that calls those APIs.
   Use the `get-api-docs` skill for guidance.
3. For each file you create/modify, run: c3x lookup <file> to get constraints
4. After implementation, update .c3/code-map.yaml with your new files
5. PR must pass: c3x check && c3x coverage (no unmapped files)
6. Do not change architecture — if you hit a blocker, flag it back to OpenClaw
7. After completing each API integration, annotate learnings:
   ```bash
   /home/node/.npm-global/bin/chub annotate <id> "what you discovered"
   ```
```
