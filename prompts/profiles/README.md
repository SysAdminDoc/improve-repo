# Stack profiles

Each file provides stack-specific guidance appended to the research prompts when a matching repo type is detected.

## Detection

| Type               | Trigger file(s)                                    |
| ------------------ | -------------------------------------------------- |
| `android`          | `build.gradle.kts`, `build.gradle`                 |
| `python`           | `pyproject.toml`, `setup.py`, `requirements.txt`   |
| `rust`             | `Cargo.toml`                                       |
| `node`             | `package.json`                                     |
| `chrome-extension` | `manifest.json` containing `"manifest_version"`    |
| `userscript`       | `*.user.js` in repo root                           |
| `powershell`       | `*.ps1` in repo root                               |
| `dotnet`           | `*.csproj`, `*.sln`                                |

Multiple profiles can apply to a single repo (e.g., a Chrome extension with `package.json` loads both `chrome-extension.md` and `node.md`).

## Adding a new profile

Create `<type>.md` and add detection logic to `detect_repo_type()` in `improve-repo.sh`. Keep profiles focused on stack-specific considerations that don't generalize — generic "add tests, add CI" suggestions belong in the core prompts.

## Overriding

Edit the files in place — they're the source of truth. `--prompts-dir` / `$IMPROVE_REPO_PROMPTS_DIR` redirect to a different tree if you want to keep local overrides out of git.
