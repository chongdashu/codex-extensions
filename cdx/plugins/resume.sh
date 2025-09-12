#!/usr/bin/env bash
set -euo pipefail

# Legacy helper: prefer first‑party resume in Codex when available.
if command -v codex >/dev/null 2>&1; then
  echo "Hint: Use Codex's built-in resume if available (e.g., 'codex resume')." >&2
fi

# If an old helper exists, try to run it for back-compat
if [[ -f "scripts/codex-resume.sh" ]]; then
  exec bash scripts/codex-resume.sh "$@"
fi

echo "cdx resume: no legacy helper found. Use first‑party 'codex resume' or provide a session path." >&2
exit 1

