#!/usr/bin/env bash
set -euo pipefail

# Uninstaller for Codex Extensions (cdx)
# - Removes rc init blocks from bash/zsh (and fish snippet)
# - Removes /usr/local/bin/cdx symlink if it points to the installed home
# - Optionally removes the entire CODEX_HOME (with --remove-home)

DEFAULT_HOME="${CODEX_HOME:-$HOME/.codex}"

info() { printf 'info: %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*"; }

remove_rc_block() {
  local rc="$1"; shift || true
  [[ -f "$rc" && -w "$rc" ]] || { info "Skip $rc (missing or not writable)"; return 0; }
  # Remove between markers (inclusive)
  local tmp
  tmp=$(mktemp)
  if awk 'BEGIN{skip=0} /# >>> codex-cli initialize >>>/{skip=1} !skip{print} /# <<< codex-cli initialize <<</{skip=0}' "$rc" >"$tmp"; then
    if ! cmp -s "$rc" "$tmp"; then
      mv "$tmp" "$rc"
      ok "Removed init block from $rc"
    else
      rm -f "$tmp"
      info "No init block present in $rc"
    fi
  else
    rm -f "$tmp" || true
    warn "Failed to process $rc; leaving unchanged"
  fi
}

remove_fish_block() {
  local cfg="$1"; shift || true
  [[ -f "$cfg" && -w "$cfg" ]] || { info "Skip $cfg (missing or not writable)"; return 0; }
  local tmp
  tmp=$(mktemp)
  if awk 'BEGIN{skip=0} /# >>> codex-cli initialize >>>/{skip=1} !skip{print} /# <<< codex-cli initialize <<</{skip=0}' "$cfg" >"$tmp"; then
    if ! cmp -s "$cfg" "$tmp"; then
      mv "$tmp" "$cfg"
      ok "Removed fish init block from $cfg"
    else
      rm -f "$tmp"
      info "No fish init block present in $cfg"
    fi
  else
    rm -f "$tmp" || true
    warn "Failed to process $cfg; leaving unchanged"
  fi
}

remove_symlink() {
  local home_dir="$1"; shift || true
  local target="/usr/local/bin/cdx"
  if [[ -L "$target" ]]; then
    local dest
    dest=$(readlink "$target" || true)
    if [[ "$dest" == "$home_dir/bin/cdx" ]]; then
      if command -v sudo >/dev/null 2>&1; then
        sudo rm -f "$target" 2>/dev/null || rm -f "$target" || true
      else
        rm -f "$target" || true
      fi
      ok "Removed symlink $target"
    else
      info "$target points elsewhere; not removing"
    fi
  else
    info "No symlink at $target"
  fi
}

usage() {
  cat <<EOF
Usage: bash cdx/uninstall.sh [--home DIR] [--remove-home] [--remove-symlink] [--yes]

Options:
  --home DIR         Uninstall from custom CODEX_HOME (default: $DEFAULT_HOME)
  --remove-home      Remove the CODEX_HOME directory after cleanup
  --remove-symlink   Remove /usr/local/bin/cdx symlink if it points to CODEX_HOME
  --yes              Do not prompt for confirmation
EOF
}

main() {
  local home_dir="$DEFAULT_HOME" remove_home="" remove_link="" assume_yes=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --home) shift; home_dir="${1:-}"; [[ -n "$home_dir" ]] || { err "--home requires a value"; exit 2; } ;;
      --remove-home) remove_home=1 ;;
      --remove-symlink) remove_link=1 ;;
      --yes|-y) assume_yes=1 ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift || true
  done

  if [[ -z "$assume_yes" ]]; then
    printf 'This will remove Codex Extensions initialization from your shell configs.'
    printf '\nContinue? [y/N]: ';
    read -r ans || ans=""
    case "${ans,,}" in y|yes) : ;; *) err "Aborted"; exit 1;; esac
  fi

  remove_rc_block "$HOME/.bashrc"
  remove_rc_block "$HOME/.zshrc"

  # fish
  local xdg_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
  remove_fish_block "$xdg_cfg/fish/config.fish"

  [[ -n "$remove_link" ]] && remove_symlink "$home_dir"

  if [[ -n "$remove_home" ]]; then
    if [[ -d "$home_dir" ]]; then
      rm -rf "$home_dir"
      ok "Removed $home_dir"
    else
      info "Nothing to remove at $home_dir"
    fi
  else
    info "Left files in $home_dir intact (use --remove-home to delete)"
  fi

  ok "Uninstall complete"
}

main "$@"

