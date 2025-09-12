#!/usr/bin/env bash
set -euo pipefail

# Smoke test for tools/cdx distribution. Safe to run anywhere.
# - Does not modify files (except optional prompts path discovery)
# - Handles missing npm/config gracefully

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENTRY="$ROOT_DIR/cdx/cdx.sh"

pass() { echo -e "\e[32m✓\e[0m $*"; }
warn() { echo -e "\e[33m!\e[0m $*"; }
fail() { echo -e "\e[31m✗\e[0m $*"; exit 1; }

[[ -f "$ENTRY" ]] || fail "Entry not found: $ENTRY"

# shellcheck source=/dev/null
source "$ENTRY"
pass "Sourced cdx entry"

# Plugins list
if cdx plugins >/dev/null 2>&1; then
  cdx plugins | sed -n '1,5p' >/dev/null
  pass "Listed plugins"
else
  fail "Failed to list plugins"
fi

# Profiles (graceful when config missing)
if cdx profiles --quiet >/dev/null 2>&1; then
  pass "Profiles command executed"
else
  warn "Profiles command reported missing config (expected if ~/.codex/config.toml is absent)"
fi

# Prompts path/list (non-fatal)
if cdx prompts path >/dev/null 2>&1 && cdx prompts list >/dev/null 2>&1; then
  pass "Prompts commands executed"
else
  warn "Prompts not available (no prompts dir); ok"
fi

# Update check (skip if npm missing)
if command -v npm >/dev/null 2>&1; then
  if cdx update --check-only --quiet >/dev/null 2>&1; then
    pass "Update check completed"
  else
    warn "Update check returned non-zero (may indicate update available); continuing"
  fi
else
  warn "npm not found; skipping update check"
fi

echo "---"
echo "Smoke test completed. If all checks are green, you're good to go."

