# ROADMAP.md schema

The pipeline reads and writes `ROADMAP.md` in the target repo. This document defines the contract so the file can be parsed programmatically without surprises, and so external tooling can generate compatible roadmaps.

## Required structure

```markdown
# ROADMAP

(free-form prose intro, optional)

## Improvement Backlog

| Priority | Title | Description | Source |
| -------- | ----- | ----------- | ------ |
| P1   | Title goes here | One-line description. | competitor-name or internal |
| P2   | ...             | ...                   | ...                         |
| P3   | ...             | ...                   | ...                         |
| DONE | Already shipped | ...                   | ...                         |

(other sections like ## Competitor Analysis, ## Internal Audit, ## Done may follow)
```

## Priority column

Must contain **exactly one** of:

- `P1` — ship within a single session (< 1 hour estimate)
- `P2` — user-expected feature (1–4 hours)
- `P3` — polish / nice-to-have
- `DONE` — shipped in a prior loop or release

The parser matches on column 2 (between the first and second pipe) after whitespace trimming. It does **not** fuzzy-match priority strings that appear elsewhere in the row (e.g. inside description text).

## Counting rule

`roadmap_counts()` reports `P1:<n> P2:<n> P3:<n>` (and `DONE:<n>` when any shipped work exists). Implementation scans each row and increments the counter whose priority cell equals the row's column-2 value.

## Updating across loops

- Research passes add rows (preserve existing).
- The implementation phase flips shipped rows to `DONE`, leaving the title and description intact for audit trail.
- The `## Done` section accumulates per-release bullets linking back to the roadmap entries that shipped.

## Minimum viable example

```markdown
# ROADMAP

## Improvement Backlog

| Priority | Title | Description | Source |
| -------- | ----- | ----------- | ------ |
| P1 | Add favicon | 16x16 PNG in the repo root | internal |
```

Anything less (no table header, no priority column, non-pipe separator) will produce `P1:0 P2:0 P3:0` and the implement phase will have nothing to do.
