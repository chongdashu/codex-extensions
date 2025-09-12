# Repository Guidelines

## Project Structure & Module Organization
- `cdx/cdx.sh` — entrypoint; sources a `cdx` shell function and `cx` alias.
- `cdx/plugins/` — subcommands invoked as `cdx <name>` (e.g., `profiles.sh`, `prompts.sh`, `update.sh`).
- `cdx/prompts/` — optional prompt files (Markdown). See `cdx/plugins/prompts.sh`.
- `cdx/agents/fast-tools.md` — reusable prompt to append to this file.
- `cdx/scripts/` — utility scripts (e.g., `setup-fast-tools.sh`).
- `cdx/install.sh`, `cdx/smoke-test.sh` — installer and health check.
Note: When embedding in another repo, `tools/cdx/**` is the recommended path. Set `REPO_PROMPTS_DIR` to override prompt source if layouts differ.

## Build, Test, and Development Commands
- Load locally: `source cdx/cdx.sh && cdx help` (defines `cdx` in your shell).
- Smoke test: `bash cdx/smoke-test.sh` (verifies sourcing, plugins, prompts, update check).
- Install to shell: `bash cdx/install.sh [--with-prompts]`.
- Update Codex CLI: `cdx update --check-only` or `cdx update [--sudo]`.
- Prompts: `cdx prompts list` • `cdx prompts install` • `cdx prompts path`.
- Profiles: `cdx profiles` or `cdx profiles --quiet`.

## Coding Style & Naming Conventions
- Bash with `set -euo pipefail`; 2‑space indent; quote variables; prefer arrays.
- Functions/locals: `snake_case`; env: `SCREAMING_SNAKE_CASE` (e.g., `CODEX_BIN`).
- Prefer `printf` over `echo -e` and explicit `return`/exit codes.
- Plugins live in `cdx/plugins/<name>.sh` and are invoked as `cdx <name>`.

## Testing Guidelines
- Lint: `shellcheck cdx/**/*.sh` (aim for zero warnings).
- Format: `shfmt -i 2 -sr -w cdx`.
- Syntax check: `bash -n cdx/**/*.sh`.
- Keep `cdx/smoke-test.sh` green; add focused tests near changed scripts when practical.

## Commit & Pull Request Guidelines
- No history exists yet; use Conventional Commits (e.g., `feat:`, `fix:`, `docs:`).
- PRs should describe behavior, list key commands/output, and link issues.
- Update `README.md`/`--help` text when CLI surfaces change; include before/after examples.

## Agent-Specific Instructions
- For repo-wide search, use `rg` (ripgrep) and `fd/fdfind`; avoid `grep/find`.
- Cap file reads at ~250 lines; prefer `rg -n -A3 -B3` for context.
- Use `jq` for JSON parsing.
- Append the fast-tools prompt (idempotent): `bash cdx/scripts/setup-fast-tools.sh [--install-deps]`.

