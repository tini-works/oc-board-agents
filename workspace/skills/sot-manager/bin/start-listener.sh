#!/usr/bin/env bash
# start-listener.sh — start the SOT approval webhook listener
# Usage: ./start-listener.sh [--sot-repo PATH] [--port PORT] [--derived-repo PATH]
#
# Reads SOT_REPO / DERIVED_REPO / LISTENER_PORT from env if flags not given.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUN="${BUN:-$HOME/.bun/bin/bun}"

exec "$BUN" "$SCRIPT_DIR/approval-listener.ts" "$@"
