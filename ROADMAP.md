# ROADMAP

Seed backlog for `improve-repo` itself. Format is the same schema the pipeline produces and consumes, so this file can be fed back into `./improve-repo.sh improve-repo --skip-research`.

## Improvement Backlog

| Priority | Title                              | Description                                                                                                        | Source     |
| -------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ---------- |
| P1       | Create feature branch before research | Research passes currently commit `ROADMAP.md` directly to the base branch. Branch off `ai-improve/<ts>` up front so all pipeline commits are isolated. | internal   |
| P1       | `set -o pipefail` inside tee subshells | `run_claude` and `run_codex_exec` pipe to `tee`; exit code comes from `tee`, masking tool failures. Add `set -o pipefail` inside the subshell and check `PIPESTATUS[0]`. | internal   |
| P1       | Timeout wrapper around AI calls    | Hung `claude`/`codex` invocations block the loop indefinitely. Wrap every call in `timeout 45m` (configurable via `--timeout`).                      | internal   |
| P1       | Auth pre-flight check              | `check_tools` only verifies binaries exist. Add `claude --version` / `codex --version` style auth probes so stale credentials fail fast.              | internal   |
| P1       | `--base-branch` override           | `detect_base_branch` auto-picks `main`/`master`. Allow explicit override for repos with a `develop` or `trunk` workflow.                               | internal   |
| P1       | Log rotation                       | `.ai-improve-logs/` grows without bound. Keep the last N runs (default 10) and prune older by mtime.                                                   | internal   |
| P1       | CHANGELOG `Unreleased` section     | Follow Keep-a-Changelog convention so each release can be drafted as `## [Unreleased]` → `## [x.y.z]`.                                                 | internal   |
| P2       | Resume / checkpoint                | Persist phase state to `.ai-improve-logs/state.json` after each step. Add `--resume` to restart from the last failed phase instead of Pass 1.          | internal   |
| P2       | `--pause-after-research`           | Gate the pipeline between research and implementation so the user can hand-edit `ROADMAP.md`. Cheapest lever for output quality.                       | internal   |
| P2       | External prompt files              | Move embedded heredoc prompts to `prompts/research-p1.md`, `prompts/implement.md`, etc. Diffable, version-controlled, user-customizable.               | internal   |
| P2       | Cost and token reporting           | Parse claude/codex session summaries (or `--json` output) and surface per-phase tokens + USD in the final summary table.                               | internal   |
| P2       | Structured ROADMAP schema          | `roadmap_counts` relies on fuzzy grep matches against priority-prefixed table cells. Define a strict schema (YAML frontmatter or fixed columns) and parse once.  | internal   |
| P2       | PR template extraction             | Move the inline PR body heredoc into `.github/PULL_REQUEST_TEMPLATE.md` in the target repo (optional install via `--install-template`).                | internal   |
| P3       | Real run screenshot in README      | Replace the abstract summary block with a real captured terminal run (DPI-aware per `screenshots.md` convention).                                      | internal   |
| P3       | Per-repo config file               | Support `.improve-repo.yml` in target repos for default `--loops`, `--research-passes`, skip flags, and base branch overrides.                         | internal   |
| P3       | Parallel research passes           | Pass 1 (broad) and Pass 3 (internal audit) are independent. Run concurrently, join before Pass 2.                                                      | internal   |
| P3       | Improved error propagation         | Use `PIPESTATUS` throughout and bubble meaningful exit codes to the loop driver so `set -e` can actually catch failures.                               | internal   |
| P3       | Per-phase `--help`                 | Expand usage to document each phase's inputs/outputs so users can reason about `--skip-*` combinations.                                                | internal   |

## Internal Audit

Findings backing the P1/P2 items above.

- **Branching order** — `do_research_pass_*` runs before `do_implement`, and `auto_commit_roadmap` issues commits against whatever branch is checked out. If the user starts on `main`, research commits land on `main`.
- **Exit code masking** — `claude ... 2>&1 | tee "$log_file"` in a subshell: `tee` always succeeds, so a crashed `claude` exits the subshell 0. `set -e` at the top level never sees the failure.
- **Auth drift** — `claude` and `codex` tokens expire silently. The pipeline invests minutes in Pass 1 only to fail at implementation with no preserved state.
- **Format coupling** — Roadmap progress reporting (`roadmap_counts`) and implementation selection (`do_implement` prompt: "items that are NOT already marked as DONE") both depend on the model producing a specific markdown shape. A schema removes the fragility.
- **Log sprawl** — Every run writes N logs per loop. Over weeks, `.ai-improve-logs/` becomes the largest directory in the repo.

## Done

_(populated as items ship)_
