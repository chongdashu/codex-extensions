# /setup-fast-tools

Append the fast-tools prompt from `./cdx/agents/fast-tools.md` into `./AGENTS.md` for the current working directory whenever it is missing.

```bash
set -euo pipefail

cwd=$(pwd)
prompt_src="$cwd/cdx/agents/fast-tools.md"
agents="$cwd/AGENTS.md"

if [ ! -f "$prompt_src" ]; then
  echo "Missing $prompt_src" >&2
  exit 1
fi

if [ -f "$agents" ]; then
  if command -v rg >/dev/null 2>&1; then
    if rg -q "FAST-TOOLS PROMPT v1" "$agents"; then
      echo "FAST-TOOLS prompt already present."
      exit 0
    fi
  elif grep -q "FAST-TOOLS PROMPT v1" "$agents"; then
    echo "FAST-TOOLS prompt already present."
    exit 0
  fi
else
  touch "$agents"
fi

if [ -s "$agents" ]; then
  printf "\n\n" >> "$agents"
fi

cat "$prompt_src" >> "$agents"
echo "Appended fast-tools prompt to $agents"
```
