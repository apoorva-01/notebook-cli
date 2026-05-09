# notebook-cli

## Dev workflow

```bash
# Reinstall locally after editing
pipx install --force --editable /Volumes/SSD/Apoorva/My\ NPM\ Packages/notebook-cli

# Verify it works
notebook --version
```

## Project structure

- **Entry point**: `src/notebook_cli/cli.py` — `_entry()` + `main()`
- **Config**: `pyproject.toml` (hatchling build, Python 3.10+)
- **No tests** — run manually via `pipx install --force --editable` then test commands

## Key commands

- `notebook init` — bind project to a notebook (interactive)
- `notebook update .` — bundle and upload to notebook
- `notebook diff` — compare current vs last upload
- `notebook claude install` — inject NotebookLM block into CLAUDE.md
- `notebook opencode install` — inject into AGENTS.md
- `notebook codex install` — inject into .cursorrules

## Gotchas

- Requires `playwright install chromium` and `notebooklm login` before first use
- Caches bundles in `.last_bundle.md` and `.last_plan_bundle.md` (gitignore these)
- Uses `~/.notebooklm/storage_state.json` for auth (private)