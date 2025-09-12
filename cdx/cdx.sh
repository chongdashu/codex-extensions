#!/usr/bin/env bash

# cdx: Codex base command with subcommand routing
# Source this file from your ~/.bashrc (or ~/.zshrc via bash-compat) to get:
#   - `cdx resume` -> runs codex-resume.sh
#   - `cdx update` -> runs codex-update.sh (updates Codex CLI)
#   - `cdx` passthrough to `codex` with your preferred defaults
#   - `cdx raw` to call codex with no defaults

############################################################
# Resolve plugin directory (this file's folder by default) #
############################################################
_cdx__detect_plugin_dir() {
  # Resolve to the plugins folder next to this file by default
  local base=""
  if [[ -n "${BASH_SOURCE[0]}" ]]; then
    base=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  elif [[ -n "$ZSH_VERSION" ]]; then
    local src
    src=$(eval 'print -r -- ${(%):-%N}' 2>/dev/null) || true
    [[ -n "$src" ]] && base=$(cd "$(dirname "$src")" 2>/dev/null && pwd || true)
  fi
  if [[ -z "$base" ]]; then
    base="$HOME/projects/codex-mastery/tools/cdx"
  fi
  printf '%s' "$base/plugins"
}

#########################################
# Configuration (overridable via env)   #
#########################################
: "${CODEX_BIN:=codex}"
: "${CDX_VERSION:=0.1.0}"
: "${CDX_BUILD_DATE:=2025-09-11}"
: "${CODEX_PLUGIN_DIR:=$(_cdx__detect_plugin_dir)}"
: "${CDX_CHECK_UPDATES:=}"

# Opinionated defaults for pass-through invocations of `codex`.
_CDX_DEFAULT_FLAGS=(
  -m gpt-5
  -c 'model_reasoning_effort="high"'
  -c 'model_reasoning_summary="auto"'
  --search
  --dangerously-bypass-approvals-and-sandbox
)

#########################################
# Helpers                               #
#########################################
_cdx_list_plugins() {
  local plugin_dir="${CODEX_PLUGIN_DIR}"
  [[ -d "$plugin_dir" ]] || return 0
  rg --files "$plugin_dir" 2>/dev/null | sed -nE 's#^.*/([^/]+)\.(sh|sg)$#\1#p' | sort -u
}

_cdx_plugins_cmd() {
  local plugin_dir="${CODEX_PLUGIN_DIR}"
  local list
  list=$(_cdx_list_plugins)
  if [[ -z "$list" ]]; then
    printf 'cdx %s (%s)\n' "$CDX_VERSION" "$CDX_BUILD_DATE"
    printf 'Plugins (0) in %s\n' "$plugin_dir"
    printf '  (no plugin scripts named codex-*.sh found)\n'
    printf 'Tip: place plugins in %s as codex-<name>.sh\n' "$plugin_dir"
    return 0
  fi
  # Count lines
  local count
  count=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
  printf 'cdx %s (%s)\n' "$CDX_VERSION" "$CDX_BUILD_DATE"
  printf 'Plugins (%s) in %s:\n' "$count" "$plugin_dir"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local path="$plugin_dir/codex-$name.sh"
    printf '  - %s  (%s)\n' "$name" "$path"
  done <<<"$list"
  printf 'Tip: run `cdx <plugin> --help` for plugin usage.\n'
}

_cdx_parse_bool() {
  # returns 0 (true) or 1 (false); empty -> 1
  case "${1,,}" in
    1|true|yes|on) return 0;;
    0|false|no|off|"") return 1;;
    *) return 1;;
  esac
}

_cdx_config_check_updates() {
  local home_dir cfg val=""
  home_dir=${CODEX_HOME:-"$HOME/.codex"}
  cfg="$home_dir/config.toml"
  [[ -f "$cfg" ]] || return 1
  # Extract value after '=', strip comments/quotes/spaces, lowercase
  val=$(sed -nE 's/^[[:space:]]*cdx_check_updates[[:space:]]*=[[:space:]]*([^#]+).*$/\1/p' "$cfg" | head -1 | tr -d '"' | tr -d "'" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  if _cdx_parse_bool "$val"; then return 0; else return 1; fi
}

_cdx_should_check_updates() {
  # Env overrides config; default off
  if [[ -n "$CDX_CHECK_UPDATES" ]]; then
    _cdx_parse_bool "$CDX_CHECK_UPDATES" && return 0 || return 1
  fi
  _cdx_config_check_updates && return 0 || return 1
}

_cdx_maybe_check_updates() {
  _cdx_should_check_updates || return 0
  local plugin="$CODEX_PLUGIN_DIR/codex-update.sh"
  [[ -f "$plugin" ]] || return 0
  # Run quiet by default (prints only when an update is available).
  # Accept CDX_CHECK_UPDATES=info|verbose|always to show status even when up-to-date.
  local flags=(--check-only)
  case "${CDX_CHECK_UPDATES,,}" in
    info|verbose|always|print|show) : ;; # no --quiet
    *) flags+=(--quiet) ;;
  esac
  bash "$plugin" "${flags[@]}" 2>/dev/null || true
}

