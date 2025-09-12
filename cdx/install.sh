#!/usr/bin/env bash
set -euo pipefail

# Global installer for Codex Extensions (cdx)
# - Installs to $HOME/.codex with bin/, extensions/, config/, lib/
# - Updates ~/.bashrc and/or ~/.zshrc with PATH and init sourcing
# - Optionally installs prompts and an /usr/local/bin symlink

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CDX_ENTRY="$SELF_DIR/cdx.sh"
DEFAULT_HOME="${CODEX_HOME:-$HOME/.codex}"

log() { printf '%s\n' "$*"; }
info() { printf 'info: %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*"; }

detect_shells() {
  # Echo a list of rc files to update (existing ones + primary from $SHELL)
  local out=()
  local primary=""
  if [[ -n "${SHELL:-}" ]]; then
    primary=$(basename -- "$SHELL")
  fi
  case "$primary" in
    zsh) out+=("$HOME/.zshrc") ;;
    bash) out+=("$HOME/.bashrc") ;;
  esac
  # Include any others that already exist
  for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$f" ]] && out+=("$f")
  done
  # Deduplicate
  awk '!(seen[$0]++)' < <(printf '%s\n' "${out[@]:-}")
}

ensure_dirs() {
  local home_dir="$1"
  install -d -m 0755 "$home_dir/bin" "$home_dir/extensions" "$home_dir/config" "$home_dir/lib"
  ok "Ensured directory structure under $home_dir"
}

write_wrapper() {
  local home_dir="$1"
  local wrapper="$home_dir/bin/cdx"
  cat > "$wrapper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export CODEX_HOME
# shellcheck source=/dev/null
if [[ -r "$CODEX_HOME/lib/codex-init.sh" ]]; then
  source "$CODEX_HOME/lib/codex-init.sh"
else
  echo "codex-init.sh not found in $CODEX_HOME/lib" >&2
  exit 1
fi
cdx "$@"
EOF
  chmod 0755 "$wrapper"
  ok "Installed wrapper: $wrapper"
}

install_files() {
  local home_dir="$1"
  # cdx.sh -> bin
  install -m 0755 "$CDX_ENTRY" "$home_dir/bin/cdx.sh"
  # codex-init.sh -> lib (from repo if present, else synthesize minimal)
  local init_src="$SELF_DIR/lib/codex-init.sh"
  if [[ -f "$init_src" ]]; then
    install -m 0644 "$init_src" "$home_dir/lib/codex-init.sh"
  else
    cat > "$home_dir/lib/codex-init.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
:
"${CODEX_HOME:=$HOME/.codex}"
export CODEX_HOME
# Ensure PATH contains bin
case ":${PATH}:" in
  *":$CODEX_HOME/bin:"*) : ;;
  *) PATH="$CODEX_HOME/bin:$PATH" ;;
esac
export PATH
# Default plugins dir to extensions
: "${CODEX_PLUGIN_DIR:=$CODEX_HOME/extensions}"
export CODEX_PLUGIN_DIR
# shellcheck source=/dev/null
if [[ -r "$CODEX_HOME/bin/cdx.sh" ]]; then
  source "$CODEX_HOME/bin/cdx.sh"
fi
EOS
    chmod 0644 "$home_dir/lib/codex-init.sh"
  fi
  ok "Installed core scripts"

  # plugins -> extensions
  local plugins_src="$SELF_DIR/plugins"
  if [[ -d "$plugins_src" ]]; then
    while IFS= read -r -d '' f; do
      install -m 0755 "$f" "$home_dir/extensions/"
    done < <(find "$plugins_src" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.sg' \) -print0)
    ok "Installed extensions from $plugins_src"
  else
    warn "No plugins directory at $plugins_src; continuing"
  fi
}

install_prompts() {
  local home_dir="$1"
  local src_root="$SELF_DIR/prompts"
  local dest_root="$home_dir/prompts"
  if [[ -d "$src_root" ]]; then
    install -d -m 0755 "$dest_root"
    while IFS= read -r -d '' f; do
      install -m 0644 "$f" "$dest_root/"
    done < <(find "$src_root" -maxdepth 1 -type f -name '*.md' -print0)
    ok "Installed prompts to $dest_root"
  else
    info "No prompts directory at $src_root; skipping"
  fi
}

append_rc_block() {
  local rc="$1" home_dir="$2"
  local block="# >>> codex-cli initialize >>>\nexport CODEX_HOME=\"$home_dir\"\nexport PATH=\"$home_dir/bin:$PATH\"\nsource \"$home_dir/lib/codex-init.sh\"\n# <<< codex-cli initialize <<<"
  mkdir -p "$(dirname "$rc")" 2>/dev/null || true
  if [[ ! -e "$rc" ]]; then
    if ! ( : > "$rc" ) 2>/dev/null; then
      warn "Cannot create $rc (permission denied); please add init block manually"
      return 0
    fi
  fi
  if [[ ! -w "$rc" ]]; then
    warn "$rc is not writable; please add init block manually"
    return 0
  fi
  if grep -Fq "$home_dir/lib/codex-init.sh" "$rc" 2>/dev/null; then
    info "Init block already present in $rc"
    return 0
  fi
  printf '\n%s\n' "$block" >>"$rc"
  ok "Updated $rc"
}

symlink_bin() {
  local home_dir="$1"
  local target="/usr/local/bin/cdx"
  if [[ -L "$target" || -f "$target" ]]; then
    info "Symlink exists at $target; leaving as-is"
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    if sudo ln -s "$home_dir/bin/cdx" "$target" 2>/dev/null; then
      ok "Created symlink: $target -> $home_dir/bin/cdx"
    else
      warn "Could not create symlink at $target (permission denied); skipped"
    fi
  else
    warn "sudo not available; skipping symlink $target"
  fi
}

