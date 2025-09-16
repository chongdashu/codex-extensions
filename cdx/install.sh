#!/usr/bin/env bash
set -euo pipefail

# Minimal installer for cdx as a standalone distribution.
# - Adds a source line to your shell rc file
# - Installs repo prompts to ~/.codex/prompts

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CDX_ENTRY="$SELF_DIR/cdx.sh"

# Try to find repo root by walking up until a marker is found (.git/ or AGENTS.md or README.md).
find_repo_root() {
  local dir; dir="$SELF_DIR"
  local max_up=6
  while [[ "$dir" != "/" && $max_up -gt 0 ]]; do
    if [[ -d "$dir/.git" || -f "$dir/AGENTS.md" || -f "$dir/README.md" ]]; then
      echo "$dir"; return
    fi
    dir=$(dirname "$dir"); max_up=$((max_up-1))
  done
  echo "$SELF_DIR/.."
}

pick_shell_rc() {
  for f in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$f" ]] && { echo "$f"; return; }
  done
  # Default to bashrc if none exist
  echo "$HOME/.bashrc"
}

ensure_source_line() {
  local rc="$1"
  local line="source $CDX_ENTRY"
  if [[ "$rc" == "$HOME/.zshrc" ]]; then
    local start_marker="# >>> Codex CLI (cdx) >>>"
    local end_marker="# <<< Codex CLI (cdx) <<<"
    if grep -Fq "$start_marker" "$rc" 2>/dev/null; then
      echo "Comment block already present in $rc"
      return
    fi
    if grep -Fq "$line" "$rc" 2>/dev/null; then
      local tmp
      tmp=$(mktemp)
      grep -Fv "$line" "$rc" > "$tmp" || true
      mv "$tmp" "$rc"
    fi
    {
      printf '\n%s\n' "$start_marker"
      printf 'if [[ -f "%s" ]]; then\n' "$CDX_ENTRY"
      printf '  source "%s"\n' "$CDX_ENTRY"
      printf 'fi\n'
      printf '%s\n' "$end_marker"
    } >> "$rc"
    echo "Added Codex CLI block to $rc"
    return
  fi
  if ! grep -Fq "$line" "$rc" 2>/dev/null; then
    echo "$line" >> "$rc"
    echo "Added to $rc: $line"
  else
    echo "Already present in $rc"
  fi
}

install_prompts() {
  local dest_root="${CODEX_HOME:-$HOME/.codex}/prompts"
  local rr
  rr=$(find_repo_root)
  # Probe likely source locations in priority order:
  # 1) explicit env override
  # 2) repo-level prompts at repo root (…/prompts)
  # 3) cdx-local prompts (…/cdx/prompts)
  # 4) legacy vendored layout (historical path)
  local candidates=(
    "${REPO_PROMPTS_DIR:-}"
    "$rr/prompts"
    "$SELF_DIR/../prompts"
    "$SELF_DIR/prompts"
    "$SELF_DIR/../../tools/cdx/prompts"
  )
  local src_root=""
  for d in "${candidates[@]}"; do
    if [[ -d "$d" ]]; then src_root="$d"; break; fi
  done
  if [[ -z "$src_root" ]]; then
    echo "No prompts directory found; looked in: ${candidates[*]}"
    echo "Skipping prompts install."
    return 0
  fi
  mkdir -p "$dest_root"
  # Copy only Markdown files
  find "$src_root" -maxdepth 1 -type f -name '*.md' -print0 | xargs -0 -I{} install -m 0644 {} "$dest_root/"
  echo "Installed prompts from $src_root to $dest_root"
}

main() {
  if [[ ! -f "$CDX_ENTRY" ]]; then
    echo "cdx.sh not found at $CDX_ENTRY" >&2
    exit 1
  fi
  local rc
  rc=$(pick_shell_rc)
  ensure_source_line "$rc"
  install_prompts
  echo "Done. Open a new shell or run: source $rc"
}

main "$@"
