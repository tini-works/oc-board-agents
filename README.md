# sot-starter

> One-command setup for an OpenClaw workspace with the full SOT (Source of Truth) development workflow.

## What's included

### Skills

| Skill | Description |
|-------|-------------|
| **c3** | Architecture documentation tool (c3 graph, code-map) |
| **prev-cli** | Docs site + infinite board canvas + A2UIPreview |
| **sot-manager** | SOT lifecycle: draft → approve → merge → handoff |
| **project-adopt** | Reverse-engineer a codebase into a SOT (6-pass, includes A2UI JSONL) |
| **get-api-docs** | Fetch third-party API docs via chub before writing code |
| **qmd** | BM25 + semantic search across workspace markdown |
| **skill-creator-ultra** | Design and package new AI skills |

### Board Agents

| Agent | Trigger | Role |
|-------|---------|------|
| **board** | Automatic — every board session | Discussion host, SOT-aware facilitator. Read-only. |
| **sot-scribe** | `@sot-scribe` in board chat | Collects insights, generates c3/A2UI/API/data-model artifacts |
| **sot-editor** | Annotation thread → Request Update | Makes targeted edits to specific artifacts |

## Prerequisites

- [OpenClaw](https://openclaw.ai) installed and **configured** (`openclaw configure` done — this sets your API key)
- `git`
- `python3`
- `bun` or `node`

## Install

```bash
git clone https://github.com/thanh-dong/sot-starter
cd sot-starter
chmod +x install.sh
./install.sh
```

The installer prompts for:
- **GitHub PAT** — for cloning private repos (leave blank to skip)
- **GitHub username** — for cloning your prev-cli fork (leave blank to skip)

> No API key needed — `openclaw configure` already handles that.

> Credentials are applied to your local files only and **never stored in this repo**.

## What the installer does

1. Copies workspace files to `~/.openclaw/workspace/` (skips existing)
2. Installs all 7 skills (skips existing)
3. Installs board agent workspaces (`workspace-sot-scribe/`, `workspace-sot-editor/`)
4. Deep-merges `config/openclaw.patch.json` into `~/.openclaw/openclaw.json`
   - Appends sot-scribe and sot-editor to `agents.list` (never wipes existing agents)
   - Upgrades board agent to sonnet + SOT-aware system prompt
5. *(Optional)* Downloads c3x binary
6. *(Optional)* Clones and builds your `prev-cli` fork
7. *(Optional)* Installs `chub` CLI
8. *(Optional)* Seeds memory search index (`openclaw memory index --force`)
9. *(Optional)* Restarts the OpenClaw gateway

## After install

1. Edit `~/.openclaw/workspace/USER.md` — tell the agent who you are
2. Edit `~/.openclaw/workspace/SOUL.md` — customise the persona
3. Start a board:
   ```bash
   cd ~/.openclaw/workspace/prev-cli
   bun dist/cli.js -c /path/to/sot-repo/docs -p 3001
   ```
4. Open `http://localhost:3001` → **Board** → start discussing
5. Tag **@sot-scribe** when ready to generate SOT artifacts
6. Annotate artifacts → **Request Update** → **@sot-editor** makes the edit

## Re-running

The installer is idempotent: existing workspace files and skills are skipped. Safe to run again after a sot-starter update.

## Structure

```
sot-starter/
├── install.sh                      ← entry point
├── config/
│   └── openclaw.patch.json         ← merged into ~/.openclaw/openclaw.json
├── workspace/
│   ├── SOUL.md / AGENTS.md / ...   ← main agent persona files
│   ├── TOOLS.md                    ← credentials + SOT config template
│   └── skills/
│       ├── c3/
│       ├── prev-cli/
│       ├── sot-manager/
│       ├── project-adopt/
│       ├── get-api-docs/
│       ├── qmd/
│       └── skill-creator-ultra/
├── workspace-sot-scribe/           ← Scribe agent persona (SOUL, AGENTS, IDENTITY)
├── workspace-sot-editor/           ← Editor agent persona (SOUL, AGENTS, IDENTITY)
└── README.md
```

## License

MIT
