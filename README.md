# Codex CLI Extensions (cdx)

![Bash](https://img.shields.io/badge/Bash-4%2B-1f425f?logo=gnu-bash&logoColor=white)
![OS](https://img.shields.io/badge/OS-macOS%20%7C%20Linux-lightgrey)
![Type](https://img.shields.io/badge/Type-CLI%20Helpers-blue)

Lightweight, POSIX‑friendly helpers that enhance the Codex CLI with a single entrypoint, plugin routing, prompt management, and a quick smoke test.

## Why cdx

As a worked through famliarising myself with the Codex CLI, I found that many of the quality of life features were missing / not yet released. I documented my findings and ended up creating this wrapper to accelerate and enhance my productivity.

► [**🎥 Watch the Video**](https://www.youtube.com/watch?v=3564u77Vyqk)

► [**🧰 Get the Builder Pack**](https://rebrand.ly/aa0f77)

- Fast: source one file and get a tidy `cdx` wrapper + `cx` alias.
- Extensible: drop scripts in `cdx/plugins/` and call `cdx <name>`.
- Practical: ship prompts and install them to `~/.codex/prompts`.
- Safe: smoke test validates sourcing, plugins, and update checks.

## Quick Start

- From this repo (local install):
  ```bash
  # Add cdx to your shell
  bash cdx/install.sh           # installs prompts and adds shell sourcing
  # Or for a temporary session
  source cdx/cdx.sh && cdx help
  ```
  

## Usage

```bash
cdx help            # usage and discovered plugins
cdx plugins         # list subcommands from cdx/plugins/
cdx prompts list    # show repo and installed prompts
cdx prompts install # install prompts to ~/.codex/prompts
cdx profiles        # list profiles from ~/.codex/config.toml
cdx update --check-only  # check Codex CLI updates (uses npm)
cdx -- --profile NAME     # pass through to codex with defaults
cdx raw <args>            # run codex without defaults
```

> Default pass-through now targets `gpt-5-codex` with `model_reasoning_effort="high"`, `model_reasoning_summary="auto"`, and `model_reasoning_summary_format="experimental"` while enabling `--search` and `--dangerously-bypass-approvals-and-sandbox`. Use `cdx raw` to skip these defaults.

## Repo at a Glance

```text
cdx/
  cdx.sh            # entrypoint defines `cdx` and alias `cx`
  plugins/          # profiles.sh, prompts.sh, update.sh, resume.sh
  prompts/          # optional Markdown prompts (fast-tools lives here)
  scripts/          # utilities
  smoke-test.sh     # non-destructive health check
```

## Repository Layout

- `cdx/cdx.sh` — entrypoint defining the `cdx` function and `cx` alias.
- `cdx/plugins/` — subcommands (`profiles.sh`, `prompts.sh`, `update.sh`, `resume.sh`).
- `cdx/prompts/` — optional Markdown prompts for Codex (including `setup-fast-tools.md`).
- `cdx/scripts/` — utilities.
- `cdx/smoke-test.sh` — non‑destructive health check.

> Tip: `cdx/prompts/setup-fast-tools.md` contains the fast-tools prompt. Copy that block into `AGENTS.md` if it is missing (the install script will drop prompts into `~/.codex/prompts`). If your prompts live elsewhere, set `REPO_PROMPTS_DIR=/path/to/prompts` before running `cdx prompts`.

## Requirements & Troubleshooting

- Bash 4+, macOS/Linux; Windows via WSL or Git Bash.
- `npm` optional (only for `cdx update`). If `codex` is not on PATH after update, check `npm prefix -g` and your shell rc file.
- `ripgrep` optional (faster plugin discovery). If missing, `cdx plugins` falls back to `find` automatically.

## Contributing

See `AGENTS.md` for style, testing, and PR conventions. Please keep the smoke test green: `bash cdx/smoke-test.sh`.

—
Quick links: `AGENTS.md` · `cdx/README.md`
