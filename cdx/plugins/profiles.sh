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
  cat <<'EOF'
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

profiles_raw=""
current=""
while IFS= read -r raw_line; do
  local_line=${raw_line%$'\r'}
  local_line=${local_line%%#*}
  # trim leading whitespace
  local_line="${local_line#${local_line%%[![:space:]]*}}"
  # trim trailing whitespace
  local_line="${local_line%${local_line##*[![:space:]]}}"
  [[ -z "$local_line" ]] && continue

  if [[ ${local_line:0:1} == "[" ]]; then
    case "$local_line" in
      \[profiles.*\])
        section=${local_line#\[profiles.}
        section=${section%]}
        name=$section
        if [[ $section == \"* && $section == *\" ]]; then
          name=${section#\"}
          name=${name%\"}
        elif [[ $section == \'* && $section == *\' ]]; then
          name=${section#\'}
          name=${name%\'}
        else
          name=${section%%.*}
        fi
        [[ -n "$name" ]] && profiles_raw+="$name"$'\n'
        ;;
    esac
    continue
  fi

  if [[ -z "$current" && $local_line == profile* ]]; then
    IFS='=' read -r key value <<<"$local_line"
    key="${key%${key##*[![:space:]]}}"
    key="${key#${key%%[![:space:]]*}}"
    if [[ $key == profile ]]; then
      value="${value#${value%%[![:space:]]*}}"
      value="${value%${value##*[![:space:]]}}"
      if [[ $value == \"* && $value == *\" ]]; then
        current=${value#\"}
        current=${current%\"}
      elif [[ $value == \'* && $value == *\' ]]; then
        current=${value#\'}
        current=${current%\'}
      else
        current=$value
      fi
    fi
  fi
done < "$cfg"

if [[ -n "$profiles_raw" ]]; then
  profiles=$(printf '%s' "$profiles_raw" | sed '/^$/d' | sort -u)
else
  profiles=""
fi

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
