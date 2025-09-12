#!/usr/bin/env bash
#
# Usage: tools/cdx/scripts/setup-fast-tools.sh [--install-deps] [--dry-run] [--non-interactive]
#
# Purpose:
# - Append the repo's fast-tools prompt to AGENTS.md (idempotent via watermark).
# - Optionally install recommended CLI tools: ripgrep (rg), fd/fdfind, jq.
#
# Examples:
#   ./tools/cdx/scripts/setup-fast-tools.sh                 # append prompt only
#   ./tools/cdx/scripts/setup-fast-tools.sh --install-deps  # append + install deps
#   ./tools/cdx/scripts/setup-fast-tools.sh --install-deps --dry-run
#
set -euo pipefail

DO_INSTALL=0
DRY_RUN=0
NON_INTERACTIVE=0

log() { printf "[setup-fast-tools] %s\n" "$*"; }
err() { printf "[setup-fast-tools][error] %s\n" "$*" >&2; }

run() {
  printf "+ %s\n" "$*"
  if [ "$DRY_RUN" = 0 ]; then
    # shellcheck disable=SC2086
    $*
  fi
}

is_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }
have() { command -v "$1" >/dev/null 2>&1; }
have_sudo_nopass() { have sudo && sudo -n true 2>/dev/null; }
run_root() {
  if is_root; then
    run "$@"
  elif have_sudo_nopass; then
    run sudo -n "$@"
  else
    return 1
  fi
}

print_help() {
  sed -n '2,25p' "$0"
}

# Parse args (simple long options)
while [ $# -gt 0 ]; do
  case "$1" in
    --install-deps) DO_INSTALL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    -h|--help) print_help; exit 0 ;;
    *) err "Unknown option: $1"; print_help; exit 2 ;;
  esac
  shift
done

# Find repo root (or stay in CWD if not a git repo)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
AGENTS="$REPO_ROOT/AGENTS.md"
PROMPT_SRC="$REPO_ROOT/tools/cdx/agents/fast-tools.md"

if [ ! -f "$AGENTS" ]; then
  err "AGENTS.md not found under $REPO_ROOT"
  exit 1
fi
if [ ! -f "$PROMPT_SRC" ]; then
  err "Prompt file missing: $PROMPT_SRC"
  exit 1
fi

# Avoid duplicates using rg if available, otherwise grep
if have rg; then
  if rg -q "FAST-TOOLS PROMPT v1" "$AGENTS"; then
    log "FAST-TOOLS prompt already present — skipping append."
  else
    run printf "\n\n" >> "$AGENTS"
    run cat "$PROMPT_SRC" >> "$AGENTS"
    log "Appended fast-tools prompt to AGENTS.md"
  fi
else
  if grep -q "FAST-TOOLS PROMPT v1" "$AGENTS"; then
    log "FAST-TOOLS prompt already present — skipping append."
  else
    run printf "\n\n" >> "$AGENTS"
    run cat "$PROMPT_SRC" >> "$AGENTS"
    log "Appended fast-tools prompt to AGENTS.md"
  fi
fi

if [ "$DO_INSTALL" -eq 0 ]; then
  log "Dependencies not requested. Done."
  log "To install rg/fd/jq later: $0 --install-deps"
  exit 0
fi

log "Installing dependencies: ripgrep (rg), fd/fdfind, jq"

# Decide install method
install_brew() {
  run brew install ripgrep fd jq
}

install_apt() {
  # Debian/Ubuntu
  if [ "$NON_INTERACTIVE" -eq 1 ] && ! is_root && ! have_sudo_nopass; then
    err "Non-interactive and no passwordless sudo; printing commands instead."
    printf "\n# Run these as an admin:\n"
    printf "sudo apt-get update\n"
    printf "sudo apt-get install -y ripgrep fd-find jq\n"
    printf "# Optionally in your shell: alias fd=fdfind\n\n"
    return 0
  fi
  run_root apt-get update || { err "apt-get update failed"; exit 1; }
  run_root apt-get install -y ripgrep fd-find jq
}

install_dnf() {
  # Fedora/RHEL
  if [ "$NON_INTERACTIVE" -eq 1 ] && ! is_root && ! have_sudo_nopass; then
    err "Non-interactive and no passwordless sudo; printing commands instead."
    printf "\n# Run these as an admin:\n"
    printf "sudo dnf install -y ripgrep fd jq || sudo dnf install -y ripgrep fd-find jq\n\n"
    return 0
  fi
  run_root dnf install -y ripgrep fd jq || run_root dnf install -y ripgrep fd-find jq
}

install_pacman() {
  # Arch/Manjaro
  if [ "$NON_INTERACTIVE" -eq 1 ] && ! is_root && ! have_sudo_nopass; then
    err "Non-interactive and no passwordless sudo; printing commands instead."
    printf "\n# Run these as an admin:\n"
    printf "sudo pacman -S --needed --noconfirm ripgrep fd jq\n\n"
    return 0
  fi
  run_root pacman -S --needed --noconfirm ripgrep fd jq
}

install_zypper() {
  # openSUSE
  if [ "$NON_INTERACTIVE" -eq 1 ] && ! is_root && ! have_sudo_nopass; then
    err "Non-interactive and no passwordless sudo; printing commands instead."
    printf "\n# Run these as an admin:\n"
    printf "sudo zypper -n refresh && sudo zypper -n install ripgrep fd jq\n\n"
    return 0
  fi
  run_root zypper -n refresh || true
  run_root zypper -n install ripgrep fd jq
}

install_choco() {
  run choco install -y ripgrep fd jq
}

install_winget() {
  # IDs may vary by catalog; best-effort
  run winget install -e --id BurntSushi.ripgrep || true
  run winget install -e --id sharkdp.fd || true
  run winget install -e --id jqlang.jq || run winget install -e --id stedolan.jq || true
}

if have brew; then
  install_brew
elif have apt-get; then
  install_apt
elif have dnf; then
  install_dnf
elif have pacman; then
  install_pacman
elif have zypper; then
  install_zypper
elif have choco; then
  install_choco
elif have winget; then
  install_winget
else
  err "No supported package manager found. Install manually: ripgrep, fd/fdfind, jq."
  exit 1
fi

log "Dependency setup complete. If on Debian/Ubuntu, consider: alias fd=fdfind"
