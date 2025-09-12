# Codex CLI Extensions (cdx)

![Bash](https://img.shields.io/badge/Bash-4%2B-1f425f?logo=gnu-bash&logoColor=white)
![OS](https://img.shields.io/badge/OS-macOS%20%7C%20Linux-lightgrey)
![Type](https://img.shields.io/badge/Type-CLI%20Helpers-blue)

Lightweight, POSIX‑friendly helpers that enhance the Codex CLI with a single entrypoint, plugin routing, prompt management, and a quick smoke test. Use directly or vendor under `tools/cdx/` in your own repo.

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
  bash cdx/install.sh --with-prompts   # optional: copies prompts
  # Or for a temporary session
  source cdx/cdx.sh && cdx help
  ```
- One‑liner (template for vendored copies):
  ```bash
  # Replace OWNER/REPO/BRANCH with your values
  bash <(curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/BRANCH/tools/cdx/install.sh) --with-prompts
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

## Repo at a Glance

```text
cdx/
  cdx.sh            # entrypoint defines `cdx` and alias `cx`
  plugins/          # profiles.sh, prompts.sh, update.sh, resume.sh
  prompts/          # optional Markdown prompts
  agents/           # reusable prompts (e.g., fast-tools.md)
  scripts/          # setup-fast-tools.sh and utilities
  smoke-test.sh     # non-destructive health check
```

## Repository Layout

- `cdx/cdx.sh` — entrypoint defining the `cdx` function and `cx` alias.
- `cdx/plugins/` — subcommands (`profiles.sh`, `prompts.sh`, `update.sh`, `resume.sh`).
- `cdx/prompts/` — optional Markdown prompts for Codex.
- `cdx/agents/fast-tools.md` — reusable prompt you can append to `AGENTS.md`.
- `cdx/scripts/` — utilities (e.g., `setup-fast-tools.sh`).
- `cdx/smoke-test.sh` — non‑destructive health check.

## Embed In Your Repo

Vendor as `tools/cdx/**` and call the installer from your repo root:

```bash
bash tools/cdx/install.sh --with-prompts
```

If your prompts live elsewhere, set `REPO_PROMPTS_DIR=/path/to/prompts` before running `cdx prompts`.

> Tip: Append the fast‑tools prompt to `AGENTS.md` with `bash cdx/scripts/setup-fast-tools.sh` (idempotent; add `--install-deps` to install rg/fd/jq).

## Requirements & Troubleshooting

- Bash 4+, macOS/Linux; Windows via WSL or Git Bash.
- `npm` optional (only for `cdx update`). If `codex` is not on PATH after update, check `npm prefix -g` and your shell rc file.

## Contributing

See `AGENTS.md` for style, testing, and PR conventions. Please keep the smoke test green: `bash cdx/smoke-test.sh`.

—
Quick links: `AGENTS.md` · `cdx/README.md`
