# ROADMAP

Seed backlog for `improve-repo` itself. Format is the same schema the pipeline produces and consumes, so this file can be fed back into `./improve-repo.sh improve-repo --skip-research`.

## Improvement Backlog

| Priority | Title                              | Description                                                                                                        | Source     |
| -------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ---------- |
| DONE     | Create feature branch before research | Research passes currently commit `ROADMAP.md` directly to the base branch. Branch off `ai-improve/<ts>` up front so all pipeline commits are isolated. | internal   |
| DONE     | `set -o pipefail` inside tee subshells | `run_claude` and `run_codex_exec` pipe to `tee`; exit code comes from `tee`, masking tool failures. Add `set -o pipefail` inside the subshell and check `PIPESTATUS[0]`. | internal   |
| DONE     | Timeout wrapper around AI calls    | Hung `claude`/`codex` invocations block the loop indefinitely. Wrap every call in `timeout 45m` (configurable via `--timeout`).                      | internal   |
| DONE     | Auth pre-flight check              | `check_tools` only verifies binaries exist. Add `claude --version` / `codex --version` style auth probes so stale credentials fail fast.              | internal   |
| DONE     | `--base-branch` override           | `detect_base_branch` auto-picks `main`/`master`. Allow explicit override for repos with a `develop` or `trunk` workflow.                               | internal   |
| DONE     | Log rotation                       | `.ai-improve-logs/` grows without bound. Keep the last N runs (default 10) and prune older by mtime.                                                   | internal   |
| DONE     | CHANGELOG `Unreleased` section     | Follow Keep-a-Changelog convention so each release can be drafted as `## [Unreleased]` → `## [x.y.z]`.                                                 | internal   |
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
| DONE     | Signal trap for cleanup            | Ctrl-C mid-run leaves the stash, feature branch, and partial commits orphaned. `print_summary` never fires on abort. Add `trap cleanup INT TERM ERR`.    | internal   |
| DONE     | Concurrency lockfile               | `TIMESTAMP=$(date +%Y%m%d-%H%M%S)` has second resolution — two fast invocations collide on branch name, stash slot, and ROADMAP. Flock-gate via `.ai-improve-logs/.lock` and use nanosecond timestamps. | internal   |
| DONE     | Git identity preflight             | If `user.email`/`user.name` are unset, the pipeline fails 10 minutes in at first commit. Check `git config user.email` next to `check_tools`.          | internal   |
| DONE     | `--remote` override                | `git push -u origin "$BRANCH_NAME"` hardcodes `origin`. Detect the remote or expose `--remote` for repos using `upstream`/custom names.                | internal   |
| DONE     | Remove `--no-verify` from auto-commit | `.gitignore` auto-commit bypasses hooks, violating the rule the tool itself flags in audits. Drop `--no-verify` and let hooks run.                   | internal   |
| DONE     | Bash 4+ version guard              | Script uses features that break on macOS default bash 3.2. Add `((BASH_VERSINFO[0] < 4))` guard with a clear error.                                    | internal   |
| P2       | `--cleanup` subcommand             | Tear down an aborted run: delete the feature branch, restore the stash, prune logs. Pairs with trap-based cleanup.                                     | internal   |
| P2       | OS notification on completion      | Long pipelines (20+ min) deserve a finish signal. Terminal bell + `notify-send`/`osascript`/PowerShell toast by platform.                              | internal   |
| P2       | Persist summary to file            | `print_summary` only hits stdout. Also write `.ai-improve-logs/summary-${TIMESTAMP}.md` so closed terminals don't lose the receipt.                    | internal   |
| P2       | Retry + backoff on API errors      | A single rate-limit or 5xx from claude/codex kills a 30-minute run. Wrap calls with bounded exponential retry.                                         | internal   |
| P2       | Model refusal detection            | If the model refuses or hits context limits, the pipeline reports success and moves on. Grep logs for refusal signatures and surface them.             | internal   |
| P2       | `--model` override per phase       | Different phases want different models (Haiku for broad scan, Opus for implementation). Expose `--research-model`/`--implement-model`.                 | internal   |
| P2       | Repo-type profile files            | Generic prompts produce generic output. Detect stack (`build.gradle.kts`, `pyproject.toml`, `manifest.json`) and load `profiles/<type>.md`.            | internal   |
| P2       | `--json` / `--quiet` output        | Machine-readable mode for CI and scripting. Emit structured phase results and summary.                                                                 | internal   |
| P3       | Input validation on `<repo-path>`  | Reject paths starting with `-` and validate `[[ -d "$REPO_PATH" ]]` before any expansion. Defense-in-depth on shell metachars.                         | internal   |
| P3       | Per-invocation log size ceiling    | Even with rotation across runs, a single runaway loop can bloat `.ai-improve-logs/` unbounded. Cap per-invocation.                                     | internal   |
| P3       | Path-with-spaces sweep             | Most `"$REPO_PATH"` usages quote correctly, but a full audit is overdue — Git Bash on Windows will find the gaps.                                      | internal   |
| P3       | Minimum version pins               | `claude`, `codex`, `gh` all ship breaking changes. Probe `--version` against known-good minima in preflight and warn on drift.                         | internal   |

