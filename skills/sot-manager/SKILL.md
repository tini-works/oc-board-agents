---
name: sot-manager
description: |
  Use when managing the Source of Truth (SOT) architecture repository for agentic
  software development. OpenClaw acts as the custodian of a c3-skill governed SOT repo.
  Handles the full lifecycle: onboarding a project, drafting architecture changes,
  visualizing with prev-cli, waiting for human approval, merging, and handing off to
  the Derived implementation repo.
  Trigger phrases: "onboard this project", "add a feature to SOT", "draft architecture for X",
  "visualize the SOT", "I approve", "reject the proposal", "handoff to implementation",
  "audit the derived repo", "what's the current architecture", "SOT status",
  "reverse-engineer this codebase", "init the SOT", "what changed in SOT".
---

# Goal

Act as the **Lead Architect and SOT Custodian** for an agentic software development pipeline.

When a change request arrives:
1. **Propose a solution concept** — summarize the approach, confirm with user
2. **Draft architecture** — ADR + c3 entities (containers, components, refs) on a branch
3. **Draft UI/UX docs** — user flows (Mermaid), screen specs, design system updates in `docs/ui/`
4. **Visualize** — serve with prev-cli so the reviewer sees the full proposal
5. **Gate approval** — approval-listener auto-merges + generates handoff on click "Approved"
6. **Handoff** — emit a machine-readable payload for Coder Agents in the Derived repo

Never corrupt the SOT main branch. All changes go through draft → approve → merge.

---

# Architecture

```
User A ──► OpenClaw (custodian) ◄── User B
                    │
         ┌──────────┴──────────┐
         │                     │
    CR-001 (branch)        CR-002 (branch)
    GitHub PR #1           GitHub PR #2
    prev-cli :3001         prev-cli :3002
    tunnel: cr-001.X       tunnel: cr-002.X
         │                     │
         └──────────┬──────────┘
                    │
              SOT Repo main
              (.c3/ + docs/)
              governed by c3x
                    │
              Derived Repo
              (read-only audit)
                    │
              Coder Agents
              (receive handoff)
```

**Two strict repos. No exceptions:**
- **SOT Repo** — architecture only. Zero executable code. Governed by c3-skill.
- **Derived Repo** — implementation only. No architectural decisions originate here.

**Team review gate — dual-layer:**
- **GitHub PR**: raw diff review (line-by-line changes, comments, approval)
- **prev-cli preview**: rendered UI flows, diagrams, MDX components (shareable via tunnel)
- **Approval signal**: GitHub PR merge (primary) or chat "approve cr-NNN" (secondary)

---

# Key Config (store in TOOLS.md)

```
SOT_REPO:           /path/to/sot-repo
DERIVED_REPO:       /path/to/derived-repo
PREV_PORT_BASE:     3001          # ports allocated from this base (3001, 3002, ...)
C3X:                /home/node/.openclaw/workspace/skills/c3/bin/c3x.sh
PREV:               /home/node/.npm-global/bin/prev
GITHUB_TOKEN:       ghp_xxx       # for creating PRs via GitHub API
GITHUB_REPO:        org/sot-repo  # GitHub repo slug
TUNNEL_DOMAIN:      sot.yourdomain.com  # base domain for per-CR tunnels (cr-001.sot.yourdomain.com)
OPENCLAW_WEBHOOK_URL: http://localhost:PORT/webhook  # optional: notify this session on events
```

---

# Operations

| User says | Op | Reference |
|---|---|---|
| init, onboard, scaffold, "greenfield", "start SOT" | **onboard** | `references/onboard.md` |
| "brownfield", "audit this codebase", "reverse-engineer" | **ingest** | `references/ingest.md` |
| "add feature", "draft", "propose", "change X", "design Y" | **draft** | `references/draft.md` |
| "visualize", "show me the SOT", "preview docs" | **visualize** | `references/draft.md` |
| "approve cr-NNN", "merge cr-NNN" (chat fallback) | **approve** | `references/approve.md` |
| "reject", "revise", "change the proposal", "not right" | **revise** | `references/draft.md` |
| "handoff", "trigger implementation", "send to devs" | **handoff** | `references/handoff.md` |
| "audit", "check drift", "coverage", "what's unmapped" | **audit** | `references/audit.md` |
| "list crs", "active changes", "what's in review" | **status** | see CR State below |
| "start listener", "watch for approvals", "start webhook server" | **listen** | see Webhook Listener below |

---

# CR State

Track all concurrent CRs in `$SOT_REPO/active-crs.json`:

```json
{
  "cr-001": {
    "id": "cr-001",
    "slug": "auth-redesign",
    "user": "thnh",
    "branch": "draft/cr-001-auth-redesign",
    "pr_number": 42,
    "pr_url": "https://github.com/org/sot/pull/42",
    "prev_port": 3001,
    "prev_pid": 12345,
    "tunnel_url": "https://sot-cr-001.yourdomain.com",
    "tunnel_pid": 12346,
    "status": "pending_review",
    "created_at": "2026-03-09T08:00:00Z",
    "files_changed": ["docs/ui/flows/auth.mdx", ".c3/c3-1/c3-101-auth.md"]
  }
}
```

