# Changelog

All notable changes to this project will be documented in this file.

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
