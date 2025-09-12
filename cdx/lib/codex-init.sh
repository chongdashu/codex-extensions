#!/usr/bin/env bash
set -euo pipefail

# codex-init.sh: Common initializer for Codex Extensions (cdx)
# - Exports CODEX_HOME (defaults to ~/.codex)
# - Ensures $CODEX_HOME/bin is on PATH
# - Defaults CODEX_PLUGIN_DIR to $CODEX_HOME/extensions
# - Sources the installed cdx.sh to define the `cdx` function and completions

: "${CODEX_HOME:=$HOME/.codex}"
export CODEX_HOME

case ":${PATH}:" in
  *":$CODEX_HOME/bin:"*) : ;;
  *) PATH="$CODEX_HOME/bin:$PATH" ;;
esac
export PATH

: "${CODEX_PLUGIN_DIR:=$CODEX_HOME/extensions}"
export CODEX_PLUGIN_DIR

# shellcheck source=/dev/null
if [[ -r "$CODEX_HOME/bin/cdx.sh" ]]; then
  source "$CODEX_HOME/bin/cdx.sh"
else
  printf 'codex-init: missing %s\n' "$CODEX_HOME/bin/cdx.sh" >&2
fi

