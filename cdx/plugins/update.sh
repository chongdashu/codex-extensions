#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  \cat <<'EOF'
Update Codex CLI to the latest (or a specified tag/version).

Usage:
  cdx update [--sudo] [--tag <dist-tag>] [--version <x.y.z>] [--force] [--npm-force] [--dry-run]
  cdx update --check-only [--tag <dist-tag>] [--quiet]
  cdx update -h|--help
EOF
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found" >&2; exit 127; }; }

get_current_version() { if command -v codex >/dev/null 2>&1; then codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown"; else echo "none"; fi; }
get_latest_version() { local tag="${1:-latest}"; npm view "@openai/codex@${tag}" version 2>/dev/null || echo "unknown"; }

version_lt() {
  local v1="$1" v2="$2"; [[ "$v1" == "none" || "$v1" == "unknown" ]] && return 0; [[ "$v2" == "unknown" ]] && return 1; [[ "$v1" == "$v2" ]] && return 1;
  local IFS='.' i; local v1_parts=($v1) v2_parts=($v2)
  for ((i=0;i<${#v1_parts[@]}||i<${#v2_parts[@]};i++)); do local a="${v1_parts[i]:-0}" b="${v2_parts[i]:-0}"; (( a<b )) && return 0; (( a>b )) && return 1; done; return 1
}

main() {
  local use_sudo=0 dry_run=0 force=0 npm_force=0 tag="" version="" check_only=0 quiet=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sudo) use_sudo=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      --force) force=1; shift ;;
      --npm-force) npm_force=1; shift ;;
      --check-only) check_only=1; shift ;;
      --quiet) quiet=1; shift ;;
      --tag) tag=${2:-}; shift 2 ;;
      --version) version=${2:-}; shift 2 ;;
      -h|--help) print_usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; print_usage; exit 2 ;;
    esac
  done

  need npm

  local current_version; current_version=$(get_current_version)
  (( ! check_only )) && { [[ "$current_version" == "none" ]] && { echo "Codex not currently installed. Installing fresh..."; force=1; } || echo "Current version: $current_version"; }

  local target_version target_spec="@openai/codex@latest"
  if [[ -n "$version" ]]; then target_version="$version"; target_spec="@openai/codex@${version}";
  elif [[ -n "$tag" ]]; then target_version=$(get_latest_version "$tag"); target_spec="@openai/codex@${tag}";
  else target_version=$(get_latest_version "latest"); fi

  (( ! quiet || ! check_only )) && echo "Latest version: $target_version"

  if (( check_only )); then
    if [[ "$current_version" == "none" ]]; then (( quiet )) || echo "Codex not installed. Run: cdx update"; exit 10; fi
    if version_lt "$current_version" "$target_version"; then echo "Update available: $current_version → $target_version. Run: cdx update"; exit 10; else (( quiet )) || echo "✓ Codex is up to date ($current_version)."; exit 0; fi
  fi

  if (( ! force )) && [[ -z "$version" ]]; then
    if ! version_lt "$current_version" "$target_version"; then echo "✓ Already up to date!"; exit 0; fi
    echo; echo "Update available: $current_version → $target_version"; read -p "Proceed with update? [Y/n] " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]?$ ]] || { echo "Update cancelled."; exit 0; }
  fi

  # Preflight: check writeability of target bin
  local npm_prefix npm_bin codex_bin
  npm_prefix=$(npm prefix -g 2>/dev/null || echo "")
  npm_bin=$(npm bin -g 2>/dev/null || echo "")
  [[ -z "$npm_bin" && -n "$npm_prefix" ]] && npm_bin="$npm_prefix/bin"
  codex_bin="$npm_bin/codex"
  if [[ -n "$codex_bin" && -e "$codex_bin" && ! -w "$codex_bin" && $use_sudo -eq 0 ]]; then
    echo "error: $codex_bin exists and is not writable. Re-run with --sudo, or remove/rename the file." >&2
    echo "hint: ls -l '$codex_bin'  # to inspect the existing file" >&2
    exit 13
  fi

  local cmd=(npm install -g "$target_spec")
  (( npm_force )) && cmd+=(--force)
  (( use_sudo )) && cmd=(sudo "${cmd[@]}")
  echo "Running: ${cmd[*]}"
  if (( dry_run )); then
    echo "(dry-run) Skipping execution."
  else
    if ! output=$("${cmd[@]}" 2>&1); then
      echo "$output" >&2
      if echo "$output" | grep -qi 'EEXIST'; then
        echo "error: npm reported EEXIST (file exists) for the 'codex' binary." >&2
        echo "fix: remove the existing file (e.g., 'sudo rm -f \"$codex_bin\"') or rerun with '--npm-force' to let npm overwrite." >&2
        echo "note: you may also need '--sudo' if the prefix is in a protected directory." >&2
      fi
      exit 1
    fi
  fi

  if command -v codex >/dev/null 2>&1; then
    local new_version; new_version=$(get_current_version)
    if [[ "$new_version" != "$current_version" ]]; then echo "✓ Successfully updated: $current_version → $new_version"; else echo "✓ Codex version: $new_version"; fi
  else
    echo "Note: 'codex' still not on PATH after install. Check your npm global prefix."; echo "npm prefix -g => $(npm prefix -g 2>/dev/null || echo unknown)"
  fi
}

main "$@"
