#!/usr/bin/env bash
set -euo pipefail

# Manage Codex custom prompts for this repository.

script_dir() { local src; src=${BASH_SOURCE[0]}; cd "$(dirname "$src")" >/dev/null 2>&1 && pwd; }
# From plugins/ -> repo root: ../../.. (plugins -> cdx -> tools -> repo)
repo_root() { cd "$(script_dir)"/../../.. >/dev/null 2>&1 && pwd; }

codex_home=${CODEX_HOME:-"$HOME/.codex"}
dest_dir="$codex_home/prompts"
src_dir_default="$(repo_root)/tools/cdx/prompts"
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
  \cat <<EOF
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