verify_installation() {
  local home_dir="$1"; shift || true
  local shells=(bash)
  command -v zsh >/dev/null 2>&1 && shells+=(zsh)
  local any_ok=0
  for sh in "${shells[@]}"; do
    if ! command -v "$sh" >/dev/null 2>&1; then continue; fi
    if CODEX_HOME="$home_dir" "$sh" -lc "source '$home_dir/lib/codex-init.sh' >/dev/null 2>&1; cdx --version" >/dev/null 2>&1; then
      ok "Verified cdx in $sh"
      any_ok=1
    else
      warn "cdx verification failed in $sh (continuing)"
    fi
  done
  if [[ $any_ok -eq 0 ]]; then
    warn "Verification could not confirm 'cdx' (ensure you open a new shell or source your rc)"
  fi
}

append_fish_block() {
  local home_dir="$1"
  local cfg_root="${XDG_CONFIG_HOME:-$HOME/.config}"
  local cfg="$cfg_root/fish/config.fish"
  mkdir -p "$(dirname "$cfg")" 2>/dev/null || true
  if [[ ! -e "$cfg" ]]; then
    if ! ( : > "$cfg" ) 2>/dev/null; then
      warn "Cannot create $cfg (permission denied); please add fish init manually"
      return 0
    fi
  fi
  if [[ ! -w "$cfg" ]]; then
    warn "$cfg is not writable; please add fish init manually"
    return 0
  fi
  # Minimal PATH + env + cx helper; wrapper is executable, no bash source needed
  local block="# >>> codex-cli initialize >>>\nset -gx CODEX_HOME \"$home_dir\"\nset -gx PATH \"$home_dir/bin\" $PATH\nfunctions -q cx; or function cx\n  cdx $argv\nend\n# <<< codex-cli initialize <<<"
  if grep -Fq "$home_dir/bin" "$cfg" 2>/dev/null; then
    info "Fish init block already present in $cfg"
    return 0
  fi
  printf '\n%s\n' "$block" >>"$cfg"
  ok "Updated $cfg"
}

check_dependencies() {
  local -a req=(awk find install sed)
  local missing=()
  for b in "${req[@]}"; do
    command -v "$b" >/dev/null 2>&1 || missing+=("$b")
  done
  if (( ${#missing[@]} > 0 )); then
    warn "Missing core tools: ${missing[*]} (installer may fail)"
  fi
  # Recommended tools
  local -a rec=(rg fd jq)
  local rec_missing=()
  for b in "${rec[@]}"; do
    command -v "$b" >/dev/null 2>&1 || rec_missing+=("$b")
  done
  if (( ${#rec_missing[@]} > 0 )); then
    info "Recommended (optional) tools missing: ${rec_missing[*]}"
  fi
  # If user aliased cat->bat but 'bat' not installed, mention it
  if alias cat 2>/dev/null | grep -q "\bbat\b"; then
    if ! command -v bat >/dev/null 2>&1; then
      if command -v batcat >/dev/null 2>&1; then
        info "Detected 'cat' alias to 'bat' but only 'batcat' is installed (Debian/Ubuntu). Consider aliasing bat=batcat."
      else
        warn "Detected 'cat' alias to 'bat' but 'bat' is not installed. Install it (e.g., 'brew install bat' on macOS)."
      fi
    fi
  fi
  if ! command -v codex >/dev/null 2>&1; then
    info "'codex' binary not found; 'cdx --' pass-through may not work until installed"
  fi
}

usage() {
  \cat <<EOF
Usage: bash cdx/install.sh [--with-prompts] [--sudo] [--home DIR]

Options:
  --with-prompts   Install prompts from cdx/prompts to \$CODEX_HOME/prompts
  --sudo           Attempt to create /usr/local/bin/cdx symlink (may prompt)
  --home DIR       Install into custom home (default: $DEFAULT_HOME)
  --verbose        Print debug commands

Behavior:
  - Updates ~/.bashrc and/or ~/.zshrc idempotently with PATH and init sourcing
  - Installs core files to \$CODEX_HOME and verifies availability
EOF
}

main() {
  if [[ ! -f "$CDX_ENTRY" ]]; then
    err "cdx.sh not found at $CDX_ENTRY" >&2
    exit 1
  fi

  local do_prompts="" do_sudo_link="" home_dir="$DEFAULT_HOME" verbose=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-prompts) do_prompts=1 ;;
      --sudo|--with-symlink) do_sudo_link=1 ;;
      --home) shift; home_dir="${1:-}"; [[ -n "$home_dir" ]] || { err "--home requires a directory"; exit 2; } ;;
      --verbose) verbose=1 ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift || true
  done

  [[ -n "$verbose" ]] && set -x

  check_dependencies
  ensure_dirs "$home_dir"
  install_files "$home_dir"
  write_wrapper "$home_dir"
  [[ -n "$do_prompts" ]] && install_prompts "$home_dir"

  # Update rc files
  local rcs=()
  while IFS= read -r _rc; do
    [[ -n "$_rc" ]] && rcs+=("$_rc")
  done < <(detect_shells)
  if [[ ${#rcs[@]} -eq 0 ]]; then
    # Default to bashrc if nothing found
    rcs=("$HOME/.bashrc")
  fi
  for rc in "${rcs[@]}"; do
    append_rc_block "$rc" "$home_dir"
  done

  # Fish shell (best-effort)
  if command -v fish >/dev/null 2>&1; then
    append_fish_block "$home_dir"
  fi

  [[ -n "$do_sudo_link" ]] && symlink_bin "$home_dir"

  verify_installation "$home_dir"
  log "---"
  ok "Installation complete"
  log "Open a new shell or run: source \"${rcs[0]}\""
}

main "$@"
