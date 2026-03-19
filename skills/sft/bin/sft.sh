#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)        ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

BIN="$SCRIPT_DIR/sft-${OS}-${ARCH}"

if [ ! -f "$BIN" ]; then
  echo "Error: binary not found: $BIN" >&2
  echo "hint: reinstall the skill" >&2
  exit 1
fi

exec "$BIN" "$@"
