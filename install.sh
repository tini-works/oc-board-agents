#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  sot-starter installer
#  Sets up OpenClaw workspace, skills, board agents, and prev-cli
#  Requirements: OpenClaw already installed and configured, git, node/bun, python3
# ─────────────────────────────────────────────

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Utility functions ──────────────────────────
print_header() {
  echo ""
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════╗${RESET}"
  echo -e "${CYAN}${BOLD}║      sot-starter installer       ║${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════╝${RESET}"
  echo ""
}

step()    { echo -e "${GREEN}${BOLD}▶ $1${RESET}"; }
warn()    { echo -e "${YELLOW}⚠  $1${RESET}"; }
info()    { echo -e "   ${CYAN}$1${RESET}"; }
success() { echo -e "${GREEN}✓ $1${RESET}"; }
fail()    { echo -e "${RED}✗ $1${RESET}"; exit 1; }

confirm() {
  read -r -p "$(echo -e "${YELLOW}$1 [y/N]:${RESET} ")" ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

read_secret() {
  local prompt="$1"
  local result
  echo -en "${YELLOW}$prompt${RESET}" >&2
  read -rs result
  echo "" >&2
  echo "$result"
}

read_input() {
  local prompt="$1"
  local result
  echo -en "${YELLOW}$prompt${RESET}" >&2
  read -r result
  echo "$result"
}

# ─── Default paths ──────────────────────────────
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
OPENCLAW_HOME="$(dirname "$WORKSPACE")"
OPENCLAW_CONFIG="$OPENCLAW_HOME/openclaw.json"

# ─── Mode detection ─────────────────────────────
DOCKER_MODE=false
OPENCLAW_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker) DOCKER_MODE=true; shift ;;
    --openclaw-repo)
      [[ $# -ge 2 ]] || fail "--openclaw-repo requires a value"
      OPENCLAW_REPO="$2"; shift 2 ;;
    --openclaw-repo=*)
      OPENCLAW_REPO="${1#*=}"; shift ;;
    *) fail "Unknown flag: $1" ;;
  esac
done

if $DOCKER_MODE; then
  # Container paths (inside Docker)
  CONTAINER_OPENCLAW_HOME="/home/node/.openclaw"
  CONTAINER_WORKSPACE="/home/node/.openclaw/workspace"

  # Host paths (where files actually get written)
  OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
  WORKSPACE="${OPENCLAW_WORKSPACE_DIR:-$OPENCLAW_CONFIG_DIR/workspace}"
  OPENCLAW_HOME="$OPENCLAW_CONFIG_DIR"
  OPENCLAW_CONFIG="$OPENCLAW_HOME/openclaw.json"

  # Resolve OpenClaw repo for docker compose commands
  if [[ -z "$OPENCLAW_REPO" ]]; then
    OPENCLAW_REPO=$(read_input "  Path to OpenClaw repo (with docker-compose.yml): ")
  fi
  [[ -f "$OPENCLAW_REPO/docker-compose.yml" ]] || fail "docker-compose.yml not found at $OPENCLAW_REPO/"
fi

# Run a command via the OpenClaw Docker CLI container
docker_openclaw() {
  local compose_dir="$OPENCLAW_REPO"
  (cd "$compose_dir" && docker compose run --rm openclaw-cli "$@")
}

# ─── Preflight ───────────────────────────────
print_header

step "Checking requirements..."
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v git     >/dev/null 2>&1 || fail "git is required"

if $DOCKER_MODE; then
  command -v docker >/dev/null 2>&1 || fail "docker is required for --docker mode"
  # In Docker mode, bun/node are optional on the host (they run inside the container)
  HAVE_BUN=false; HAVE_NODE=false
  command -v bun  >/dev/null 2>&1 && HAVE_BUN=true
  command -v node >/dev/null 2>&1 && HAVE_NODE=true
else
  HAVE_BUN=false; HAVE_NODE=false
  command -v bun  >/dev/null 2>&1 && HAVE_BUN=true
  command -v node >/dev/null 2>&1 && HAVE_NODE=true
  $HAVE_BUN || $HAVE_NODE || fail "bun or node is required"
fi

