# Approve Reference

Approval can come from 3 sources (in priority order):

1. **GitHub PR merge** (primary) — human merges PR on GitHub → webhook → pipeline auto-runs
2. **prev-cli badge** (secondary) — human clicks "Approved" in prev-cli UI → webhook
3. **Chat command** (fallback) — human says "approve cr-NNN" → OpenClaw calls `/manual-approve`

> **If approval-listener is running (port 3999), sources 1 and 2 are fully automatic.**
> This reference is used only for: chat-triggered approval (source 3), or recovery.

---

## Preconditions

- CR exists in `active-crs.json` with status `pending_review`
- PR exists on GitHub (for source 1)
- `c3x check` was passing at last draft commit
- Approval-listener running: `curl http://localhost:3999/health`

---

## Chat-Triggered Approval (Source 3)

Accept phrases: "approve cr-001", "merge cr-001", "ship cr-001", "looks good cr-001"

Reject ambiguous: "maybe" or "sounds fine" is not approval. Ask to confirm.

```bash
# Trigger pipeline via listener
curl -s -X POST http://localhost:3999/manual-approve \
  -H "Content-Type: application/json" \
  -d "{\"cr_id\": \"$CR_ID\", \"approved_by\": \"$USER\"}"
```

If listener isn't running, run the steps below manually.

---

## Manual Steps (recovery / listener not running)

### Step 1: Identify CR

```bash
cat $SOT_REPO/active-crs.json
# Find cr_id, branch, files_changed
```

### Step 2: Final Validation

```bash
bash $C3X check --c3-dir $SOT_REPO/.c3
```

If fails: notify human, return to draft. **Never merge a broken SOT.**

### Step 3: Update ADR Status

```bash
bash $C3X set adr-YYYYMMDD-{slug} status implemented --c3-dir $SOT_REPO/.c3
git -C $SOT_REPO add .c3/adr/
git -C $SOT_REPO commit -m "chore: mark ADR as implemented [${CR_ID}]"
```

### Step 4: Merge to Main

```bash
cd $SOT_REPO
git checkout main
git merge --no-ff $BRANCH -m "feat: merge $BRANCH [$CR_ID] — approved"
```

### Step 5: Rebuild Structural Index

```bash
bash $C3X list --json --c3-dir $SOT_REPO/.c3 > /dev/null
```

### Step 6: Cleanup CR Instances

```bash
# Kill prev-cli instance
PREV_PID=$(python3 -c "import json; print(json.load(open('$SOT_REPO/active-crs.json')).get('$CR_ID', {}).get('prev_pid',''))" 2>/dev/null)
[ -n "$PREV_PID" ] && kill $PREV_PID 2>/dev/null || true

# Kill tunnel
TUNNEL_PID=$(python3 -c "import json; print(json.load(open('$SOT_REPO/active-crs.json')).get('$CR_ID', {}).get('tunnel_pid',''))" 2>/dev/null)
[ -n "$TUNNEL_PID" ] && kill $TUNNEL_PID 2>/dev/null || true

# Remove git worktree
git -C $SOT_REPO worktree remove --force /tmp/sot-preview-$CR_ID 2>/dev/null || true

# Remove from active-crs.json
python3 -c "
import json
f = '$SOT_REPO/active-crs.json'
crs = json.load(open(f))
crs.pop('$CR_ID', None)
open(f,'w').write(json.dumps(crs, indent=2))
"
```

### Step 7: Trigger Handoff

See `references/handoff.md`.

### Step 8: Notify Team

```
✅ **[${CR_ID}] ${SLUG}** — merged to SOT main

SOT updated. Structural index rebuilt. Handoff triggered → Derived repo notified.
Preview instance shut down.

Branch `${BRANCH}` can be deleted.
```

---

## Conflict Resolution

If merge has conflicts:
1. Report conflict to human with affected files
2. Ask human to resolve manually, or propose resolution and confirm
3. Never auto-resolve architectural conflicts silently

---

## GitHub Webhook Setup

To enable auto-trigger on PR merge, configure GitHub repo webhook:

```
URL:    http://<your-server>:3999/github-webhook
        (or tunnel URL if behind NAT)
Events: Pull requests
Secret: $GITHUB_WEBHOOK_SECRET (optional but recommended)
```
