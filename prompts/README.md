# Prompt templates

Each `.md` file is the prompt sent to `claude` or `codex` for a specific phase of the pipeline. The script looks for them here first; if a file is missing it falls back to the embedded default baked into `improve-repo.sh`.

| File                   | Phase                       | Tool    |
| ---------------------- | --------------------------- | ------- |
| `research-pass-1.md`   | Broad competitor scan       | claude  |
| `research-pass-2.md`   | Deep dive on top competitors | claude |
| `research-pass-3.md`   | Internal code audit         | claude  |
| `implement.md`         | Implement roadmap items     | claude  |
| `ux-polish.md`         | UX + bug pass               | codex   |

## Overriding

```bash
# Use a different prompt directory for this repo
./improve-repo.sh my-project --prompts-dir ~/my-prompts/

# Or set the env var (persists across invocations)
export IMPROVE_REPO_PROMPTS_DIR=~/my-prompts/
./improve-repo.sh my-project
```

Edit freely — these files are the source of truth when present. Delete a file to fall back to the embedded default.