[[ -f "$OPENCLAW_CONFIG" ]] || fail "openclaw.json not found at $OPENCLAW_CONFIG — is OpenClaw set up?"
success "Requirements OK"

# ─── Credentials ─────────────────────────────
# Model provider + API key are configured by docker-setup.sh / openclaw configure.
# We only need GitHub credentials here for the sot-manager PR workflow.
echo ""
step "Gathering credentials (stored only in your local files, never in this repo)"
echo ""

GITHUB_PAT=$(read_secret "  GitHub PAT — for sot-manager to push branches + create PRs (leave blank to skip): ")
GITHUB_USER=$(read_input "  GitHub username (leave blank to skip): ")
echo ""

# ─── Workspace files ──────────────────────────
step "Installing workspace files → $WORKSPACE"
mkdir -p "$WORKSPACE/memory"

for f in AGENTS.md SOUL.md USER.md IDENTITY.md MEMORY.md HEARTBEAT.md; do
  src="$SCRIPT_DIR/workspace/$f"
  dst="$WORKSPACE/$f"
  if [[ ! -f "$src" ]]; then
    warn "Source $f not found in repo — skipping"
    continue
  fi
  if [[ -f "$dst" ]]; then
    warn "$f already exists — skipping"
  else
    cp "$src" "$dst"
    info "Installed $f"
  fi
done

# TOOLS.md — install from template, substitute credentials, clean leftover placeholders
TOOLS_DST="$WORKSPACE/TOOLS.md"
if [[ -f "$TOOLS_DST" ]]; then
  cp "$TOOLS_DST" "$TOOLS_DST.bak"
  warn "TOOLS.md already exists — overwriting (backup at TOOLS.md.bak)"
fi
cp "$SCRIPT_DIR/workspace/TOOLS.md" "$TOOLS_DST"

_sed() { sed -i '' "$1" "$TOOLS_DST" 2>/dev/null || sed -i "$1" "$TOOLS_DST"; }

[[ -n "$GITHUB_USER" ]] && _sed "s|{{GITHUB_USER}}|$GITHUB_USER|g" || _sed "s|{{GITHUB_USER}}||g"
info "Installed TOOLS.md"

# Write GitHub PAT to .env (not TOOLS.md — keeps workspace safe to commit)
if [[ -n "$GITHUB_PAT" ]]; then
  ENV_FILE="$OPENCLAW_HOME/.env"
  if [[ -f "$ENV_FILE" ]] && grep -q "^GITHUB_TOKEN=" "$ENV_FILE" 2>/dev/null; then
    _sed_env() { sed -i '' "$1" "$ENV_FILE" 2>/dev/null || sed -i "$1" "$ENV_FILE"; }
    _sed_env "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=${GITHUB_PAT}|"
    info "Updated GITHUB_TOKEN in $ENV_FILE"
  else
    echo "GITHUB_TOKEN=${GITHUB_PAT}" >> "$ENV_FILE"
    info "Added GITHUB_TOKEN to $ENV_FILE"
  fi
  chmod 600 "$ENV_FILE"
  success "GitHub PAT saved to .env"
fi

# In Docker mode, override paths to use container-relative locations
if $DOCKER_MODE; then
  _sed "s|~/.openclaw/workspace|${CONTAINER_WORKSPACE}|g"
  _sed "s|\$HOME/.openclaw/workspace|${CONTAINER_WORKSPACE}|g"
fi
success "Workspace files done"

# ─── Skills ───────────────────────────────────
step "Installing skills → $WORKSPACE/skills/"
mkdir -p "$WORKSPACE/skills"

