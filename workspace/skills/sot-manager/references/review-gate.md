# ReviewGate Reference

ReviewGate closes the loop between the prev-cli UI and the sot-manager approve flow.
When a reviewer clicks "approved" in the docs UI, ReviewGate automatically triggers
the OpenClaw approve flow — no manual message needed.

## Architecture

```
prev dev (docs UI)
  └── StatusDropdown → POST /__prev/approval
        └── prev-cli server → POST http://localhost:3099/webhook (webhookUrl in .prev.yaml)
              └── ReviewGate server
                    └── writes .review-gate-pending.json to SOT repo
                          └── OpenClaw heartbeat detects trigger
                                └── runs approve flow automatically
                                      └── notifies user ✅
```

## Files

| File | Purpose |
|---|---|
| `workspace/review-gate/server.ts` | Bun HTTP webhook receiver |
| `workspace/review-gate/start.sh` | Start script |
| `workspace/review-gate/check-trigger.sh` | Heartbeat helper — checks for pending trigger |
| `$SOT_REPO/.review-gate-pending.json` | Trigger file written on approval |
| `$SOT_REPO/.prev.yaml` | Must have `approval.webhookUrl: http://localhost:3099/webhook` |

## Server Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/` | Status + recent events + pending trigger |
| `POST` | `/webhook` | Receive `prev-approval.v1` events |
| `DELETE` | `/trigger` | Clear pending trigger (called after approve completes) |

## Starting ReviewGate

```bash
# With SOT repo path
SOT_REPO=/path/to/sot-repo ~/.openclaw/workspace/review-gate/start.sh

# Or with flag
~/.openclaw/workspace/review-gate/start.sh --sot-repo /path/to/sot-repo --port 3099
```

Store the PID in `.sot-manager-state.json` as `reviewGatePid`.

## Trigger File Format

Written to `$SOT_REPO/.review-gate-pending.json`:

```json
{
  "pending": true,
  "page": "architecture/index",
  "status": "approved",
  "triggeredAt": "2026-03-07T05:00:00Z",
  "sotRepo": "/path/to/sot-repo",
  "webhookPayload": { ... }
}
```

## Heartbeat Integration

The heartbeat checks for this file. When found:

1. Read `.review-gate-pending.json` from the active SOT repo
2. Confirm the trigger is for the active draft (cross-check `.sot-manager-state.json`)
3. Run the approve flow (`references/approve.md`)
4. After approve completes: `DELETE http://localhost:3099/trigger` to clear
5. Notify user: "✅ Auto-approved via ReviewGate — page: {page}"

## .prev.yaml Config

Every SOT repo needs this in `.prev.yaml`:

```yaml
approval:
  enabled: true
  webhookUrl: http://localhost:3099/webhook
```

This is included in the SOT template by default.

## State Tracking

Add `reviewGatePid` and `reviewGatePort` to `.sot-manager-state.json`:

```json
{
  "reviewGatePid": 12345,
  "reviewGatePort": 3099
}
```

Start ReviewGate as part of `draft` operation. Kill on `approve` completion.

## Statuses

Only `approved` writes a trigger. Other statuses are logged but ignored:
- `draft` — no action
- `in-review` — no action  
- `needs-changes` — no action (user should respond to the page comments)
- `approved` → **writes trigger**
