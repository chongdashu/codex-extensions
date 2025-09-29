# Changelog

All notable changes to this project will be documented in this file.

This project adheres to semantic versioning. Dates are in YYYY-MM-DD.

## [0.2.3] - 2025-09-29

- fix: Re-run plugin directory detection each invocation so built-in subcommands work after env overrides.
- fix: Warn once when falling back to bundled plugins, keeping misconfigurations visible without blocking usage.

## [0.2.2] - 2025-09-16

- chore: Installer now always sources cdx and copies bundled prompts without needing `--with-prompts`.
- docs: Refresh README and AGENTS instructions to match the simplified install flow.

## [0.2.1] - 2025-09-16

- feat: Default `cdx` pass-through now targets `gpt-5-codex` and enables experimental reasoning summaries.
- fix: `setup-fast-tools` now works from the current directory, creating `AGENTS.md` when missing and appending the fast-tools prompt without duplicate noise.
- docs: Update `/setup-fast-tools`, README, and CHANGELOG to reflect the streamlined workflow.

## [0.2.0] - 2025-09-16

- fix: Prompt installer now searches correct locations in order of preference and respects `REPO_PROMPTS_DIR`.
  - Looks in `repo_root/prompts`, then `cdx/prompts`, then a legacy vendored prompts path.
  - Improves messages when no prompts are found.
- fix: `cdx prompts` plugin resolves repo root more robustly and mirrors the same source directory priority.
  - Adds upward walk to detect `.git`, `AGENTS.md`, or `README.md`.
  - `cdx prompts path` reflects resolved source/dest paths.
- fix: `cdx plugins` no longer requires ripgrep; falls back to `find` when `rg` is unavailable.
- docs: Remove “vendored copies” wording and one‑liner; simplify Quick Start.
- chore: Bump `cdx` version to `0.2.0` and update build date to `2025-09-16`.

## [0.1.0] - 2025-09-11

- Initial public release.
- Adds `cdx` shell wrapper, plugin routing, prompts management, update check, and smoke test.