for skill_dir in "$SCRIPT_DIR/workspace/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  dst="$WORKSPACE/skills/$skill_name"
  if [[ -d "$dst" ]]; then
    warn "Skill '$skill_name' already exists — skipping"
  else
    cp -r "$skill_dir" "$dst"
    [[ -d "$dst/bin" ]] && chmod +x "$dst/bin"/* 2>/dev/null || true
    info "Installed skill: $skill_name"
  fi
done
success "Skills installed"

# ─── Agent workspaces ─────────────────────────
step "Installing board agent workspaces..."

for agent in board sot-scribe sot-editor sot-reader; do
  src="$SCRIPT_DIR/workspace/agents/${agent}"
  dst="$WORKSPACE/agents/${agent}"
  if [[ ! -d "$src" ]]; then
    warn "agents/${agent} not found in sot-starter — skipping"
    continue
  fi
  mkdir -p "$dst"
  for f in IDENTITY.md SOUL.md AGENTS.md; do
    if [[ -f "$src/$f" ]]; then
      if [[ -f "$dst/$f" ]]; then
        warn "agents/${agent}/$f already exists — skipping"
      else
        cp "$src/$f" "$dst/$f"
        info "Installed agents/${agent}/$f"
      fi
    fi
  done
done
success "Agent workspaces installed"

# ─── openclaw.json patch ──────────────────────
step "Patching openclaw.json..."

# In Docker mode, paths inside openclaw.json must be container-relative
if $DOCKER_MODE; then
  PATCH_OPENCLAW_HOME="$CONTAINER_OPENCLAW_HOME"
else
  PATCH_OPENCLAW_HOME="$OPENCLAW_HOME"
fi

DOCKER_MODE_FLAG="false"
$DOCKER_MODE && DOCKER_MODE_FLAG="true"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

python3 - "$OPENCLAW_CONFIG" "$SCRIPT_DIR/config/openclaw.patch.json" "$PATCH_OPENCLAW_HOME" "$DOCKER_MODE_FLAG" "$GATEWAY_PORT" <<'PYEOF'
import json, sys

config_path   = sys.argv[1]
patch_path    = sys.argv[2]
openclaw_home = sys.argv[3]
docker_mode   = sys.argv[4] == "true"
gateway_port  = sys.argv[5]

with open(config_path) as f:
    config = json.load(f)
with open(patch_path) as f:
    raw = f.read().replace("{{OPENCLAW_HOME}}", openclaw_home)
    patch = json.loads(raw)

patch.pop("_comment", None)

def merge_list_by_id(base_list, overlay_list):
    """Append new agents by id — never wipe existing ones."""
    existing_ids = {a["id"] for a in base_list if "id" in a}
    for agent in overlay_list:
        if agent.get("id") not in existing_ids:
            base_list.append(agent)
    return base_list

def deep_merge(base, overlay):
    for k, v in overlay.items():
        if k == "list" and isinstance(v, list):
            base[k] = merge_list_by_id(base.get(k, []), v)
        elif k in base and isinstance(base[k], dict) and isinstance(v, dict):
            deep_merge(base[k], v)
        else:
            base[k] = v

deep_merge(config, patch)

# In Docker mode, docker-compose starts the gateway with --bind lan.
# The config must match, and controlUi needs allowedOrigins for non-loopback binds.
if docker_mode:
    gw = config.setdefault("gateway", {})
    gw["bind"] = "lan"
    ui = gw.setdefault("controlUi", {})
    ui["enabled"] = True
    origins = ui.get("allowedOrigins", [])
    for origin in [f"http://localhost:{gateway_port}", f"http://127.0.0.1:{gateway_port}"]:
        if origin not in origins:
            origins.append(origin)
    ui["allowedOrigins"] = origins

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
print("Patch applied")
PYEOF

success "openclaw.json patched"

# ─── c3x binary ───────────────────────────────
step "Installing c3x binary..."

C3_VERSION=$(cat "$WORKSPACE/skills/c3/bin/VERSION" 2>/dev/null || echo "6.6.0")

if $DOCKER_MODE; then
  # Docker container runs Linux — download Linux binary regardless of host OS
  C3X_OS="linux"
  # Detect container architecture from the Docker image
  # Must use 'docker image inspect' (not 'docker inspect' which defaults to containers)
  C3X_ARCH=$(docker image inspect --format='{{.Architecture}}' "${OPENCLAW_IMAGE:-openclaw:local}" 2>/dev/null || echo "amd64")
  [[ "$C3X_ARCH" == "aarch64" ]] && C3X_ARCH="arm64"
  info "Docker mode: downloading c3x for ${C3X_OS}-${C3X_ARCH}"
else
  C3X_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  C3X_ARCH=$(uname -m)
fi
[[ "$C3X_ARCH" == "x86_64" ]] && C3X_ARCH="amd64"
[[ "$C3X_ARCH" == "arm64" || "$C3X_ARCH" == "aarch64" ]] && C3X_ARCH="arm64"

C3X_BIN="$WORKSPACE/skills/c3/bin/c3x-${C3_VERSION}-${C3X_OS}-${C3X_ARCH}"
C3X_LINK="$WORKSPACE/skills/c3/bin/c3x"

if [[ -f "$C3X_LINK" ]] || [[ -f "$C3X_BIN" ]]; then
  warn "c3x binary already exists — skipping download"
else
  C3X_URL="https://github.com/c3-ai/c3x/releases/download/v${C3_VERSION}/c3x-${C3_VERSION}-${C3X_OS}-${C3X_ARCH}"
  info "Downloading $C3X_URL"
  if curl -fsSL "$C3X_URL" -o "$C3X_BIN" 2>/dev/null; then
    chmod +x "$C3X_BIN"
    ln -sf "$C3X_BIN" "$C3X_LINK"
    success "c3x v${C3_VERSION} installed (${C3X_OS}-${C3X_ARCH})"
  else
    warn "Could not download c3x binary — install manually later"
    warn "URL: $C3X_URL"
  fi
fi

# ─── prev-cli ─────────────────────────────────
echo ""
DEFAULT_PREV_CLI_REPO="https://github.com/tini-works/oc-board-cli.git"
PREV_CLI_REPO=""

if confirm "Install prev-cli (board UI for SOT workflow)?"; then
  PREV_CLI_REPO=$(read_input "  prev-cli repo URL [${DEFAULT_PREV_CLI_REPO}]: ")
  PREV_CLI_REPO="${PREV_CLI_REPO:-$DEFAULT_PREV_CLI_REPO}"

  step "Setting up prev-cli..."
  PREV_CLI_PATH="$WORKSPACE/prev-cli"

  if [[ -d "$PREV_CLI_PATH" ]]; then
    warn "prev-cli already exists at $PREV_CLI_PATH — skipping clone"
  else
    CLONE_URL="$PREV_CLI_REPO"
    # If user provided a GitHub PAT earlier, inject it for private repos
    if [[ -n "$GITHUB_PAT" ]] && [[ "$CLONE_URL" == https://github.com/* ]]; then
      CLONE_URL="${CLONE_URL/https:\/\//https://${GITHUB_PAT}@}"
    fi
    git clone "$CLONE_URL" "$PREV_CLI_PATH"
    # Strip PAT from stored remote URL
    [[ -n "$GITHUB_PAT" ]] && git -C "$PREV_CLI_PATH" remote set-url origin "$PREV_CLI_REPO"
    info "Cloned to $PREV_CLI_PATH"
  fi

  if $DOCKER_MODE; then
    CONTAINER_PREV_CLI="$CONTAINER_WORKSPACE/prev-cli"
    info "Building prev-cli inside Docker container..."
    docker_openclaw bash -c "cd $CONTAINER_PREV_CLI && npm install && npm run build" \
      && success "prev-cli built (inside container)" \
      || warn "Could not build prev-cli inside container — build manually"
    _sed "s|{{PREV_CLI_PATH}}|$CONTAINER_PREV_CLI|g"
  else
    (
      cd "$PREV_CLI_PATH"
      if $HAVE_BUN; then bun install && bun run build
      else npm install && npm run build; fi
    )
    _sed "s|{{PREV_CLI_PATH}}|$PREV_CLI_PATH|g"
  fi

  success "prev-cli set up at $PREV_CLI_PATH"
fi

# Clean leftover PREV_CLI_PATH placeholder (if prev-cli was not installed)
_sed "s|{{PREV_CLI_PATH}}||g"

# ─── chub ─────────────────────────────────────
echo ""
if $DOCKER_MODE; then
  if confirm "Install chub CLI inside running Docker gateway?"; then
    step "Installing chub..."
    # Use 'exec' against running gateway — 'run --rm' would discard the install
    (cd "$OPENCLAW_REPO" && docker compose exec openclaw-gateway npm install -g @aisuite/chub) \
      && success "chub installed (inside gateway container)" \
      || warn "Could not install chub — ensure gateway is running, then: docker compose exec openclaw-gateway npm install -g @aisuite/chub"
  fi
else
  if confirm "Install chub CLI (API docs fetcher)?"; then
    step "Installing chub..."
    if $HAVE_BUN; then
      bun add -g @aisuite/chub 2>/dev/null || npm install -g @aisuite/chub
    else
      npm install -g @aisuite/chub
    fi
    success "chub installed"
  fi
fi

# ─── Memory index ─────────────────────────────
echo ""
if confirm "Seed memory search index now? (recommended, takes ~1 min)"; then
  step "Indexing memory..."
  if $DOCKER_MODE; then
    docker_openclaw memory index --force 2>/dev/null \
      && success "Memory index seeded" \
      || warn "Could not index memory — run 'docker compose run --rm openclaw-cli memory index --force' in your OpenClaw repo"
  else
    openclaw memory index --force 2>/dev/null \
      && success "Memory index seeded" \
      || warn "Could not index memory — run 'openclaw memory index --force' manually later"
  fi
fi

# ─── Restart OpenClaw ─────────────────────────
echo ""
if confirm "Restart OpenClaw gateway to apply config?"; then
  step "Restarting OpenClaw..."
  if $DOCKER_MODE; then
    (cd "$OPENCLAW_REPO" && docker compose restart openclaw-gateway) \
      && success "Gateway restarted" \
      || warn "Could not restart — run 'docker compose restart openclaw-gateway' in your OpenClaw repo"
  else
    openclaw gateway restart \
      && success "Gateway restarted" \
      || warn "Could not restart — run 'openclaw gateway restart' manually"
  fi
fi

# ─── Summary ──────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}══════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Installation complete!${RESET}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════${RESET}"
echo ""
echo -e "  Workspace : ${BOLD}$WORKSPACE${RESET}"
echo -e "  Skills    : c3, prev-cli, sot-manager, project-adopt,"
echo -e "              get-api-docs, qmd, skill-creator-ultra"
echo ""
echo -e "  Board agents:"
echo -e "    ${BOLD}board${RESET}       — discussion host (automatic on every board session)"
echo -e "    ${BOLD}sot-scribe${RESET}  — insight collector + SOT artifact generator (@sot-scribe)"
echo -e "    ${BOLD}sot-editor${RESET}  — targeted artifact editor (annotation thread updates)"
echo ""
if $DOCKER_MODE; then
  echo -e "  ${YELLOW}Docker mode:${RESET}"
  echo -e "    OpenClaw repo : ${BOLD}$OPENCLAW_REPO${RESET}"
  echo -e "    Container home: ${BOLD}$CONTAINER_OPENCLAW_HOME${RESET}"
  echo -e "    Gateway port  : ${BOLD}http://localhost:${OPENCLAW_GATEWAY_PORT:-18789}${RESET}"
  echo ""
  echo -e "  ${YELLOW}Next steps:${RESET}"
  echo -e "  1. Edit ${BOLD}$WORKSPACE/USER.md${RESET} — tell the agent about yourself"
  echo -e "  2. Edit ${BOLD}$WORKSPACE/SOUL.md${RESET} — customise the persona"
  echo -e "  3. Open OpenClaw Control UI: ${BOLD}http://localhost:${OPENCLAW_GATEWAY_PORT:-18789}${RESET}"
  echo -e "  4. Start a board via Docker:"
  echo -e "     ${BOLD}cd $OPENCLAW_REPO && docker compose run --rm openclaw-cli bash${RESET}"
  echo -e "     ${BOLD}bun dist/cli.js -c /path/to/sot-repo/docs -p 3001${RESET}"
  echo -e "  5. Discuss -> tag @sot-scribe to generate artifacts -> annotate -> @sot-editor to edit"
else
  echo -e "  ${YELLOW}Next steps:${RESET}"
  echo -e "  1. Edit ${BOLD}$WORKSPACE/USER.md${RESET} — tell the agent about yourself"
  echo -e "  2. Edit ${BOLD}$WORKSPACE/SOUL.md${RESET} — customise the persona"
  echo -e "  3. Start a board: ${BOLD}bun dist/cli.js -c /path/to/sot-repo/docs -p 3001${RESET}"
  echo -e "  4. Discuss -> tag @sot-scribe to generate artifacts -> annotate -> @sot-editor to edit"
fi
echo ""
