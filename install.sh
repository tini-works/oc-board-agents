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

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
OPENCLAW_HOME="$(dirname "$WORKSPACE")"
OPENCLAW_CONFIG="$OPENCLAW_HOME/openclaw.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  [[ "${ans,,}" == "y" ]]
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

# ─── Preflight ───────────────────────────────
print_header

step "Checking requirements..."
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v git     >/dev/null 2>&1 || fail "git is required"

HAVE_BUN=false; HAVE_NODE=false
command -v bun  >/dev/null 2>&1 && HAVE_BUN=true
command -v node >/dev/null 2>&1 && HAVE_NODE=true
$HAVE_BUN || $HAVE_NODE || fail "bun or node is required"

[[ -f "$OPENCLAW_CONFIG" ]] || fail "openclaw.json not found at $OPENCLAW_CONFIG — please run 'openclaw configure' first"
success "Requirements OK"

# ─── Credentials ─────────────────────────────
echo ""
step "Gathering credentials (stored only in your local files, never in this repo)"
echo ""

GITHUB_PAT=$(read_secret "  GitHub PAT (leave blank to skip): ")
GITHUB_USER=$(read_input "  GitHub username (leave blank to skip): ")
echo ""

# ─── Workspace files ──────────────────────────
step "Installing workspace files → $WORKSPACE"
mkdir -p "$WORKSPACE/memory"

for f in AGENTS.md SOUL.md USER.md IDENTITY.md MEMORY.md HEARTBEAT.md; do
  src="$SCRIPT_DIR/workspace/$f"
  dst="$WORKSPACE/$f"
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

[[ -n "$GITHUB_PAT" ]]  && _sed "s|{{GITHUB_PAT}}|$GITHUB_PAT|g"   || _sed "s|{{GITHUB_PAT}}||g"
[[ -n "$GITHUB_USER" ]] && _sed "s|{{GITHUB_USER}}|$GITHUB_USER|g" || _sed "s|{{GITHUB_USER}}||g"
# PREV_CLI_PATH placeholder filled later; clean it now as a fallback
_sed "s|{{PREV_CLI_PATH}}||g"
info "Installed TOOLS.md"
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

for agent in sot-scribe sot-editor; do
  src="$SCRIPT_DIR/workspace-${agent}"
  dst="$OPENCLAW_HOME/workspace-${agent}"
  if [[ ! -d "$src" ]]; then
    warn "workspace-${agent} not found in sot-starter — skipping"
    continue
  fi
  mkdir -p "$dst"
  for f in IDENTITY.md SOUL.md AGENTS.md; do
    if [[ -f "$src/$f" ]]; then
      if [[ -f "$dst/$f" ]]; then
        warn "${agent}/$f already exists — skipping"
      else
        cp "$src/$f" "$dst/$f"
        info "Installed workspace-${agent}/$f"
      fi
    fi
  done
done
success "Agent workspaces installed"

# ─── openclaw.json patch ──────────────────────
step "Patching openclaw.json..."

python3 - "$OPENCLAW_CONFIG" "$SCRIPT_DIR/config/openclaw.patch.json" "$OPENCLAW_HOME" <<'PYEOF'
import json, sys

config_path   = sys.argv[1]
patch_path    = sys.argv[2]
openclaw_home = sys.argv[3]

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

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
print("Patch applied")
PYEOF

success "openclaw.json patched"

# ─── c3x binary ───────────────────────────────
step "Installing c3x binary..."

C3_VERSION=$(cat "$WORKSPACE/skills/c3/bin/VERSION" 2>/dev/null || echo "6.6.0")
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
[[ "$ARCH" == "x86_64" ]]              && ARCH="amd64"
[[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]] && ARCH="arm64"

C3X_BIN="$WORKSPACE/skills/c3/bin/c3x-${C3_VERSION}-${OS}-${ARCH}"
C3X_LINK="$WORKSPACE/skills/c3/bin/c3x"

if [[ -f "$C3X_LINK" ]] || [[ -f "$C3X_BIN" ]]; then
  warn "c3x binary already exists — skipping download"
else
  C3X_URL="https://github.com/c3-ai/c3x/releases/download/v${C3_VERSION}/c3x-${C3_VERSION}-${OS}-${ARCH}"
  info "Downloading $C3X_URL"
  if curl -fsSL "$C3X_URL" -o "$C3X_BIN" 2>/dev/null; then
    chmod +x "$C3X_BIN"
    ln -sf "$C3X_BIN" "$C3X_LINK"
    success "c3x v${C3_VERSION} installed (${OS}-${ARCH})"
  else
    warn "Could not download c3x binary — install manually later"
    warn "URL: $C3X_URL"
  fi
fi

# ─── prev-cli ─────────────────────────────────
echo ""
if [[ -n "$GITHUB_USER" ]] && confirm "Clone and build prev-cli fork (${GITHUB_USER}/prev-cli)?"; then
  step "Setting up prev-cli..."

  PREV_CLI_PATH="$WORKSPACE/prev-cli"

  if [[ -d "$PREV_CLI_PATH" ]]; then
    warn "prev-cli already exists at $PREV_CLI_PATH — skipping clone"
  else
    CLONE_URL="https://github.com/${GITHUB_USER}/prev-cli.git"
    [[ -n "$GITHUB_PAT" ]] && CLONE_URL="https://${GITHUB_PAT}@github.com/${GITHUB_USER}/prev-cli.git"
    git clone "$CLONE_URL" "$PREV_CLI_PATH"
    info "Cloned to $PREV_CLI_PATH"
  fi

  cd "$PREV_CLI_PATH"
  if $HAVE_BUN; then bun install && bun run build
  else npm install && npm run build; fi

  # Fill PREV_CLI_PATH placeholder in TOOLS.md
  _sed "s|{{PREV_CLI_PATH}}|$PREV_CLI_PATH|g"
  success "prev-cli built at $PREV_CLI_PATH"
fi

# ─── chub ─────────────────────────────────────
echo ""
if confirm "Install chub CLI (API docs fetcher)?"; then
  step "Installing chub..."
  if $HAVE_BUN; then
    bun add -g @aisuite/chub 2>/dev/null || npm install -g @aisuite/chub
  else
    npm install -g @aisuite/chub
  fi
  success "chub installed"
fi

# ─── Memory index ─────────────────────────────
echo ""
if confirm "Seed memory search index now? (recommended, takes ~1 min)"; then
  step "Indexing memory..."
  openclaw memory index --force 2>/dev/null \
    && success "Memory index seeded" \
    || warn "Could not index memory — run 'openclaw memory index --force' manually later"
fi

# ─── Restart OpenClaw ─────────────────────────
echo ""
if confirm "Restart OpenClaw gateway to apply config?"; then
  step "Restarting OpenClaw..."
  openclaw gateway restart \
    && success "Gateway restarted" \
    || warn "Could not restart — run 'openclaw gateway restart' manually"
fi

# ─── Summary ──────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}══════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Installation complete! 🎉${RESET}"
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
echo -e "  ${YELLOW}Next steps:${RESET}"
echo -e "  1. Edit ${BOLD}$WORKSPACE/USER.md${RESET} — tell the agent about yourself"
echo -e "  2. Edit ${BOLD}$WORKSPACE/SOUL.md${RESET} — customise the persona"
echo -e "  3. Start a board: ${BOLD}bun dist/cli.js -c /path/to/sot-repo/docs -p 3001${RESET}"
echo -e "  4. Discuss → tag @sot-scribe to generate artifacts → annotate → @sot-editor to edit"
echo ""
