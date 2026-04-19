<div align="center">

# improve-repo

**Automated repository improvement pipeline — research, implement, polish, review, PR.**

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/SysAdminDoc/improve-repo/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows--bash-lightgrey.svg)](#requirements)
[![Shell](https://img.shields.io/badge/shell-bash-89e051.svg)](improve-repo.sh)

</div>

---

Point it at a git repo. It generates a competitor-informed roadmap, implements the top-priority items on a feature branch, polishes the UX, runs a code review, and opens a pull request.

## Pipeline

Per loop:

1. **Research Pass 1** — Broad competitor scan → seeds `ROADMAP.md`
2. **Research Pass 2** — Deep dive on top competitors + popular feature requests
3. **Research Pass 3** — Internal code audit (dead code, perf, a11y, edge cases)
4. **Implement** — All P1 backlog items, one commit each
5. **UX Polish** — Bug hunt + a11y + error messages on the diff
6. **Code Review** — Structured review against the base branch
7. **Pull Request** — Opened on the final loop with a commit-by-commit summary

Multi-loop runs re-research after implementation, promote deferred items, and implement the next priority tier.

## Quickstart

```bash
git clone https://github.com/SysAdminDoc/improve-repo.git
cd improve-repo
chmod +x improve-repo.sh

# Single loop, full research
./improve-repo.sh ~/repos/my-project

# Shorthand: resolves to ~/repos/my-project
./improve-repo.sh my-project

# Two full cycles
./improve-repo.sh my-project --loops 2
```

## Usage

```
improve-repo.sh <repo-path-or-name> [OPTIONS]

OPTIONS:
  --loops N            Number of full cycles (default: 1, max: 5)
  --research-passes N  Research depth: 1=broad, 2=+deep, 3=+internal (default: 3)
  --skip-research      Reuse existing ROADMAP.md
  --skip-implement     Skip implementation
  --skip-ux            Skip UX polish pass
  --skip-audit         Skip code review
  --skip-pr            Run locally; do not push or open a PR
  --dry-run            Print planned steps without running
```

### Examples

```bash
./improve-repo.sh my-project                          # default: 1 loop, 3 passes
./improve-repo.sh my-project --loops 2                # 2 full cycles
./improve-repo.sh my-project --research-passes 1      # quick: broad scan only
./improve-repo.sh my-project --skip-research          # reuse existing ROADMAP.md
./improve-repo.sh my-project --skip-pr                # local only
```

## Requirements

The following CLIs must be on `PATH`:

| Tool    | Purpose                                 |
| ------- | --------------------------------------- |
| `claude` | Research + implementation steps        |
| `codex`  | UX polish + code review                |
| `gh`     | Branch push + pull request creation    |
| `git`    | Branching, commits, diff stats         |
| `bash`   | Runtime (Git Bash works on Windows)    |

All auth (GitHub, model providers) must be configured ahead of time for the respective CLIs.

## What it writes

Inside the target repo:

- `ROADMAP.md` — Competitor analysis, improvement backlog (P1/P2/P3), internal audit findings. Committed per research pass.
- `.ai-improve-logs/` — Per-step stdout logs (auto-added to `.gitignore`).
- Feature branch `ai-improve/<timestamp>` — All implementation and polish commits.
- Pull request on the final loop — Commit-by-commit summary + checklist.

Uncommitted tracked changes are auto-stashed before the pipeline runs. A reminder is printed at the end to `git stash pop` when done.

## Safety

- Never force-pushes. Never amends published commits.
- Runs on an isolated `ai-improve/<timestamp>` branch — the base branch is untouched until you merge.
- `--dry-run` prints the full plan without invoking any AI tool.
- `--skip-pr` keeps everything local for inspection.

## Output

Each step reports its wall-clock time and a short result line. Final summary:

```
╔══════════════════════════════════════════════════════╗
║        Pipeline Summary: my-project
╚══════════════════════════════════════════════════════╝

  Step                 Time         Result
  -------------------- ------------ ----------------------------
  Research P1          2m 14s       P1:8 P2:12 P3:5
  Research P2          3m 02s       P1:11 P2:15 P3:7
  Research P3          1m 48s       P1:14 P2:18 P3:9
  Implement            9m 21s       6 commits (P1), 12 files changed
  UX Polish            3m 40s       3 commits by Codex
  Audit + PR           1m 55s       4 findings

  Total:   9 commits | 14 files changed, 412 insertions(+), 87 deletions(-)
  Loops:   1 (3 research passes each)
  Time:    22m 00s
  Branch:  ai-improve/20260419-034923
  Logs:    /path/to/repo/.ai-improve-logs/
```

## License

MIT — see [LICENSE](LICENSE).
