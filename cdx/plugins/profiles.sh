#!/usr/bin/env bash
set -euo pipefail

# codex-profiles.sh: list profiles from Codex config (pretty by default)
# Usage:
#   cdx profiles            # pretty list with header, count, path
#   cdx profiles --quiet    # names only (one per line)
#   cdx profiles --help     # show help
#
# Respects:
#   $CODEX_HOME/config.toml (default: ~/.codex/config.toml)

show_help() {
  \cat <<'EOF'
List Codex profiles defined in config.toml.

Usage:
  cdx profiles [--quiet]

Looks for $CODEX_HOME/config.toml when $CODEX_HOME is set,
otherwise uses ~/.codex/config.toml.
EOF
}

QUIET=0
case "${1-}" in
  -h|--help|help)
    show_help; exit 0;;
  -q|--quiet)
    QUIET=1; shift || true;;
esac

home_dir=${CODEX_HOME:-"$HOME/.codex"}
cfg="$home_dir/config.toml"

if [[ ! -f "$cfg" ]]; then
  printf 'cdx: error: config not found at %s\n' "$cfg" >&2
  exit 1
fi

# Extract [profiles.<name>] headers (quoted or bare); ignore subtables and trailing comments
profiles=$(awk '
match($0,/^[[:space:]]*\[profiles\.(.*)\][[:space:]]*(#.*)?$/,m){
  s=m[1]
  if (s ~ /^"/){sub(/^"/,"",s); sub(/".*/,"",s)} else {sub(/\..*/,"",s)}
  print s
}' "$cfg" | sort -u)

# Determine active profile from top-level `profile = "..."` (single or double quotes)
current=$(awk '
match($0,/^[[:space:]]*profile[[:space:]]*=[[:space:]]*"([^"]+)"/,m){print m[1]; exit}
match($0,/^[[:space:]]*profile[[:space:]]*=\s*'\''([^'\'']+)'\''/,m){print m[1]; exit}
' "$cfg" 2>/dev/null || true)

if [[ $QUIET -eq 1 ]]; then
  if [[ -n "$profiles" ]]; then printf '%s\n' "$profiles"; fi
  exit 0
fi

count=0
if [[ -n "$profiles" ]]; then count=$(printf '%s\n' "$profiles" | wc -l | tr -d ' '); fi
printf 'Profiles (%s) from %s:\n' "$count" "$cfg"
if [[ -z "$profiles" ]]; then
  printf '  (no [profiles.*] entries found)\n'
else
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ -n "$current" && "$name" == "$current" ]]; then
      printf '  - %s  (active)\n' "$name"
    else
      printf '  - %s\n' "$name"
    fi
  done <<<"$profiles"
fi
printf 'Tip: use `codex --profile NAME` or `cdx -- --profile NAME`.\n'
