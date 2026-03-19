---
name: sft
description: |
  Use when working with UI behavioral specifications, screen flows, or user interaction modeling.
  SFT (Screens, Flows, Transitions) is a lightweight vocabulary for making implicit UI structure explicit.
  Event-driven, layered state machines in YAML.
  Trigger phrases: "UI spec", "screen flow", "user journey", "state machine", "SFT",
  "create a flow", "map screens", "transition diagram", "UI behavior", "mockup spec"
---

# SFT — Screens, Flows, Transitions

CLI: `bash /home/node/.openclaw/workspace/skills/sft/bin/sft.sh <command> [args]`

## Quick Reference

| Command | Purpose |
|---------|---------|
| `sft add app <name> <desc>` | Create app |
| `sft add screen <name> <desc>` | Create screen |
| `sft add region <name> <desc> --in <parent>` | Create region |
| `sft add event <name> --in <region>` | Create event |
| `sft add transition --on <event> --in <owner> [--from <s>] [--to <s>] [--action <a>]` | Create transition |
| `sft show` | Full spec tree (human readable) |
| `sft show --json` | Full spec (JSON) |
| `sft query screens` | List all screens |
| `sft query events` | List all events |
| `sft query states <name>` | Transitions for a screen/region |
| `sft validate` | Check for orphans, dead events, cycles |
| `sft import <file>` | Import YAML spec |
| `sft export [file]` | Export to YAML |

## Core Concepts

- **App** — Top-level boundary. One deployable app = one App.
- **Screen** — What the user sees. A viewport grouping of Regions.
- **Region** — Building block. Own content, own events. May contain sub-regions (1 level max).
- **Events** — Declared on the Region that emits them.
- **Tags** — [condition] for existence, [overlay] for rendering.
- **Flows** — Key user journeys worth communicating to the team.

## State Machines

State machines live at the layer they belong to. Events bubble up: Sub-Region → Region → Screen → App.

Transition format:
```yaml
states:
  - on: <event>        # event that triggers
    from: <state>      # guard (current state)
    to: <state>        # target state
    action: <effect>   # navigate(), emit()
```

## Usage Patterns

1. **Create new spec**: `sft add app <name> <desc>`
2. **Add screens**: `sft add screen Inbox "Email list view"`
3. **Add regions**: `sft add region EmailList --in Inbox`
4. **Add events**: `sft add event select-email --in EmailList`
5. **Define transitions**: `sft add transition --on select-email --in Inbox --from browsing --to viewing`
6. **Validate**: `sft validate`
7. **Export**: `sft export spec.yaml`

## File Structure

SFT specs are stored in `.sft/db` (auto-created when you run commands).

## Example Workflow

```bash
# Create a new app
sft add app Email "Email client"

# Add screens
sft add screen Inbox "List of emails"
sft add screen ThreadView "Single email view"

# Add regions
sft add region EmailList --in Inbox
sft add region ReplyComposer --in ThreadView

# Add events
sft add event select-email --in EmailList
sft add event start-reply --in ReplyComposer

# View the spec
sft show

# Validate
sft validate
```
