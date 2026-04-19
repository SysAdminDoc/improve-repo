Stack: Python (library, CLI tool, or app).

Prioritize:
- `pyproject.toml` as the single source of truth (not mixed with `setup.py`/`setup.cfg`)
- Ruff for linting + formatting (replaces flake8, isort, black)
- mypy or pyright in strict mode; type hints throughout
- `uv` or `pipx` for install flows; `rye`/`poetry`/`hatch` for library publishing
- Async correctness: `asyncio.gather` vs sequential awaits, cancellation handling, task groups (3.11+)
- Context managers for every resource (files, sessions, locks)
- `pathlib.Path` over `os.path` string manipulation
- Structured logging with `structlog` or stdlib `logging` + formatter; no bare `print`
- `pydantic` v2 for data validation / settings; `BaseSettings` for env-driven config
- CLI: `typer` or `click` over `argparse` for non-trivial interfaces
- `pyinstaller` single-file bundling for distribution; MSI/DEB/DMG targets
- GUI apps: `PyQt6` / `PySide6` preferred; `QThread` + `pyqtSignal` for workers (no blocking the event loop)
- GitHub Actions matrix: 3.11, 3.12, 3.13 at minimum; drop 3.8/3.9/3.10 unless required
- Security: dependabot + `pip-audit` or `safety`; pin indirect deps via lockfile

Skip generic "add unit tests" suggestions; focus on the stack-shaped issues above.
