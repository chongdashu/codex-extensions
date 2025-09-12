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

- Global install (recommended):
  ```bash
  # Install globally under ~/.codex and update your shell rc
  bash cdx/install.sh --with-prompts        # add --sudo to create /usr/local/bin/cdx symlink
  # Open a new shell or source your rc, then:
  cdx --version
  ```
- Temporary session (no install):
  ```bash
  source cdx/cdx.sh && cdx help
  ```
- One‑liner (template when vendored as tools/cdx):
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

Base requirements
- Bash 3.2+ (macOS) / 4+ or zsh; fish supported for PATH + `cx` helper.
- macOS or Linux; Windows via WSL or Git Bash.
- Core POSIX tools: `awk`, `sed`, `find`, `install`.

Recommended (optional)
- ripgrep (`rg`) • fd • jq — used by some helpers; cdx degrades gracefully if absent.
- bat — only needed if you choose to alias `cat` to `bat` in your shell.
  - Note for Debian/Ubuntu: the package installs the binary as `batcat`. Either alias `bat=batcat` or install from another source.

Install recommended tools
- macOS (Homebrew):
  ```bash
  brew install ripgrep fd jq bat
  ```
- Ubuntu/Debian:
  ```bash
  sudo apt-get update
  sudo apt-get install -y ripgrep fd-find jq bat
  # Make fd accessible as `fd` instead of `fdfind` (optional):
  mkdir -p ~/.local/bin && ln -sf "$(command -v fdfind)" ~/.local/bin/fd && export PATH="$HOME/.local/bin:$PATH"
  # bat may be installed as `batcat`:
  echo "alias bat=batcat" >> ~/.bashrc   # or ~/.zshrc
  ```
- Other distros: use your package manager, or install from upstream releases.

Optional (Codex CLI updates)
- `npm` is only needed for `cdx update`. If `codex` is not on PATH after update, check `npm prefix -g` and your shell rc file.

If `cdx` is not found after install
- Ensure your rc file contains:
  ```bash
  export CODEX_HOME="$HOME/.codex"
  export PATH="$CODEX_HOME/bin:$PATH"
  source "$CODEX_HOME/lib/codex-init.sh"
  ```
  and start a new shell or `source ~/.bashrc` / `source ~/.zshrc`.


## Uninstall

```bash
bash cdx/uninstall.sh --remove-symlink --remove-home
```

This removes the init blocks from `~/.bashrc`, `~/.zshrc`, fish config, an optional `/usr/local/bin/cdx` symlink, and the `~/.codex` install (with `--remove-home`).

## Contributing

See `AGENTS.md` for style, testing, and PR conventions. Please keep the smoke test green: `bash cdx/smoke-test.sh`.

—
Quick links: `AGENTS.md` · `cdx/README.md`
