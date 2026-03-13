# sot-starter

> One-command setup for an OpenClaw workspace with the full SOT (Source of Truth) development workflow.

## What's included

| Component | Description |
|-----------|-------------|
| **Workspace files** | SOUL.md, AGENTS.md, USER.md, TOOLS.md, MEMORY.md, HEARTBEAT.md |
| **c3** | Architecture documentation tool |
| **prev-cli** | Docs site + infinite board canvas |
| **sot-manager** | SOT lifecycle manager (draft → approve → merge → handoff) |
| **project-adopt** | Reverse-engineer a codebase into a c3-governed SOT |
| **get-api-docs** | Fetch third-party API docs via chub before writing code |
| **qmd** | BM25 + semantic search across workspace markdown |
| **skill-creator-ultra** | Design and package new AI skills |

## Prerequisites

- [OpenClaw](https://openclaw.ai) installed and configured (`openclaw configure` done)
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

The installer will prompt you for:
- **GitHub PAT** — for cloning private repos and API calls
- **GitHub username** — for forking/cloning prev-cli
- **Anthropic API key** — injected into openclaw.json (optional if already configured)

> Credentials are applied directly to your local files and **never stored in this repo**.

## What the installer does

1. Copies workspace files to `~/.openclaw/workspace/`
2. Installs all 7 skills
3. Deep-merges `config/openclaw.patch.json` into `~/.openclaw/openclaw.json`
4. *(Optional)* Clones and builds your `prev-cli` fork
5. *(Optional)* Installs `chub` CLI for API docs
6. *(Optional)* Restarts the OpenClaw gateway

## After install

1. Edit `~/.openclaw/workspace/USER.md` — tell the agent who you are
2. Edit `~/.openclaw/workspace/SOUL.md` — customise the persona
3. Start a prev-cli docs server:
   ```bash
   cd ~/.openclaw/workspace/prev-cli
   bun dist/cli.js -c /path/to/your/docs -p 3001
   ```
4. Open `http://localhost:3001` — your docs site + board canvas is live

## Re-running

The installer is idempotent: existing workspace files are backed up (`.bak`), existing skills are skipped. Safe to run again after an update.

## Structure

```
sot-starter/
├── install.sh                    ← entry point
├── config/
│   └── openclaw.patch.json       ← settings merged into openclaw.json
├── workspace/
│   ├── SOUL.md / AGENTS.md / ...
│   └── skills/
│       ├── c3/
│       ├── prev-cli/
│       ├── sot-manager/
│       ├── project-adopt/
│       ├── get-api-docs/
│       ├── qmd/
│       └── skill-creator-ultra/
└── README.md
```

## License

MIT
