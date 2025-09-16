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
    if [[ -n "$src" ]]; then
      [[ "$src" != /* ]] && src="$PWD/$src"
      base=$(cd "$(dirname "$src")" 2>/dev/null && pwd || true)
    fi
  fi
  if [[ -z "$base" ]]; then
    base="$HOME/.codex/cdx"
  elif [[ ! -d "$base/plugins" && -d "$base/cdx/plugins" ]]; then
    base="$base/cdx"
  fi
  printf '%s' "$base/plugins"
}

#########################################
# Configuration (overridable via env)   #
#########################################
: "${CODEX_BIN:=codex}"
: "${CDX_VERSION:=0.2.0}"
: "${CDX_BUILD_DATE:=2025-09-16}"
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
  if command -v rg >/dev/null 2>&1; then
    rg --files "$plugin_dir" 2>/dev/null | sed -nE 's#^.*/([^/]+)\.(sh|sg)$#\1#p' | sort -u
  else
    # Fallback when ripgrep is unavailable
    find "$plugin_dir" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.sg' \) -print 2>/dev/null \
      | sed -nE 's#^.*/([^/]+)\.(sh|sg)$#\1#p' | sort -u
  fi
}

_cdx_find_plugin_script() {
  local plugin_dir="$1" name="$2" ext candidate
  for ext in sh sg; do
    for candidate in "$plugin_dir/$name.$ext" "$plugin_dir/codex-$name.$ext"; do
      if [[ -f "$candidate" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
    done
  done
  return 1
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
    local resolved
    resolved=$(_cdx_find_plugin_script "$plugin_dir" "$name") || resolved="$plugin_dir/$name"
    printf '  - %s  (%s)\n' "$name" "$resolved"
  done <<<"$list"
  printf 'Tip: run `cdx <plugin> --help` for plugin usage.\n'
}

_cdx_parse_bool() {
  # returns 0 (true) or 1 (false); empty -> 1
  local raw="${1-}" val
  val=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
  [[ -z "$val" ]] && return 1
  case "$val" in
    1|true|yes|on) return 0;;
    0|false|no|off) return 1;;
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
  local mode
  mode=$(printf '%s' "${CDX_CHECK_UPDATES:-}" | tr '[:upper:]' '[:lower:]')
  case "$mode" in
    info|verbose|always|print|show) : ;; # no --quiet
    *) flags+=(--quiet) ;;
  esac
  bash "$plugin" "${flags[@]}" 2>/dev/null || true
}

_cdx_usage() {
  printf 'cdx %s (%s)\n\n' "$CDX_VERSION" "$CDX_BUILD_DATE"
  local resume_plugin update_plugin prompts_plugin profiles_plugin
  resume_plugin=$(_cdx_find_plugin_script "$CODEX_PLUGIN_DIR" "resume") || resume_plugin="$CODEX_PLUGIN_DIR/resume.sh"
  update_plugin=$(_cdx_find_plugin_script "$CODEX_PLUGIN_DIR" "update") || update_plugin="$CODEX_PLUGIN_DIR/update.sh"
  prompts_plugin=$(_cdx_find_plugin_script "$CODEX_PLUGIN_DIR" "prompts") || prompts_plugin="$CODEX_PLUGIN_DIR/prompts.sh"
  profiles_plugin=$(_cdx_find_plugin_script "$CODEX_PLUGIN_DIR" "profiles") || profiles_plugin="$CODEX_PLUGIN_DIR/profiles.sh"
  cat <<EOF
Usage:
  cdx [--] [codex-args...]
  cdx --version            -> print cdx version
  cdx resume [args...]      -> ${resume_plugin}
  cdx update [args...]      -> ${update_plugin}
  cdx prompts [args...]     -> ${prompts_plugin}
  cdx raw [codex-args...]   -> run codex with no defaults
  cdx profiles [args...]    -> ${profiles_plugin}
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
    candidate=$(_cdx_find_plugin_script "$plugin_dir" "$sub") || candidate=""
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
