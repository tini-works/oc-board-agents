# Verify & Handoff Phase

## Goal
Present the completed SOT, get explicit approval, emit a handoff payload
conforming to `handoffs/SCHEMA.md` in the sot-template.

---

## Step 1: Generate Verification Report

```bash
# Structural validation
bash $C3X check --c3-dir <sot-repo>/.c3 --json

# Full topology
bash $C3X list --c3-dir <sot-repo>/.c3 --compact

# Coverage stats
bash $C3X coverage --c3-dir <sot-repo>/.c3
```

A2UI verification:
```bash
# Count JSONL entries per feature
for f in <sot-repo>/docs/ui/a2ui/*.jsonl; do
  echo "$f: $(wc -l < "$f") entries"
done

# Validate all JSONL
for f in <sot-repo>/docs/ui/a2ui/*.jsonl; do
  echo "=== $f ==="
  while IFS= read -r line; do
    echo "$line" | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))" \
      2>&1 | grep -v '^$' || true
  done < "$f"
done
```

---

## Step 2: Present to User

```
✅ SOT Adoption Complete: <project-name>

📐 Architecture Map
<c3x list --compact output>

📊 Coverage: <N>%
<c3x coverage output>

🎨 A2UI JSONL
  - design-system.jsonl: <N> tokens, <N> components
  - <feature>.screens.jsonl: <N> screens
  - <feature>.flow.jsonl: <N> flows
  (total features: <N>)

📄 API Contracts: <N> endpoints documented
🌍 Env vars: <N> variables documented
📋 Data model: <N> entities

🔍 Validation: <PASS / WARN / FAIL>
<list any warnings>

📁 SOT Repo: <path or GitHub URL>
🔗 Derived Repo: <path>

Next steps:
• Architecture changes → sot-manager skill (draft → approve → merge)
• Code queries → /c3 query
• Impact assessment → /c3 sweep
• A2UI rendering → canvas a2ui_push with JSONL from docs/ui/a2ui/

Shall I emit a handoff payload?
```

---

## Step 3: Visualize with prev-cli (optional but recommended)

```bash
PREV=/home/node/.npm-global/bin/prev
cd <sot-repo>
$PREV dev --port 3001 &
```

Share preview URL so the user can explore architecture + A2UI flows visually.

---

## Step 4: Emit Handoff Payload

Write to `<sot-repo>/handoffs/initial-adopt.json`, conforming to `handoffs/SCHEMA.md`:

```json
{
  "cr": "initial-adopt",
  "slug": "<project-name>-adopt",
  "approved_at": "<ISO-8601>",
  "approved_by": "<user>",

  "title": "Initial SOT adoption: <project-name>",
  "description": "Full SOT reverse-engineered from existing codebase",

  "c3_components": ["<all component IDs>"],

  "a2ui": ["<all .jsonl paths relative to sot-repo>"],

  "api_endpoints": ["<all documented endpoint strings>"],

  "entities": ["<all entity names from ref-data-model>"],

  "refs": [
    "ref-auth-pattern",
    "ref-error-handling",
    "ref-ui-design-system",
    "ref-data-model",
    "ref-testing-strategy"
  ],

  "chub_ids": [],

  "derived_repo": "<derived-repo-path-or-url>",
  "target_branch": "main",

  "adr": null,

  "done_when": [
    "All AC items in each c3 component pass",
    "c3x check passes",
    "c3x coverage >60%",
    "All JSONL files validate",
    "CLAUDE.md injected into derived repo"
  ],

  "meta": {
    "schema": "sot-handoff.v1",
    "event": "initial-adopt",
    "sot_repo": "<sot-repo-path-or-url>",
    "c3_summary": {
      "containers": "<N>",
      "components": "<N>",
      "refs": 5,
      "coverage_pct": "<N>"
    },
    "a2ui_summary": {
      "features": "<N>",
      "screens": "<N>",
      "flows": "<N>",
      "components": "<N>",
      "tokens": "<N>"
    }
  }
}
```

---

## Step 5: Save Config for sot-manager

Append to user's TOOLS.md:

```markdown
### SOT: <project-name>
- **SOT_REPO:** <sot-repo-path>
- **DERIVED_REPO:** <derived-repo-path>
- **C3X:** /home/node/.openclaw/workspace/skills/c3/bin/c3x.sh
- **GITHUB_TOKEN:** (from existing entry)
- **GITHUB_REPO:** <org/repo>
- **Adopted:** <date>
- **Status:** active — use `sot-manager` skill for future feature development
```

---

## Failure Paths

| Condition | Action |
|-----------|--------|
| `c3x check` has errors | Fix before presenting — never show broken SOT |
| Coverage <40% | Warn user, offer to improve code-map |
| JSONL validation fails | Fix invalid lines before handoff |
| User rejects proposal | Return to analyze phase, re-propose |
| GitHub push fails | Save locally, provide manual push instructions |
| No frontend found | Skip A2UI phase, note in handoff `a2ui: []` |
