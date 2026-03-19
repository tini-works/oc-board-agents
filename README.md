# sot-starter

One-command installer that configures [OpenClaw](https://github.com/openclaw/openclaw) for the **Source of Truth (SOT)** agentic development workflow.

## What it sets up

- **3 board agents** — board (facilitator), sot-scribe (artifact generator), sot-editor (artifact editor)
- **7 skills** — c3, sot-manager, project-adopt, prev-cli, get-api-docs, qmd, skill-creator-ultra
- **Workspace files** — SOUL.md, AGENTS.md, TOOLS.md, USER.md, MEMORY.md
- **prev-cli** — Board UI for collaborative architecture discussions
- **c3x binary** — Architecture validation tool
- **Model provider** — uses the model already configured by OpenClaw setup

## Prerequisites

### Docker mode (recommended)

1. [Docker](https://docs.docker.com/get-docker/) installed and running
2. OpenClaw Docker image built and gateway started:
   ```bash
   cd /path/to/openclaw
   ./docker-setup.sh
   ```
3. `python3` and `git` on the host

### Native mode

1. OpenClaw installed and configured (`openclaw configure`)
2. `python3`, `git`, and `bun` or `node` on the host

## Install

### Docker mode

```bash
git clone https://github.com/tini-works/oc-sot-starter.git
cd oc-sot-starter
./install.sh --docker --openclaw-repo /path/to/openclaw
```

### Native mode

```bash
git clone https://github.com/tini-works/oc-sot-starter.git
cd oc-sot-starter
./install.sh
```

## What the installer does

```
Step 1: Enter credentials
         GitHub PAT + username (for sot-manager PR workflow, optional)

Step 2: Install workspace files
         SOUL.md, AGENTS.md, TOOLS.md, etc. → ~/.openclaw/workspace/

Step 3: Install 7 skills
         → ~/.openclaw/workspace/skills/

Step 4: Install agent workspaces
         workspace-sot-scribe/, workspace-sot-editor/

Step 5: Patch openclaw.json
         Register agents, configure memory search
         (Docker) Fix gateway bind + controlUi allowedOrigins

Step 6: Download c3x binary
         Linux binary in Docker mode, native binary otherwise

Step 7: Clone + build prev-cli
         Default: https://github.com/tini-works/oc-board-cli.git
         Custom repo URL supported

Step 8: Optional
         Install chub CLI, seed memory index, restart gateway
```

## After install

1. **Edit your profile:**
   ```bash
   nano ~/.openclaw/workspace/USER.md
   ```

2. **Start the board:**

   Docker:
   ```bash
   cd /path/to/openclaw
   docker compose exec openclaw-gateway \
     node /home/node/.openclaw/workspace/prev-cli/dist/cli.js \
     -c /path/to/sot-repo/docs -p 3001
   ```

   Native:
   ```bash
   cd ~/.openclaw/workspace/prev-cli
   bun dist/cli.js -c /path/to/sot-repo/docs -p 3001
   ```

3. **Open** `http://localhost:3001` → Board tab

4. **Discuss → Generate → Review:**
   - Chat with the board agent (discussion facilitator)
   - Tag `@sot-scribe` to generate architecture artifacts
   - Annotate artifacts → sot-editor makes targeted edits
   - Use sot-manager to open a Change Request

## Agents

| Agent | Trigger | Role | Tools |
|-------|---------|------|-------|
| **board** | Always present | Discussion facilitator (read-only) | read, web_search, web_fetch, memory_search |
| **sot-scribe** | `@sot-scribe` in board chat | Generates SOT artifacts from discussions | read, write, exec, web_search, web_fetch, memory_search |
| **sot-editor** | Annotation → Request Update | Makes targeted edits to artifacts | read, write, exec, memory_search |

## Skills

| Skill | Purpose |
|-------|---------|
| **c3** | Architecture documentation (c3x CLI) |
| **sot-manager** | SOT lifecycle: draft → approve → merge → handoff |
| **project-adopt** | Reverse-engineer codebases into SOT |
| **prev-cli** | Documentation site + board canvas |
| **get-api-docs** | Fetch third-party API docs via chub |
| **qmd** | Semantic memory search (BM25 + vector) |
| **skill-creator-ultra** | AI skill design pipeline |

## Flags

| Flag | Description |
|------|-------------|
| `--docker` | Configure for Docker-based OpenClaw |
| `--openclaw-repo <path>` | Path to OpenClaw repo with docker-compose.yml |

## Re-running

The installer is idempotent — safe to re-run. Existing workspace files and skills are skipped. TOOLS.md is overwritten (backup created).

## Workspace structure

After install, the workspace at `~/.openclaw/workspace/` looks like this and can be pushed to a git repo:

```
~/.openclaw/workspace/              ← single git repo for all agents
├── SOUL.md                         ← main agent personality
├── AGENTS.md                       ← operating rules
├── USER.md                         ← your profile
├── TOOLS.md                        ← local config (no secrets)
├── IDENTITY.md
├── MEMORY.md                       ← curated long-term memory
├── HEARTBEAT.md
├── .gitignore                      ← ignores prev-cli/, secrets
├── memory/                         ← daily notes
├── skills/                         ← shared skills (all agents)
│   ├── c3/
│   ├── sot-manager/
│   ├── prev-cli/
│   ├── project-adopt/
│   ├── get-api-docs/
│   ├── qmd/
│   └── skill-creator-ultra/
├── agents/                         ← per-agent workspaces
│   ├── sot-scribe/
│   │   ├── SOUL.md
│   │   ├── AGENTS.md
│   │   └── IDENTITY.md
│   └── sot-editor/
│       ├── SOUL.md
│       ├── AGENTS.md
│       └── IDENTITY.md
└── prev-cli/                       ← board UI (gitignored, built per machine)
```

Credentials (GitHub PAT) are stored in `~/.openclaw/.env`, outside the workspace.

## Repo structure (this repo)

```
sot-starter/
├── install.sh                      ← entry point
├── config/
│   └── openclaw.patch.json         ← merged into ~/.openclaw/openclaw.json
├── workspace/
│   ├── SOUL.md / AGENTS.md / ...   ← main agent persona files
│   ├── TOOLS.md                    ← config template (no secrets)
│   ├── .gitignore                  ← workspace gitignore template
│   ├── skills/                     ← 7 skills
│   └── agents/                     ← agent workspace templates
│       ├── sot-scribe/
│       └── sot-editor/
└── README.md
```

## License

MIT
