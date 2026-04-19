# Changelog

All notable changes to this project will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [3.1.0] - 2026-04-19

### Fixed
- Research passes were committing `ROADMAP.md` directly to the base branch. The feature branch now exists before research starts, so all pipeline commits stay isolated.
- `tee` in the AI-call subshells masked `claude`/`codex` exit codes. Subshells now use `set -o pipefail` and inspect `PIPESTATUS[0]`.
- Hung AI invocations could block indefinitely. All calls are wrapped in `timeout --foreground $AI_TIMEOUT` (default 45m).
- Concurrent invocations on the same repo collided on branch name, stash slot, and roadmap commits. Added portable mkdir-based lockfile and unique PID+RANDOM timestamp suffix.
- `.gitignore` auto-commit no longer bypasses hooks (`--no-verify` dropped).

### Added
- `--timeout DURATION` — configurable per-call wall-clock ceiling (e.g. `2h`, `90m`).
- `--base-branch NAME` — override auto-detected base (`main`/`master`) for repos with `develop`/`trunk` workflows.
- `--remote NAME` — override push remote (auto-detects, prefers `origin`).
- `--keep-logs N` — retain last N prior runs' logs (default 10); older pruned automatically.
- Preflight probes: bash 4+ version guard, `git user.email`/`user.name` check, `claude --version` / `codex --version` / `gh auth status` validation.
- Signal trap: `EXIT`/`INT`/`TERM` handler releases the lockfile and prints concrete recovery commands on abort.

## [3.0.0] - 2026-04-19

### Added
- Multi-pass research: broad competitor scan, deep dive, internal audit
- Multi-loop mode (`--loops N`) for iterative improvement cycles
- Configurable research depth (`--research-passes 1-3`)
- Per-step timing and summary table
- Auto-stash of uncommitted changes before pipeline runs
- Auto-commit of `ROADMAP.md` between phases
- Shorthand resolution: `<name>` resolves to `~/repos/<name>`
- `.ai-improve-logs/` auto-added to target repo `.gitignore`

### Pipeline
- Research → Implement (P1) → UX Polish → Code Review → PR
- PR created only on the final loop
- Isolated feature branch `ai-improve/<timestamp>`

### Requirements
- `claude`, `codex`, `gh`, `git`, `bash`
