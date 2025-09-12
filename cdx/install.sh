#!/usr/bin/env bash
set -euo pipefail

# Minimal installer for tools/cdx as a standalone distribution.
# - Adds a source line to your shell rc file
# - Optionally installs repo prompts to ~/.codex/prompts

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CDX_ENTRY="$SELF_DIR/cdx.sh"

pick_shell_rc() {
  for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$f" ]] && { echo "$f"; return; }
  done
  # Default to bashrc if none exist
  echo "$HOME/.bashrc"
}

ensure_source_line() {
  local rc="$1"
  local line="source $CDX_ENTRY"
  if ! grep -Fq "$line" "$rc" 2>/dev/null; then
    echo "$line" >> "$rc"
    echo "Added to $rc: $line"
  else
    echo "Already present in $rc"
  fi
}

install_prompts() {
  local src_root="$SELF_DIR/../../tools/cdx/prompts"
  local dest_root="${CODEX_HOME:-$HOME/.codex}/prompts"
  if [[ -d "$src_root" ]]; then
    mkdir -p "$dest_root"
    find "$src_root" -maxdepth 1 -type f -name '*.md' -print0 | xargs -0 -I{} install -m 0644 {} "$dest_root/"
    echo "Installed prompts to $dest_root"
  else
    echo "No tools/cdx/prompts directory found; skipping prompts install."
  fi
}

main() {
  if [[ ! -f "$CDX_ENTRY" ]]; then
    echo "cdx.sh not found at $CDX_ENTRY" >&2
    exit 1
  fi
  local rc
  rc=$(pick_shell_rc)
  ensure_source_line "$rc"
  case "${1:-}" in
    --with-prompts) install_prompts ;;
    *) : ;;
  esac
  echo "Done. Open a new shell or run: source $rc"
}

main "$@"
