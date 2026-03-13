# Verify & Handoff Phase

## Goal
Present the completed SOT to the user, get explicit approval,
then emit a handoff payload for downstream Coder Agents.

## Step 1: Generate Verification Report

Run and collect all outputs:

```bash
# Structural validation
bash $C3X check --c3-dir <sot-repo>/.c3 --json

# Full topology
bash $C3X list --c3-dir <sot-repo>/.c3 --compact

# Coverage stats
bash $C3X coverage --c3-dir <sot-repo>/.c3
```

## Step 2: Present to User

```
✅ SOT Adoption Complete: <project-name>

📐 Architecture Map
<c3x list --compact output>

📊 Coverage
<c3x coverage output>

🔍 Validation: <PASS / WARN / FAIL>
<list any warnings>

📁 SOT Repo: <path or GitHub URL>
🔗 Derived Repo: <path>

Next steps:
• Review the SOT docs in <sot-repo>/.c3/
• For any architecture changes → use sot-manager skill (draft → approve → merge)
• For code queries → `/c3 query <what you want to know>`
• For impact assessment → `/c3 sweep <what you're changing>`

Shall I emit a handoff payload for Coder Agents?
```

## Step 3: Visualize with prev-cli (optional but recommended)

If prev-cli is available:
```bash
PREV=/home/node/.npm-global/bin/prev
cd <sot-repo>
$PREV dev --port 3001 &
```

Share the preview URL with user so they can explore architecture visually.

## Step 4: Emit Handoff Payload (on approval)

Write to `<sot-repo>/handoffs/initial-adopt.json`:

```json
{
  "schema": "sot-handoff.v1",
  "event": "initial-adopt",
  "project": "<project-name>",
  "timestamp": "<ISO-8601>",
  "sot_repo": "<path-or-url>",
  "derived_repo": "<path-or-url>",
  "c3_summary": {
    "containers": <N>,
    "components": <N>,
    "refs": <N>,
    "coverage_pct": <N>
  },
  "containers": [
    {
      "id": "c3-1",
      "slug": "<name>",
      "purpose": "<description>",
      "tech": ["<stack>"],
      "components": [
        { "id": "c3-101", "slug": "<name>", "purpose": "<description>" }
      ]
    }
  ],
  "refs": [
    { "id": "ref-<slug>", "slug": "<slug>", "description": "<what it governs>" }
  ],
  "code_map_path": ".c3/code-map.yaml",
  "claude_md_injected": true
}
```

## Step 5: Save Config for Future ops

Append to user's TOOLS.md (or `<sot-repo>/.sot-manager-state.json`):

```
SOT_REPO: <sot-repo-path>
DERIVED_REPO: <derived-repo-path>
C3X: /home/node/.openclaw/workspace/skills/c3/bin/c3x.sh
GITHUB_TOKEN: <token if available>
GITHUB_REPO: <org/repo>
```

This enables the `sot-manager` skill to pick up where `project-adopt` left off.

## Failure Paths

| Condition | Action |
|-----------|--------|
| `c3x check` has errors | Fix before presenting — never show broken SOT |
| Coverage <40% | Warn user, offer to spend more time on code-map |
| User rejects proposal | Go back to analyze phase, re-propose |
| GitHub push fails | Save locally, provide manual push instructions |
