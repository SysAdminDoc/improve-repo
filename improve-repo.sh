#!/usr/bin/env bash
# improve-repo.sh v3.1.0
# Multi-AI repo improvement pipeline with multi-pass research and iterative loops
# Usage: ./improve-repo.sh <repo-path> [OPTIONS]

set -euo pipefail

# Require bash 4+ (macOS default bash 3.2 lacks features used here)
if (( BASH_VERSINFO[0] < 4 )); then
    echo "[ERROR] bash 4.0+ required (found ${BASH_VERSION})." >&2
    echo "        On macOS: brew install bash && exec /opt/homebrew/bin/bash $0 \"\$@\"" >&2
    exit 1
fi

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; DIM='\033[2m'
RESET='\033[0m'

# ── Config ──────────────────────────────────────────────────────────────────
BRANCH_PREFIX="ai-improve"
# Uniqueness: seconds + PID + RANDOM. Cross-platform (GNU date's %N isn't
# portable to macOS). Two fast invocations can no longer collide.
TIMESTAMP="$(date +%Y%m%d-%H%M%S)-$$-${RANDOM}"
BRANCH_NAME="${BRANCH_PREFIX}/${TIMESTAMP}"
LOCK_DIR=""
LOG_DIR=""
REPO_PATH=""
REPO_NAME=""
BASE_BRANCH=""
PIPELINE_START=""
DRY_RUN=false
SKIP_RESEARCH=false
SKIP_IMPLEMENT=false
SKIP_UX=false
SKIP_AUDIT=false
SKIP_PR=false
STASHED=false
LOOPS=1           # Number of full improve cycles
RESEARCH_PASSES=3 # Research passes per loop (broad, deep, internal)
AI_TIMEOUT="45m"  # Per-call wall-clock ceiling for claude/codex invocations
BASE_BRANCH_OVERRIDE="" # Optional --base-branch value
REMOTE_NAME=""    # Optional --remote value (auto-detected if empty)

# Step tracking for summary
STEP_RESULTS=()
STEP_COUNTER=0
TOTAL_STEPS=0
LOG_KEEP=10       # Retain the last N prior runs' logs; older get pruned
CLEANUP_MODE=false # --cleanup: tear down orphaned run state instead of running the pipeline

# Model overrides (empty = let the CLI pick its default)
RESEARCH_MODEL=""
IMPLEMENT_MODEL=""
REVIEW_MODEL=""

# Directory of prompt templates. External files override embedded defaults.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${IMPROVE_REPO_PROMPTS_DIR:-$SCRIPT_DIR/prompts}"

# Exit handling state
PIPELINE_CLEAN_EXIT=false

# ── Helpers ─────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[DONE]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

step() {
    STEP_COUNTER=$(( STEP_COUNTER + 1 ))
    local step_start
    step_start=$(date +%s)
    echo -e "\n${MAGENTA}${BOLD}=== STEP ${STEP_COUNTER}/${TOTAL_STEPS}: $1 ===${RESET}"
    echo -e "${DIM}    Started $(date '+%H:%M:%S')${RESET}\n"
    export _STEP_START="$step_start"
}

step_done() {
    local elapsed=$(( $(date +%s) - ${_STEP_START:-$(date +%s)} ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))
    local time_str="${mins}m ${secs}s"
    STEP_RESULTS+=("$1|$2|${time_str}")
    success "$1 ($time_str)"
}

elapsed_since() {
    local elapsed=$(( $(date +%s) - $1 ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))
    echo "${mins}m ${secs}s"
}

# Invoked via trap on EXIT/INT/TERM. Releases the lock, then — only on abort —
# prints the recovery hint the user would otherwise have to piece together.
cleanup_on_exit() {
    local rc=$?
    [[ -n "$LOCK_DIR" && -d "$LOCK_DIR" ]] && rm -rf "$LOCK_DIR"

    if ! $PIPELINE_CLEAN_EXIT; then
        echo "" >&2
        warn "Pipeline aborted (exit $rc). Recovery hints:"
        if [[ -n "$BRANCH_NAME" && -n "$REPO_PATH" ]] && \
           git -C "$REPO_PATH" rev-parse --verify "$BRANCH_NAME" &>/dev/null; then
            echo "    Branch:     $BRANCH_NAME (inspect with: git -C '$REPO_PATH' log $BRANCH_NAME)" >&2
            echo "    Drop it:    git -C '$REPO_PATH' branch -D '$BRANCH_NAME'" >&2
        fi
        if $STASHED; then
            echo "    Stash:      git -C '$REPO_PATH' stash pop" >&2
        fi
        if [[ -n "$LOG_DIR" && -d "$LOG_DIR" ]]; then
            echo "    Logs:       $LOG_DIR/" >&2
        fi
    fi
}

