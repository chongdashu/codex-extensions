#!/usr/bin/env bash
set -euo pipefail

# Manage Codex custom prompts for this repository.

script_dir() { local src; src=${BASH_SOURCE[0]}; cd "$(dirname "$src")" >/dev/null 2>&1 && pwd; }

# Try to find repo root by walking up until a marker is found (.git/ or AGENTS.md or README.md).
repo_root() {
  local dir; dir=$(script_dir)
  local max_up=6
  while [[ "$dir" != "/" && $max_up -gt 0 ]]; do
    if [[ -d "$dir/.git" || -f "$dir/AGENTS.md" || -f "$dir/README.md" ]]; then
      echo "$dir"; return
    fi
    dir=$(dirname "$dir"); max_up=$((max_up-1))
  done
  # Fallbacks: two and three levels up from plugins/
  if cd "$(script_dir)"/../.. >/dev/null 2>&1; then pwd; return; fi
  cd "$(script_dir)"/../../.. >/dev/null 2>&1 && pwd
}

codex_home=${CODEX_HOME:-"$HOME/.codex"}
dest_dir="$codex_home/prompts"

# Resolve default source directory by probing common layouts in order of preference.
resolve_src_dir() {
  local rr; rr=$(repo_root)
  local candidates=(
    "${REPO_PROMPTS_DIR:-}"           # explicit override
    "$rr/prompts"                      # repo-level prompts
    "$(script_dir)/../prompts"         # cdx/prompts
    "$rr/tools/cdx/prompts"            # legacy vendored layout
  )
  local d
  for d in "${candidates[@]}"; do
    [[ -n "$d" && -d "$d" ]] && { echo "$d"; return; }
  done
  # If nothing found, still return the first non-empty candidate for messaging
  for d in "${candidates[@]}"; do
    if [[ -n "$d" ]]; then echo "$d"; return; fi
  done
  echo "$rr/prompts"
}

src_dir_default="$(resolve_src_dir)"
src_dir=${REPO_PROMPTS_DIR:-"$src_dir_default"}

ensure_dirs() { mkdir -p "$dest_dir"; }
die() { echo "prompts: $*" >&2; exit 1; }

list_repo() { [[ -d "$src_dir" ]] || return 0; for f in "$src_dir"/*.md; do [[ -e "$f" ]] || continue; basename "$f" .md; done | sort -u; }
list_installed() { [[ -d "$dest_dir" ]] || return 0; for f in "$dest_dir"/*.md; do [[ -e "$f" ]] || continue; basename "$f" .md; done | sort -u; }

copy_one() {
  # Split assignments so $name is set before expansion under `set -u`.
  local name src_file dest_file
  name=${1:?missing prompt name}
  src_file="$src_dir/$name.md"
  dest_file="$dest_dir/$name.md"
  [[ -f "$src_file" ]] || die "missing prompt: $src_file"
  install -m 0644 "$src_file" "$dest_file"
  echo "Installed /$name -> $dest_file"
}

do_install() {
  ensure_dirs
  if [[ $# > 0 ]]; then
    # Normalize any provided names by stripping trailing .md
    local arg name
    for arg in "$@"; do
      name=${arg%.md}
      copy_one "$name"
    done
  else
    local any=false
    for f in "$src_dir"/*.md; do [[ -e "$f" ]] || continue; any=true; copy_one "$(basename "$f" .md)"; done
    [[ "$any" == false ]] && echo "No repo prompts to install from $src_dir"
  fi
  echo "Done. Restart Codex or start a new session to reload prompts."
}

usage() {
  cat <<EOF
cdx prompts - manage Codex custom prompts (slash menu)

Commands:
  install [names]   Install prompts from repo to $dest_dir
  list              Show repo and installed prompts
  path              Print source and destination directories
  help              Show this help

Defaults:
  CODEX_HOME=$codex_home
  REPO_PROMPTS_DIR=${REPO_PROMPTS_DIR:-}
  SRC_DIR_RESOLVED=$src_dir
EOF
}

do_list() {
  local repo_names installed_names
  repo_names=$(list_repo)
  installed_names=$(list_installed)
  echo "Repo prompts in $src_dir:"; [[ -z "$repo_names" ]] && echo "  (none)" || printf '%s\n' "$repo_names" | sed 's/^/  - /'
  echo; echo "Installed prompts in $dest_dir:"; [[ -z "$installed_names" ]] && echo "  (none)" || printf '%s\n' "$installed_names" | sed 's/^/  - /'
  if [[ -n "$repo_names" ]]; then echo; echo "To install all repo prompts: cdx prompts install"; fi
}

case "${1:-list}" in
  help|-h|--help) usage ;;
  list) do_list ;;
  path) echo "src:  $src_dir"; echo "dest: $dest_dir" ;;
  install) shift || true; do_install "$@" ;;
  *) echo "Unknown subcommand: $1" >&2; usage; exit 2 ;;
esac