**Status values:** `drafting` → `pending_review` → `approved` → `merged`

**Conflict detection:** Before starting a new CR, check if any `files_changed` overlap with active CRs. Warn user if overlap found.

---

# Webhook Listener

The approval listener runs as a background process. Receives:
- **GitHub PR merge webhook** (primary) — fires when PR is merged on GitHub
- **prev-cli approval webhook** (secondary) — fires when "Approved" clicked in prev-cli UI
- **Chat approval** (fallback) — "approve cr-NNN" from user in chat

## Start

```bash
bash /home/node/.openclaw/workspace/skills/sot-manager/bin/start-listener.sh \
  --sot-repo $SOT_REPO \
  --port 3999 \
  --derived-repo $DERIVED_REPO
```

## Routes

| Method | Path | Action |
|---|---|---|
| POST | /github-webhook | GitHub PR merge event → lookup CR by branch → run pipeline |
| POST | /sot-approval | prev-cli approval badge → secondary trigger |
| POST | /manual-approve | Chat-triggered approval with `{ cr_id }` body |
| GET | /health | Current config + active CRs |
| GET | /active-crs | List all active CRs with status |

## Pipeline (on approved — any source)

1. Lookup CR by branch name / cr_id from `active-crs.json`
2. `c3x check` — validates SOT integrity; aborts if fails
3. `git merge --no-ff <branch>` → main (skip if GitHub already merged)
4. `c3x list` — rebuilds structural index
5. `prev build` — generates static artifact
6. Write `handoffs/<cr-id>.json` payload
7. Kill prev-cli instance + tunnel for this CR
8. Remove CR from `active-crs.json`
9. POST to `OPENCLAW_WEBHOOK_URL` → notifies team in chat

## Wire into .prev.yaml

```yaml
approval:
  enabled: true
  webhookUrl: http://localhost:3999/sot-approval
```

## Notify OpenClaw (optional)

Set `OPENCLAW_WEBHOOK_URL` to receive pipeline completion events back in chat.
Use with OpenClaw's built-in webhook ingest endpoint.

---

# Dispatch

1. Classify op from user message (ambiguous → ask with options above)
2. Check preconditions (SOT_REPO configured? `.c3/` exists?)
3. Load `references/<op>.md`
4. Execute — use parallel steps where possible

---

# Preconditions

**Before every op except onboard/ingest:**
```bash
bash $C3X list --c3-dir $SOT_REPO/.c3 --json
```
Fails/empty → route to **onboard**

**Before draft:**
```bash
cd $SOT_REPO && git status --short
```
Dirty working tree → stash or warn before branching.

---

# Hard Rules

1. **Never commit to SOT main directly** — all changes go to a draft branch first
2. **c3x check must pass** before any visualization or merge
3. **Approval must be explicit** — "approved", "approve", "ship it", "merge it", or equivalent
4. **Rejection returns to draft** — never silently discard a proposal
5. **Handoff only after merge** — no handoff from a draft branch
6. **Derived repo is read-only** — audit only, never write
7. **ADR before any change** — same rule as c3-skill: `c3x add adr <slug>` is always first

---

# ASSUMPTION_MODE

First "don't ask me" or denial of clarification → `ASSUMPTION_MODE = true` for session.
- Never call AskUserQuestion again
- State assumptions inline with [ASSUMED] tag
- Proceed with high-confidence defaults

---

# Shared State

Track global config in `$SOT_REPO/.sot-manager-state.json`:
```json
{
  "version": "2.0",
  "productName": "My App",
  "sotRepo": "/path/to/sot-repo",
  "derivedRepoPath": "/path/to/derived",
  "c3xPath": "/home/node/.openclaw/workspace/skills/c3/bin/c3x.sh",
  "prevPath": "/home/node/.npm-global/bin/prev",
  "listenerPid": 4522,
  "listenerPort": 3999,
  "prevPortBase": 3001,
  "githubRepo": "org/sot-repo",
  "tunnelDomain": "sot.yourdomain.com",
  "lastMergeAt": "2026-03-06T08:00:00Z",
  "lastMergedCR": "cr-001",
  "lastHandoffPath": null
}
```

Per-CR state lives in `$SOT_REPO/active-crs.json` (see CR State section above).
`activeDraftBranch` and `proposalStatus` are **deprecated** — use `active-crs.json` instead.

---

# Operations Summary

### onboard
Init `.c3/` in SOT repo, scaffold context/containers/components, inject CLAUDE.md.
Details: `references/onboard.md`

### ingest
Reverse-engineer existing codebase into c3 structure (brownfield).
Details: `references/ingest.md`

### draft
Change request → solution concept → ADR → c3 entities → UI/UX docs → c3x check → prev-cli review.
Details: `references/draft.md`

### approve
Merge draft branch to main, update structural index, emit handoff payload.
Details: `references/approve.md`

### handoff
Package c3 structural index + component spec → JSON payload for Coder Agents.
Details: `references/handoff.md`

### audit
Run c3x check + c3x coverage against both repos. Report drift.
Details: `references/audit.md`

<!-- Generated by Skill Creator Ultra v1.0 evaluation pass -->