## Internal Audit

Findings backing the P1/P2 items above.

- **Branching order** — `do_research_pass_*` runs before `do_implement`, and `auto_commit_roadmap` issues commits against whatever branch is checked out. If the user starts on `main`, research commits land on `main`.
- **Exit code masking** — `claude ... 2>&1 | tee "$log_file"` in a subshell: `tee` always succeeds, so a crashed `claude` exits the subshell 0. `set -e` at the top level never sees the failure.
- **Auth drift** — `claude` and `codex` tokens expire silently. The pipeline invests minutes in Pass 1 only to fail at implementation with no preserved state.
- **Format coupling** — Roadmap progress reporting (`roadmap_counts`) and implementation selection (`do_implement` prompt: "items that are NOT already marked as DONE") both depend on the model producing a specific markdown shape. A schema removes the fragility.
- **Log sprawl** — Every run writes N logs per loop. Over weeks, `.ai-improve-logs/` becomes the largest directory in the repo.
- **Abort recovery gap** — No `trap` handler. Ctrl-C strands the stash, the partial branch, and whatever state the in-flight phase was mutating. The user-facing "you have stashed changes" reminder only runs on clean exit.
- **Concurrency races** — Second-resolution timestamps plus no lockfile means two simultaneous invocations on the same repo step on each other's branch names, stash, and roadmap commits.
- **Hook bypass self-foul** — The `.gitignore` auto-commit uses `--no-verify`, which is precisely the anti-pattern the tool would call out when auditing someone else's script.
- **Prompt genericness** — The same prompts target Python libs, Android apps, Chrome extensions, and C++ desktop apps. Most of the "missing features" the model surfaces are plumbing advice rather than stack-specific insight.
- **Silent model refusals** — When `claude` or `codex` refuses (context, safety, ambiguity) the pipeline reports success. Post-run roadmap counts will look fine while zero actual implementation happened.

## Done

### v3.1.0 — 2026-04-19

All 13 P1 items shipped in six commits. Dogfooded by hand because the pipeline isn't yet cleared to rewrite itself:

- Create feature branch before research
- `set -o pipefail` inside tee subshells
- Timeout wrapper around AI calls (`--timeout`, default 45m)
- Auth pre-flight check (`claude --version`, `codex --version`, `gh auth status`)
- `--base-branch` override
- Log rotation (`--keep-logs N`, default 10)
- CHANGELOG `Unreleased` section (Keep-a-Changelog)
- Signal trap for cleanup (`EXIT`/`INT`/`TERM`)
- Concurrency lockfile (mkdir-based, portable)
- Git identity preflight
- `--remote` override
- Remove `--no-verify` from auto-commit
- Bash 4+ version guard