# Prune older per-run log files, keeping the most recent $LOG_KEEP runs.
# Uses ls -t (portable across GNU + BSD) rather than find -printf (GNU-only).
rotate_logs() {
    [[ -d "$LOG_DIR" ]] || return 0
    local -a files old
    mapfile -t files < <(ls -1t "$LOG_DIR"/*.log 2>/dev/null || true)
    if (( ${#files[@]} > LOG_KEEP )); then
        old=("${files[@]:$LOG_KEEP}")
        rm -f "${old[@]}"
        info "Rotated ${#old[@]} old log file(s) (kept newest $LOG_KEEP)"
    fi
}

# Fire a best-effort OS notification when the pipeline finishes. Falls back
# through platform-specific channels, ending at a terminal bell.
notify_complete() {
    local title="improve-repo"
    local msg="${1:-pipeline complete}"
    case "$OSTYPE" in
        linux*)
            command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$msg" 2>/dev/null || true
            ;;
        darwin*)
            command -v osascript >/dev/null 2>&1 && \
                osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
            ;;
        msys*|cygwin*|win32)
            # Git Bash on Windows — PowerShell toast via BurntToast isn't
            # guaranteed, so just play the system exclamation sound.
            command -v powershell.exe >/dev/null 2>&1 && \
                powershell.exe -NoProfile -Command "[System.Media.SystemSounds]::Exclamation.Play()" 2>/dev/null || true
            ;;
    esac
    # Terminal bell as universal fallback — costs nothing, never fails.
    printf '\a' >&2
}

# Persist the human-readable summary to disk so closed terminals don't lose it.
write_summary_file() {
    local summary_file="$LOG_DIR/summary-${TIMESTAMP}.md"
    local total_commits stats total_elapsed
    total_commits=$(commit_count)
    stats=$(diff_stats)
    total_elapsed=$(elapsed_since "$PIPELINE_START")

    {
        echo "# improve-repo summary — ${REPO_NAME}"
        echo ""
        echo "- **Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo "- **Branch:** \`${BRANCH_NAME}\`"
        echo "- **Base:** \`${BASE_BRANCH}\`"
        echo "- **Loops:** ${LOOPS} (${RESEARCH_PASSES} research passes each)"
        echo "- **Time:** ${total_elapsed}"
        echo "- **Commits:** ${total_commits} | ${stats}"
        [[ -f "$REPO_PATH/ROADMAP.md" ]] && echo "- **Roadmap:** $(roadmap_counts)"
        echo ""
        echo "## Steps"
        echo ""
        echo "| Step | Time | Result |"
        echo "| ---- | ---- | ------ |"
        for result in "${STEP_RESULTS[@]}"; do
            local step_name detail time_str
            step_name=$(echo "$result" | cut -d'|' -f1)
            detail=$(echo "$result"  | cut -d'|' -f2)
            time_str=$(echo "$result" | cut -d'|' -f3)
            echo "| $step_name | $time_str | $detail |"
        done
    } > "$summary_file"

    info "Summary written: $summary_file"
}

# --cleanup: tear down leftover state from an aborted run (lock, branch, stash,
# logs). Inverse of the pipeline; safe to invoke on a clean repo (no-op).
do_cleanup() {
    local current_branch stash_count
    info "Cleanup mode for: $REPO_NAME ($REPO_PATH)"

    # 1. Remove stale lock directory
    if [[ -d "$LOG_DIR/.lock" ]]; then
        rm -rf "$LOG_DIR/.lock"
        success "Removed stale lock directory"
    fi

    # 2. Delete all ai-improve/* feature branches (user must have merged or
    #    abandoned them — we don't guess).
    current_branch=$(git -C "$REPO_PATH" branch --show-current 2>/dev/null || echo "")
    if [[ "$current_branch" == ai-improve/* ]]; then
        warn "Currently on $current_branch — switch off it first:"
        warn "  git -C '$REPO_PATH' checkout $BASE_BRANCH"
        return 1
    fi
    local -a branches
    mapfile -t branches < <(git -C "$REPO_PATH" branch --list 'ai-improve/*' | sed 's/^[ *]*//')
    if (( ${#branches[@]} > 0 )); then
        for b in "${branches[@]}"; do
            git -C "$REPO_PATH" branch -D "$b" 2>&1 | head -1
        done
        success "Deleted ${#branches[@]} ai-improve/* branch(es)"
    else
        info "No ai-improve/* branches to delete"
    fi

    # 3. Surface (but don't silently pop) any leftover auto-stash
    stash_count=$(git -C "$REPO_PATH" stash list | grep -c 'ai-improve: auto-stash' || true)
    if (( stash_count > 0 )); then
        warn "$stash_count auto-stash entry/entries remain. Inspect with:"
        warn "  git -C '$REPO_PATH' stash list"
        warn "Restore manually with: git -C '$REPO_PATH' stash pop"
    fi

    # 4. Prune logs down to --keep-logs N (default 10)
    rotate_logs

    success "Cleanup complete"
}

detect_base_branch() {
    if [[ -n "$BASE_BRANCH_OVERRIDE" ]]; then
        if ! git -C "$REPO_PATH" rev-parse --verify "refs/heads/${BASE_BRANCH_OVERRIDE}" &>/dev/null; then
            error "--base-branch '${BASE_BRANCH_OVERRIDE}' does not exist in the repo"
            exit 1
        fi
        BASE_BRANCH="$BASE_BRANCH_OVERRIDE"
        return
    fi
    if git -C "$REPO_PATH" rev-parse --verify refs/heads/main &>/dev/null; then
        BASE_BRANCH="main"
    elif git -C "$REPO_PATH" rev-parse --verify refs/heads/master &>/dev/null; then
        BASE_BRANCH="master"
    else
        BASE_BRANCH=$(git -C "$REPO_PATH" branch --show-current 2>/dev/null || echo "main")
    fi
}

detect_remote() {
    if [[ -n "$REMOTE_NAME" ]]; then
        if ! git -C "$REPO_PATH" remote get-url "$REMOTE_NAME" &>/dev/null; then
            error "--remote '$REMOTE_NAME' is not configured in the repo"
            exit 1
        fi
        return
    fi
    # Prefer origin, then first remote, else empty (PR step will error clearly)
    if git -C "$REPO_PATH" remote get-url origin &>/dev/null; then
        REMOTE_NAME="origin"
    else
        REMOTE_NAME=$(git -C "$REPO_PATH" remote | head -n1)
    fi
}

commit_count() {
    git -C "$REPO_PATH" rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "0"
}

diff_stats() {
    git -C "$REPO_PATH" diff --shortstat "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "no changes"
}

roadmap_counts() {
    local p1 p2 p3
    p1=$(grep -c '| P1 ' "$REPO_PATH/ROADMAP.md" 2>/dev/null | tr -d '[:space:]')
    p2=$(grep -c '| P2 ' "$REPO_PATH/ROADMAP.md" 2>/dev/null | tr -d '[:space:]')
    p3=$(grep -c '| P3 ' "$REPO_PATH/ROADMAP.md" 2>/dev/null | tr -d '[:space:]')
    echo "P1:${p1:-0} P2:${p2:-0} P3:${p3:-0}"
}

# Auto-commit ROADMAP.md if dirty
auto_commit_roadmap() {
    local msg="${1:-Update ROADMAP.md}"
    local roadmap_dirty
    roadmap_dirty=$(git -C "$REPO_PATH" status --porcelain ROADMAP.md 2>/dev/null || true)
    if [[ -n "$roadmap_dirty" ]]; then
        git -C "$REPO_PATH" add ROADMAP.md
        git -C "$REPO_PATH" commit -m "$msg"
        info "ROADMAP.md auto-committed"
    fi
}

# Run claude with standard options. Exits non-zero if claude itself fails —
# `tee` alone would mask the tool's exit code, so we use pipefail and inspect
# PIPESTATUS[0] inside the subshell. Optional 4th arg selects a model.
run_claude() {
    local prompt="$1"
    local tools="${2:-Read Glob Grep Write Edit}"
    local log_file="$3"
    local model="${4:-}"
    local -a model_args=()
    [[ -n "$model" ]] && model_args=(--model "$model")

    (
        set -o pipefail
        cd "$REPO_PATH"
        timeout --foreground "$AI_TIMEOUT" claude -p "$prompt" \
            --allowedTools "$tools" \
            --permission-mode default \
            "${model_args[@]}" \
            </dev/null \
            2>&1 | tee "$log_file"
        local rc=${PIPESTATUS[0]}
        if (( rc == 124 )); then
            error "claude timed out after $AI_TIMEOUT"
        elif (( rc != 0 )); then
            error "claude exited with code $rc"
        fi
        return "$rc"
    )
}

# Run codex exec with write access. Optional 3rd arg selects a model.
run_codex_exec() {
    local prompt="$1"
    local log_file="$2"
    local model="${3:-}"
    local -a model_args=()
    [[ -n "$model" ]] && model_args=(-m "$model")

    (
        set -o pipefail
        cd "$REPO_PATH"
        timeout --foreground "$AI_TIMEOUT" codex exec \
            -c 'sandbox_permissions=["disk-full-read-access","disk-write-access"]' \
            -c 'approval_policy="auto-edit"' \
            "${model_args[@]}" \
            "$prompt" \
            </dev/null \
            2>&1 | tee "$log_file"
        local rc=${PIPESTATUS[0]}
        if (( rc == 124 )); then
            error "codex timed out after $AI_TIMEOUT"
        elif (( rc != 0 )); then
            error "codex exited with code $rc"
        fi
        return "$rc"
    )
}

# Load a prompt template by name. External file in $PROMPTS_DIR wins over the
# embedded default. External prompts can use {{TOKEN}} placeholders (expanded
# via envsubst-style sed) for loop-aware content.
load_prompt() {
    local name="$1"
    local external="$PROMPTS_DIR/${name}.md"
    if [[ -f "$external" ]]; then
        cat "$external"
        return 0
    fi
    # Fall back to the function-scoped default embedded at the call site.
    return 1
}

usage() {
    cat <<'EOF'
improve-repo.sh v3.1.0 - Multi-AI repo improvement pipeline

USAGE:
    ./improve-repo.sh <repo-path> [OPTIONS]
    ./improve-repo.sh <repo-name> [OPTIONS]     # shorthand for ~/repos/<name>

OPTIONS:
    --loops N           Number of full improve cycles (default: 1, max: 5)
    --research-passes N Research depth per loop: 1=broad, 2=+deep, 3=+internal (default: 3)
    --timeout DURATION  Per-call ceiling for claude/codex (default: 45m; e.g. 2h, 90m)
    --base-branch NAME  Override auto-detected base branch (default: main or master)
    --remote NAME       Override push remote (default: auto-detect, prefers origin)
    --keep-logs N       Retain the last N prior runs' logs (default: 10)
    --cleanup           Tear down orphaned run state (lock, branches, logs) and exit
    --research-model M  Override claude model for research phases
    --implement-model M Override claude model for implementation phase
    --review-model M    Override codex model for UX polish + audit
    --prompts-dir DIR   Use custom prompt templates (default: $SCRIPT_DIR/prompts)
    --skip-research     Skip all research passes (use existing ROADMAP.md)
    --skip-implement    Skip implementation
    --skip-ux           Skip Codex UX pass
    --skip-audit        Skip Codex code review
    --skip-pr           Run everything locally, don't push or create PR
    --dry-run           Show what would happen without executing AI tools

PIPELINE (per loop):
    Research Pass 1  -> Broad competitor scan, initial ROADMAP.md
    Research Pass 2  -> Deep dive on top competitors, find gaps in Pass 1
    Research Pass 3  -> Internal codebase review for UX/quality issues
    Claude Implement -> All P1 items from combined roadmap
    Codex UX Polish  -> Fix what Claude missed
    Codex Audit      -> Code review

MULTI-LOOP (--loops 2):
    Loop 1: Full pipeline above
    Loop 2: Re-research what was implemented, find new gaps, implement next batch

EXAMPLES:
    ./improve-repo.sh BetterNext                          # 1 loop, 3 research passes
    ./improve-repo.sh BetterNext --loops 2                # 2 full cycles
    ./improve-repo.sh BetterNext --research-passes 1      # quick: broad scan only
    ./improve-repo.sh BetterNext --loops 2 --skip-ux      # 2 loops, no Codex edits
    ./improve-repo.sh BetterNext --skip-research           # reuse existing ROADMAP.md

REQUIREMENTS:
    claude, codex, gh
EOF
    exit 0
}

check_tools() {
    local missing=()
    command -v claude  >/dev/null 2>&1 || missing+=("claude")
    command -v codex   >/dev/null 2>&1 || missing+=("codex")
    command -v gh      >/dev/null 2>&1 || missing+=("gh")
    command -v git     >/dev/null 2>&1 || missing+=("git")
    command -v timeout >/dev/null 2>&1 || missing+=("timeout (coreutils)")

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
        exit 1
    fi

    # Version probes — surfaces stale auth and broken installs early, before
    # the pipeline invests minutes in research only to fail at implementation.
    if ! claude --version >/dev/null 2>&1; then
        error "'claude --version' failed. Is the CLI installed and authenticated?"
        exit 1
    fi
    if ! codex --version >/dev/null 2>&1; then
        error "'codex --version' failed. Is the CLI installed and authenticated?"
        exit 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        error "'gh auth status' failed. Run: gh auth login"
        exit 1
    fi

    success "All tools available (claude, codex, gh, git, timeout)"
}

check_git_identity() {
    local email name
    email=$(git -C "$REPO_PATH" config user.email 2>/dev/null || true)
    name=$(git -C "$REPO_PATH" config user.name  2>/dev/null || true)
    if [[ -z "$email" || -z "$name" ]]; then
        error "git user.email and user.name must be set in the target repo."
        error "  git -C '$REPO_PATH' config user.email 'you@example.com'"
        error "  git -C '$REPO_PATH' config user.name  'Your Name'"
        exit 1
    fi
}

check_repo() {
    if [[ ! -d "$REPO_PATH/.git" ]]; then
        error "'$REPO_PATH' is not a git repository"
        exit 1
    fi

    REPO_NAME=$(basename "$REPO_PATH")
    LOG_DIR="$REPO_PATH/.ai-improve-logs"
    mkdir -p "$LOG_DIR"

    # Atomic mutex against concurrent invocations on the same repo. mkdir is
    # atomic on every POSIX filesystem, so this portably stands in for flock.
    LOCK_DIR="$LOG_DIR/.lock"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        error "Another improve-repo run appears to be active on '$REPO_NAME'."
        error "  Lock: $LOCK_DIR"
        error "  If you're sure no run is in progress: rm -rf '$LOCK_DIR'"
        exit 1
    fi

    check_git_identity

    # Auto-add .ai-improve-logs to .gitignore. Hooks are NOT bypassed — if a
    # pre-commit hook rejects the change, that is signal, not an obstacle.
    if [[ -f "$REPO_PATH/.gitignore" ]]; then
        if ! grep -q "^\.ai-improve-logs" "$REPO_PATH/.gitignore" 2>/dev/null; then
            echo ".ai-improve-logs/" >> "$REPO_PATH/.gitignore"
            git -C "$REPO_PATH" add .gitignore
            if git -C "$REPO_PATH" commit -m "Add .ai-improve-logs to gitignore" 2>/dev/null; then
                info "Added .ai-improve-logs/ to .gitignore"
            else
                warn "Pre-commit hook blocked the .gitignore update — investigate before rerunning."
            fi
        fi
    fi

    detect_base_branch
    detect_remote

    # Handle uncommitted changes
    local dirty
    dirty=$(git -C "$REPO_PATH" status --porcelain --untracked-files=no 2>/dev/null || true)
    if [[ -n "$dirty" ]]; then
        local dirty_trimmed dirty_count
        dirty_trimmed=$(echo "$dirty" | sed 's/^[ \t]*//' | grep -v '^$')
        dirty_count=$(echo "$dirty_trimmed" | wc -l)

        if echo "$dirty_trimmed" | grep -q "ROADMAP.md" && [[ "$dirty_count" -eq 1 ]]; then
            auto_commit_roadmap "Update ROADMAP.md (from prior session)"
        else
            warn "Uncommitted tracked changes detected -- stashing..."
            git -C "$REPO_PATH" stash push -m "ai-improve: auto-stash before pipeline"
            STASHED=true
        fi
    fi

    success "Repository: $REPO_NAME (base: $BASE_BRANCH)"
}

# Create (or resume) the ai-improve feature branch BEFORE research begins.
# Previously the branch was created only at implementation time, so research
# passes' ROADMAP.md auto-commits landed on the base branch — colliding with
# branch protection and polluting main's history.
prepare_feature_branch() {
    local current_branch
    current_branch=$(git -C "$REPO_PATH" branch --show-current 2>/dev/null || echo "")
    if [[ "$current_branch" == ai-improve/* ]]; then
        BRANCH_NAME="$current_branch"
        info "Resuming on branch: $BRANCH_NAME"
    else
        info "Creating branch: $BRANCH_NAME"
        git -C "$REPO_PATH" checkout -b "$BRANCH_NAME"
    fi
}

# ── Research Passes ────────────────────────────────────────────────────────
# Each pass has a distinct focus so they build on each other instead of repeating.

do_research_pass_1() {
    local loop_num="$1"
    step "RESEARCH Pass 1/${RESEARCH_PASSES} - Broad Competitor Scan (Loop ${loop_num})"

    local prompt
    if [[ "$loop_num" -eq 1 ]]; then
        prompt='You are analyzing this repository to find improvement opportunities.

1. Read README.md, CLAUDE.md, and the main config file (package.json / build.gradle.kts / Cargo.toml / setup.py / pyproject.toml) to understand what this project does.

2. Search GitHub for 5-10 comparable/competing projects. For each, note:
   - Repo name and star count
   - Key features this project is MISSING
   - UX patterns they do better

3. Generate or update ROADMAP.md with:
   - "## Competitor Analysis" — table of competitors found
   - "## Improvement Backlog" — prioritized items:
     - P1: Quick wins, clear value, < 1 hour each
     - P2: Medium features users expect, 1-4 hours
     - P3: Nice-to-haves and polish
   - Each item: priority, title, one-line description, which competitor inspired it
   - "## UX Improvements" — specific UI/UX issues found

4. Focus on PRACTICAL improvements only. Skip anything requiring external APIs, paid services, or special hardware.

Write the ROADMAP.md file. No other files. No explanation text.'
    else
        # Loop 2+: re-research after implementation
        prompt='ROADMAP.md already exists from a prior improvement cycle. Read it AND the recent git log to see what was implemented.

Now do a FRESH competitor scan:
1. Search GitHub for 5-10 comparable projects (may overlap prior research -- that is fine).
2. Focus on features that are STILL missing after the recent implementation work.
3. Look at the top-starred competitors recent releases/changelogs for ideas we missed.

Update ROADMAP.md:
- Keep the existing "## Competitor Analysis" section but ADD any new competitors found.
- In "## Improvement Backlog", mark implemented items as DONE and add NEW items discovered.
- Re-prioritize: some former P2/P3 items may now be P1 given what was built.
- Add a "## Post-Implementation Gaps" section for things the implementation exposed.

Write the updated ROADMAP.md. No other files.'
    fi

    if $DRY_RUN; then
        step_done "Research P1" "skipped (dry run)"
        return
    fi

    # External prompt override wins over embedded default
    local external
    if external=$(load_prompt "research-pass-1"); then
        prompt="$external"
    fi

    info "Claude is scanning competitors (pass 1)..."
    run_claude "$prompt" \
        "Bash(git:*) Read Glob Grep WebSearch mcp__github__search_repositories mcp__github__get_file_contents Write Edit" \
        "$LOG_DIR/research-L${loop_num}-P1-${TIMESTAMP}.log" \
        "$RESEARCH_MODEL"

    auto_commit_roadmap "ROADMAP.md: broad competitor scan (loop ${loop_num})"
    step_done "Research P1" "$(roadmap_counts)"
}

do_research_pass_2() {
    local loop_num="$1"
    step "RESEARCH Pass 2/${RESEARCH_PASSES} - Deep Dive (Loop ${loop_num})"

    local prompt
    prompt='ROADMAP.md exists with a competitor analysis from Pass 1. Now do a DEEP DIVE:

1. Read the current ROADMAP.md competitor table.
2. Pick the top 3 competitors by star count. For EACH one:
   - Read their README, feature list, and recent commits/releases on GitHub
   - Identify specific features, UI patterns, or architectural decisions we should adopt
   - Note their documentation style, onboarding flow, and configuration approach
3. Search GitHub Issues on those repos for popular feature requests (sorted by thumbs-up) -- these represent unmet user needs we could capture.

Update ROADMAP.md:
- Add a "## Deep Dive: [Competitor]" section for each of the top 3
- Add NEW backlog items discovered from this deep analysis (avoid duplicates with Pass 1)
- Tag new items with the specific competitor and feature that inspired them

Write the updated ROADMAP.md. No other files.'

    if $DRY_RUN; then
        step_done "Research P2" "skipped (dry run)"
        return
    fi

    local external
    if external=$(load_prompt "research-pass-2"); then
        prompt="$external"
    fi

    info "Claude is doing deep competitor analysis (pass 2)..."
    run_claude "$prompt" \
        "Bash(git:*) Read Glob Grep WebSearch mcp__github__search_repositories mcp__github__get_file_contents mcp__github__list_issues Write Edit" \
        "$LOG_DIR/research-L${loop_num}-P2-${TIMESTAMP}.log" \
        "$RESEARCH_MODEL"

    auto_commit_roadmap "ROADMAP.md: deep competitor dive (loop ${loop_num})"
    step_done "Research P2" "$(roadmap_counts)"
}

do_research_pass_3() {
    local loop_num="$1"
    step "RESEARCH Pass 3/${RESEARCH_PASSES} - Internal Code Review (Loop ${loop_num})"

    local prompt
    prompt='ROADMAP.md has competitor research from Pass 1 and Pass 2. Now turn INWARD and audit THIS codebase:

1. Read the project main source files, templates, and config.
2. Look for INTERNAL improvement opportunities that competitors would not reveal:
   - Dead code, unused imports, redundant functions
   - Inconsistent error handling patterns
   - Missing input validation or edge cases
   - Performance bottlenecks (N+1 queries, unbounded loops, missing indexes)
   - Accessibility gaps (missing aria labels, keyboard traps, contrast issues)
   - Missing empty states, loading indicators, or error feedback
   - Configuration that should have defaults but does not
   - Code that is duplicated across files and should be extracted

3. Update ROADMAP.md:
   - Add a "## Internal Audit" section with findings grouped by category
   - Add P1/P2/P3 items to the backlog for each actionable finding
   - Tag these items as "internal" (no competitor reference needed)

Write the updated ROADMAP.md. No other files.'

    if $DRY_RUN; then
        step_done "Research P3" "skipped (dry run)"
        return
    fi

    local external
    if external=$(load_prompt "research-pass-3"); then
        prompt="$external"
    fi

    info "Claude is auditing internal code quality (pass 3)..."
    run_claude "$prompt" \
        "Bash(git:*) Read Glob Grep Write Edit" \
        "$LOG_DIR/research-L${loop_num}-P3-${TIMESTAMP}.log" \
        "$RESEARCH_MODEL"

    auto_commit_roadmap "ROADMAP.md: internal code audit (loop ${loop_num})"
    step_done "Research P3" "$(roadmap_counts)"
}

# ── Implement ──────────────────────────────────────────────────────────────
do_implement() {
    local loop_num="$1"
    local priority="${2:-P1}"
    step "IMPLEMENT ${priority} items (Loop ${loop_num}, Claude)"

    if [[ ! -f "$REPO_PATH/ROADMAP.md" ]]; then
        error "No ROADMAP.md found."
        step_done "Implement" "skipped (no ROADMAP.md)"
        return 1
    fi

    # Branch is prepared up-front in main(); just confirm.
    info "On branch: $BRANCH_NAME"

    local commits_before
    commits_before=$(commit_count)

    local prompt
    prompt="Read ROADMAP.md in this repository. Implement ALL ${priority} items from the \"## Improvement Backlog\" section that are NOT already marked as DONE.

Rules:
- Implement each item as a separate commit with a clear message
- Do NOT modify ROADMAP.md itself
- Do NOT add tests unless the item specifically requires it
- Do NOT add features beyond what's listed
- Maintain existing code style and conventions
- If a CLAUDE.md exists, follow its instructions
- After implementing, output a brief summary of what was done

If there are no ${priority} items (or all are DONE), implement the top 3 items from the next priority level."

    if $DRY_RUN; then
        step_done "Implement" "skipped (dry run)"
        return
    fi

    local external
    if external=$(load_prompt "implement"); then
        prompt="$external"
    fi

    info "Claude is implementing ${priority} roadmap items..."
    run_claude "$prompt" \
        "Bash(git:*) Bash(npm:*) Bash(npx:*) Bash(pnpm:*) Bash(cargo:*) Bash(python:*) Bash(pip:*) Bash(gradle:*) Read Glob Grep Write Edit" \
        "$LOG_DIR/implement-L${loop_num}-${priority}-${TIMESTAMP}.log" \
        "$IMPLEMENT_MODEL"

    local commits_after new_commits stats
    commits_after=$(commit_count)
    new_commits=$(( commits_after - commits_before ))
    stats=$(diff_stats)
    step_done "Implement" "${new_commits} commits (${priority}), ${stats}"
}

# ── UX Polish (Codex) ─────────────────────────────────────────────────────
do_ux() {
    local loop_num="$1"
    step "UX POLISH (Loop ${loop_num}, Codex)"

    local changed_files
    changed_files=$(git -C "$REPO_PATH" diff --name-only "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "")

    if [[ -z "$changed_files" ]]; then
        warn "No changed files. Skipping UX pass."
        step_done "UX Polish" "skipped (no changes)"
        return
    fi

    local file_count
    file_count=$(echo "$changed_files" | wc -l)

    local prompt="Review the recent changes on this branch and improve UX/DX. Focus on:

1. Runtime bugs — const reassignment, wrong variable names, missing null checks
2. Better error messages — actionable, not cryptic
3. Loading states and user feedback
4. Accessibility — aria labels, keyboard navigation, contrast
5. Broken action handlers — buttons/events wired to non-existent functions
6. Edge cases — escape key behavior, empty arrays, NaN guards

Changed files:
$changed_files

Make direct edits. Commit each fix separately. Do NOT add new features."

    if $DRY_RUN; then
        step_done "UX Polish" "skipped (dry run)"
        return
    fi

    local commits_before commits_after new_commits
    commits_before=$(commit_count)

    local external
    if external=$(load_prompt "ux-polish"); then
        prompt="$external"
    fi

    info "Codex is polishing UX on ${file_count} files..."
    run_codex_exec "$prompt" "$LOG_DIR/ux-L${loop_num}-${TIMESTAMP}.log" "$REVIEW_MODEL"

    commits_after=$(commit_count)
    new_commits=$(( commits_after - commits_before ))

    if [[ $new_commits -gt 0 ]]; then
        step_done "UX Polish" "${new_commits} commits by Codex"
    else
        step_done "UX Polish" "review-only (check log)"
    fi
}

# ── Audit (Codex Review) ──────────────────────────────────────────────────
do_audit() {
    local loop_num="$1"
    local is_final="${2:-false}"
    step "CODE REVIEW (Loop ${loop_num}, Codex)"

    if $DRY_RUN; then
        step_done "Audit" "skipped (dry run)"
        return
    fi

    local log_file="$LOG_DIR/audit-L${loop_num}-${TIMESTAMP}.log"

    info "Codex is reviewing all changes against ${BASE_BRANCH}..."
    local -a review_model_args=()
    [[ -n "$REVIEW_MODEL" ]] && review_model_args=(-m "$REVIEW_MODEL")
    (
        set -o pipefail
        cd "$REPO_PATH"
        timeout --foreground "$AI_TIMEOUT" codex review --base "$BASE_BRANCH" \
            "${review_model_args[@]}" \
            </dev/null \
            2>&1 | tee "$log_file"
        local rc=${PIPESTATUS[0]}
        if (( rc == 124 )); then
            error "codex review timed out after $AI_TIMEOUT"
        elif (( rc != 0 )); then
            warn  "codex review exited with code $rc (continuing to PR step)"
        fi
    )

    local findings
    findings=$(grep -c '^\- \[P[0-9]\]' "$log_file" 2>/dev/null || echo "0")
    info "Codex found ${findings} review items"

    # Only create PR on the final loop
    if [[ "$is_final" == "true" ]] && ! $SKIP_PR; then
        _create_pr "$findings"
        step_done "Audit + PR" "${findings} findings"
    else
        step_done "Audit" "${findings} findings"
    fi
}

# ── PR Creation ────────────────────────────────────────────────────────────
_create_pr() {
    local findings="$1"

    if [[ -z "$REMOTE_NAME" ]]; then
        error "No git remote configured. Add one (git remote add origin <url>) or pass --remote."
        return 1
    fi
    info "Pushing branch $BRANCH_NAME to $REMOTE_NAME..."
    git -C "$REPO_PATH" push -u "$REMOTE_NAME" "$BRANCH_NAME" 2>&1

    local commit_log total_commits stats
    commit_log=$(git -C "$REPO_PATH" log --oneline "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "no commits")
    total_commits=$(commit_count)
    stats=$(diff_stats)

    local loop_desc=""
    if [[ $LOOPS -gt 1 ]]; then
        loop_desc=" (${LOOPS} loops, ${RESEARCH_PASSES} research passes each)"
    fi

    # Compose PR body. If the target repo defines a template, prepend it so
    # its checklist items survive; the pipeline summary follows.
    local pr_body pr_template="$REPO_PATH/.github/PULL_REQUEST_TEMPLATE.md"
    local pipeline_body
    pipeline_body=$(cat <<EOF
## Multi-AI Improvement Pipeline${loop_desc}

**${total_commits} commits** | ${stats}

### Pipeline
- ${RESEARCH_PASSES}-pass research (broad scan + deep dive + internal audit)
- Implemented roadmap items
- UX polish pass
- Code review (${findings} findings)

### Commits
\`\`\`
${commit_log}
\`\`\`

### Checklist
- [ ] Review ROADMAP.md competitor analysis
- [ ] Verify each commit independently
- [ ] Test the changes locally
- [ ] Merge or cherry-pick individual commits
EOF
)
    if [[ -f "$pr_template" ]]; then
        pr_body="$(cat "$pr_template")"$'\n\n---\n\n'"$pipeline_body"
        info "Using repo PR template: $pr_template"
    else
        pr_body="$pipeline_body"
    fi

    info "Creating pull request..."
    local pr_url
    pr_url=$(
        cd "$REPO_PATH"
        gh pr create \
            --title "AI Improvement: ${REPO_NAME} $(date +%Y-%m-%d)" \
            --body "$pr_body" \
            --base "$BASE_BRANCH" 2>&1
    )

    if [[ -n "$pr_url" && "$pr_url" == *"github.com"* ]]; then
        success "PR created: $pr_url"
    else
        warn "PR creation may have failed. Output: $pr_url"
    fi
}

# ── Run One Loop ───────────────────────────────────────────────────────────
run_loop() {
    local loop_num="$1"
    local is_last_loop="$2"

    echo ""
    echo -e "${CYAN}${BOLD}  ┌────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}${BOLD}  │          LOOP ${loop_num} of ${LOOPS}                    │${RESET}"
    echo -e "${CYAN}${BOLD}  └────────────────────────────────────────┘${RESET}"
    echo ""

    # ── Research (multi-pass) ──
    if ! $SKIP_RESEARCH; then
        do_research_pass_1 "$loop_num"
        [[ $RESEARCH_PASSES -ge 2 ]] && do_research_pass_2 "$loop_num"
        [[ $RESEARCH_PASSES -ge 3 ]] && do_research_pass_3 "$loop_num"
    fi

    # ── Implement ──
    if ! $SKIP_IMPLEMENT; then
        if [[ "$loop_num" -eq 1 ]]; then
            do_implement "$loop_num" "P1"
        else
            # Later loops: implement P2 items (P1s should be done from loop 1)
            do_implement "$loop_num" "P2"
        fi
    fi

    # ── UX Polish ──
    $SKIP_UX || do_ux "$loop_num"

    # ── Audit ──
    if ! $SKIP_AUDIT; then
        do_audit "$loop_num" "$is_last_loop"
    fi
}

# ── Summary Report ──────────────────────────────────────────────────────────
print_summary() {
    local total_elapsed
    total_elapsed=$(elapsed_since "$PIPELINE_START")

    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║        Pipeline Summary: ${REPO_NAME}${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""

    printf "  ${BOLD}%-20s %-12s %s${RESET}\n" "Step" "Time" "Result"
    printf "  %-20s %-12s %s\n" "--------------------" "------------" "----------------------------"
    for result in "${STEP_RESULTS[@]}"; do
        local step_name detail time_str
        step_name=$(echo "$result" | cut -d'|' -f1)
        detail=$(echo "$result" | cut -d'|' -f2)
        time_str=$(echo "$result" | cut -d'|' -f3)
        printf "  ${GREEN}%-20s${RESET} ${DIM}%-12s${RESET} %s\n" "$step_name" "$time_str" "$detail"
    done
    echo ""

    local total_commits stats
    total_commits=$(commit_count)
    stats=$(diff_stats)
    echo -e "  ${BOLD}Total:${RESET}   ${total_commits} commits | ${stats}"
    echo -e "  ${BOLD}Loops:${RESET}   ${LOOPS} (${RESEARCH_PASSES} research passes each)"
    echo -e "  ${BOLD}Time:${RESET}    ${total_elapsed}"
    echo -e "  ${BOLD}Branch:${RESET}  ${BRANCH_NAME}"
    echo -e "  ${BOLD}Logs:${RESET}    ${LOG_DIR}/"

    if [[ -f "$REPO_PATH/ROADMAP.md" ]]; then
        echo -e "  ${BOLD}Roadmap:${RESET} $(roadmap_counts)"
    fi

    if $STASHED; then
        echo ""
        warn "You have stashed changes. Run: git -C '$REPO_PATH' stash pop"
    fi
    echo ""
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║   Multi-AI Repo Improvement Pipeline v3.1        ║"
    echo "  ║   Claude x3 Research -> Implement -> Codex Loop  ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
    fi

    # Support shorthand: repo name -> ~/repos/<name>
    local input_path="$1"
    if [[ ! "$input_path" == /* ]] && [[ ! "$input_path" == ~/* ]] && [[ ! "$input_path" == ./* ]] && [[ ! -d "$input_path" ]]; then
        if [[ -d "$HOME/repos/$input_path" ]]; then
            input_path="$HOME/repos/$input_path"
            info "Resolved shorthand to: $input_path"
        fi
    fi

    REPO_PATH="$(cd "$input_path" && pwd)"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --loops)          LOOPS="${2:?--loops requires a number}"; shift ;;
            --research-passes) RESEARCH_PASSES="${2:?--research-passes requires a number}"; shift ;;
            --timeout)        AI_TIMEOUT="${2:?--timeout requires a duration (e.g. 45m, 2h)}"; shift ;;
            --base-branch)    BASE_BRANCH_OVERRIDE="${2:?--base-branch requires a branch name}"; shift ;;
            --remote)         REMOTE_NAME="${2:?--remote requires a remote name}"; shift ;;
            --keep-logs)      LOG_KEEP="${2:?--keep-logs requires a count}"; shift ;;
            --cleanup)        CLEANUP_MODE=true ;;
            --research-model) RESEARCH_MODEL="${2:?--research-model requires a model name}"; shift ;;
            --implement-model) IMPLEMENT_MODEL="${2:?--implement-model requires a model name}"; shift ;;
            --review-model)   REVIEW_MODEL="${2:?--review-model requires a model name}"; shift ;;
            --prompts-dir)    PROMPTS_DIR="${2:?--prompts-dir requires a path}"; shift ;;
            --skip-research)  SKIP_RESEARCH=true ;;
            --skip-implement) SKIP_IMPLEMENT=true ;;
            --skip-ux)        SKIP_UX=true ;;
            --skip-audit)     SKIP_AUDIT=true ;;
            --skip-pr)        SKIP_PR=true ;;
            --dry-run)        DRY_RUN=true; warn "DRY RUN MODE" ;;
            *) error "Unknown option: $1"; usage ;;
        esac
        shift
    done

    # Validate
    if [[ $LOOPS -lt 1 || $LOOPS -gt 5 ]]; then
        error "--loops must be 1-5"
        exit 1
    fi
    if [[ $RESEARCH_PASSES -lt 1 || $RESEARCH_PASSES -gt 3 ]]; then
        error "--research-passes must be 1-3"
        exit 1
    fi

    # Calculate total steps for progress display
    local steps_per_loop=0
    $SKIP_RESEARCH  || steps_per_loop=$(( steps_per_loop + RESEARCH_PASSES ))
    $SKIP_IMPLEMENT || steps_per_loop=$(( steps_per_loop + 1 ))
    $SKIP_UX        || steps_per_loop=$(( steps_per_loop + 1 ))
    $SKIP_AUDIT     || steps_per_loop=$(( steps_per_loop + 1 ))
    TOTAL_STEPS=$(( steps_per_loop * LOOPS ))

    PIPELINE_START=$(date +%s)

    # Register cleanup BEFORE any state-mutating work so aborts are recoverable.
    trap cleanup_on_exit EXIT INT TERM

    check_tools
    check_repo
    rotate_logs

    # --cleanup: tear down and exit before touching the feature branch
    if $CLEANUP_MODE; then
        do_cleanup
        PIPELINE_CLEAN_EXIT=true
        return 0
    fi

    prepare_feature_branch

    info "Target:   $REPO_NAME ($REPO_PATH)"
    info "Branch:   $BRANCH_NAME"
    info "Base:     $BASE_BRANCH"
    info "Loops:    $LOOPS (${RESEARCH_PASSES} research passes each)"
    info "Steps:    $TOTAL_STEPS total"
    info "Logs:     $LOG_DIR/"
    echo ""

    # Run loops
    for (( loop=1; loop<=LOOPS; loop++ )); do
        local is_last="false"
        [[ $loop -eq $LOOPS ]] && is_last="true"
        run_loop "$loop" "$is_last"
    done

    print_summary
    write_summary_file
    notify_complete "finished in $(elapsed_since "$PIPELINE_START")"
    PIPELINE_CLEAN_EXIT=true
}

main "$@"
