# Changelog

All notable changes to this project will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [3.2.0] - 2026-04-19

### Added
- `prompts/*.md` — phase prompt templates with embedded fallbacks. `--prompts-dir` / `$IMPROVE_REPO_PROMPTS_DIR` redirect to custom directories.
- `prompts/profiles/*.md` — stack-specific guidance auto-appended to research prompts. Initial set: android, python, node, chrome-extension, userscript, rust, powershell, dotnet.
- `--research-model`, `--implement-model`, `--review-model` — per-phase model overrides passed through to `claude` and `codex`.
- `--max-retries N` + `--retry-backoff S` — exponential backoff on transient AI failures. Timeouts never retry.
- `--quiet` / `--json` — output modes for CI and scripting contexts.
- `--resume` — picks the newest `.ai-improve-logs/state-<ts>.txt` and skips phases already logged as completed. Each phase writes a checkpoint on success.
- `--pause-after-research` — interactive gate before implementation so `ROADMAP.md` can be hand-edited. TTY-only; ignored under `--json`/`--quiet`/`--dry-run`.
- `--cleanup` — tears down orphaned locks, `ai-improve/*` branches, and rotates logs without running the pipeline.
- `ROADMAP-SCHEMA.md` — documents the strict format the pipeline reads and writes.
- Summary file — `.ai-improve-logs/summary-${TIMESTAMP}.md` persists the run receipt.
- OS notification on finish — `notify-send` / `osascript` / PowerShell beep with terminal-bell fallback.
- Cost reporting — best-effort parse of input/output tokens and USD markers from call logs; surfaced in summary and JSON.
- PR-template detection — if target repo has `.github/PULL_REQUEST_TEMPLATE.md`, its body is prepended to the pipeline summary in the PR body.

### Changed
- Model refusals (rate limits, context overflow, policy blocks) now detected via log-tail grep and surfaced with exit code 2 instead of reporting success.
- `roadmap_counts` now uses a structured awk parser; priority strings in description cells no longer trip the counter. Reports `DONE:<n>` when shipped work exists.
- Research prompts (both external templates and embedded fallbacks) now spec the ROADMAP schema explicitly so models don't drift to bullet lists.

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
