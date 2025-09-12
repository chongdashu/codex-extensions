# /setup-fast-tools

Append the project’s fast-tools prompt to `AGENTS.md` without attempting to install any system packages. This avoids requiring `sudo`.

What this does:

- Detects `AGENTS.md` and `tools/cdx/agents/fast-tools.md` in the current repo.
- Checks for the `FAST-TOOLS PROMPT v1` watermark to avoid duplicates.
- Appends the prompt if not already present.

It does not install `ripgrep`, `fd`/`fdfind`, or `jq`. If you need those tools, install them separately using your OS package manager (see brief guidance inside `tools/cdx/agents/fast-tools.md`).

Run this minimal, no-sudo snippet:

```bash
set -euo pipefail

# Find repo root (or stay in CWD if not a git repo)
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
agents="$repo_root/AGENTS.md"
prompt_src="$repo_root/tools/cdx/agents/fast-tools.md"

if [ ! -f "$agents" ]; then
  echo "AGENTS.md not found under $repo_root" >&2
  exit 1
fi
if [ ! -f "$prompt_src" ]; then
  echo "Prompt file missing: $prompt_src" >&2
  exit 1
fi

# Avoid duplicates using rg if available, otherwise grep
if command -v rg >/dev/null 2>&1; then
  if rg -q "FAST-TOOLS PROMPT v1" "$agents"; then
    echo "FAST-TOOLS prompt already present — nothing to do."
    exit 0
  fi
else
  if grep -q "FAST-TOOLS PROMPT v1" "$agents"; then
    echo "FAST-TOOLS prompt already present — nothing to do."
    exit 0
  fi
fi

printf "\n\n" >> "$agents"
cat "$prompt_src" >> "$agents"
echo "Appended fast-tools prompt to AGENTS.md"
```

## Quick Setup Script

Tell the user to that they need to install dependencies / third party tools after the prompt is appended to AGENTS.md, which they can utilise the following prompts for.

```bash
# Append prompt (idempotent)
./tools/cdx/scripts/setup-fast-tools.sh

# Append and install ripgrep/fd/jq (best effort)
./tools/cdx/scripts/setup-fast-tools.sh --install-deps
```

Notes:

- Non-interactive envs can add `--non-interactive` or `--dry-run` to print commands.
- Debian/Ubuntu may provide `fdfind` instead of `fd` (use `alias fd=fdfind`).