_cdx_usage() {
  printf 'cdx %s (%s)\n\n' "$CDX_VERSION" "$CDX_BUILD_DATE"
  cat <<EOF
Usage:
  cdx [--] [codex-args...]
  cdx --version            -> print cdx version
  cdx resume [args...]      -> ${CODEX_PLUGIN_DIR}/codex-resume.sh
  cdx update [args...]      -> ${CODEX_PLUGIN_DIR}/codex-update.sh
  cdx prompts [args...]     -> ${CODEX_PLUGIN_DIR}/prompts.sh
  cdx raw [codex-args...]   -> run codex with no defaults
  cdx profiles [args...]    -> ${CODEX_PLUGIN_DIR}/profiles.sh
  cdx plugins               -> list discovered subcommands
  cdx help                  -> show this help

Behavior:
  - If first arg is a known subcommand (script codex-<sub>.sh in ${CODEX_PLUGIN_DIR}), cdx runs it.
  - Unknown subcommands now error instead of falling back to Codex.
  - Use 'cdx -- ...' to pass through to '"${CODEX_BIN}"' with defaults.
  - Use 'cdx raw ...' to run '"${CODEX_BIN}"' with no defaults.

Environment:
  CODEX_BIN           (default: codex)
  CODEX_PLUGIN_DIR    (default: this file's directory)
  CDX_CHECK_UPDATES   (true/false; overrides config value 'cdx_check_updates')
                      Also accepts: info|verbose|always to print status even
                      when up-to-date.

Available subcommands in ${CODEX_PLUGIN_DIR}:
$( _cdx_list_plugins | sed 's/^/  - /' )
EOF
}

#########################################
# Command                               #
#########################################
cdx() {
  local codebin="${CODEX_BIN}"
  local plugin_dir="${CODEX_PLUGIN_DIR}"

  # Early handling for version/help to avoid pass-through
  case "${1-}" in
    -V|--version|version)
      printf 'cdx %s (%s)\n' "$CDX_VERSION" "$CDX_BUILD_DATE"
      return 0 ;;
    -h|--help|help)
      _cdx_usage
      return 0 ;;
  esac

  # Force pass-through to codex (ignore subcommand lookup)
  if [[ "$1" == "--" ]]; then
    # Optional update check on pass-through invocations
    _cdx_maybe_check_updates
    shift
    if ! command -v "$codebin" >/dev/null 2>&1; then
      printf 'cdx: error: cannot find codex executable (%s)\n' "$codebin" >&2
      return 127
    fi
    "$codebin" "${_CDX_DEFAULT_FLAGS[@]}" "$@"
    return $?
  fi

  # Help and utilities
  case "$1" in
    plugins)
      _cdx_plugins_cmd
      return 0;;
    update)
      # Skip auto-check to avoid duplicate checks when user is already updating
      : ;;
    *)
      # Optional update check for subcommands or pass-through
      _cdx_maybe_check_updates ;;
  esac

  # If first arg is non-option, treat as potential subcommand
  if [[ $# -ge 1 && "$1" != -* ]]; then
    local sub="$1"; shift
    case "$sub" in
      raw)
        if ! command -v "$codebin" >/dev/null 2>&1; then
          printf 'cdx: error: cannot find codex executable (%s)\n' "$codebin" >&2
          return 127
        fi
        "$codebin" "$@"
        return $? ;;
      *) ;;
    esac
    local candidate=""
    for ext in sh sg; do
      if [[ -f "$plugin_dir/$sub.$ext" ]]; then
        candidate="$plugin_dir/$sub.$ext"; break
      fi
    done
    if [[ -n "$candidate" ]]; then
      bash "$candidate" "$@"; return $?
    fi
    # Unknown subcommand: do not pass-through implicitly
    printf 'cdx: unknown subcommand "%s"\n' "$sub" >&2
    printf "Hint: use 'cdx -- %s %s' to pass through, or 'cdx raw %s %s' for no defaults.\n" "$sub" "$*" "$sub" "$*" >&2
    return 2
  fi

  if ! command -v "$codebin" >/dev/null 2>&1; then
    printf 'cdx: error: cannot find codex executable (%s)\n' "$codebin" >&2
    return 127
  fi
  "$codebin" "${_CDX_DEFAULT_FLAGS[@]}" "$@"
}

# Back-compat shim (optional wrappers can be added here)

# Short alias
alias cx='cdx'

#########################################
# Completions                           #
#########################################
_cdx_completions_bash() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if (( COMP_CWORD == 1 )); then
    local subs
    subs=$( { _cdx_list_plugins; echo -e 'raw\nhelp\nplugins'; } | tr '\n' ' ' )
    COMPREPLY=( $(compgen -W "$subs" -- "$cur") )
  else
    COMPREPLY=()
  fi
}

if [[ -n "$BASH_VERSION" ]]; then
  complete -F _cdx_completions_bash cdx 2>/dev/null || true
fi
