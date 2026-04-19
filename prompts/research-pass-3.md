ROADMAP.md has competitor research from Pass 1 and Pass 2. Now turn INWARD and audit THIS codebase:

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

Write the updated ROADMAP.md. No other files.
