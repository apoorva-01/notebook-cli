# notebook-cli

A small wrapper around [`notebooklm-py`](https://github.com/teng-lin/notebooklm-py) that turns any project on disk into a NotebookLM-backed knowledge base — with one command to upload, one to diff, one to wire it into Claude Code.

> **Why?** NotebookLM's source-grounded answers + Gemini synthesis are an excellent on-demand knowledge base for a codebase or research project. But manually curating sources every time the repo changes is friction. `notebook` automates that loop.

## What you get

```
notebook init              # interactively bind this project to a notebook
notebook update .          # bundle plan + docs + key code → upload as one source
notebook diff              # preview what'll change before uploading
notebook plan-only .       # upload plan + docs only (no code), as a separate source
notebook claude install    # tell Claude Code to use this notebook for context
notebook ask "..."         # query the notebook, auto-scoped to this project
```

Old upload is replaced on each `update`, so the notebook stays clean — no orphaned sources.

## Install

### Prerequisite: install the underlying CLI

`notebook` shells out to the `notebooklm` CLI from `notebooklm-py`. Set that up once:

```bash
# Python ≥ 3.10 required
pipx install notebooklm-py
pipx inject notebooklm-py playwright
~/.local/pipx/venvs/notebooklm-py/bin/playwright install chromium

# Authenticate with Google (opens a browser)
notebooklm login          # complete the login, press ENTER
notebooklm status         # verify
```

If `pipx` isn't installed: `brew install pipx` (macOS) or `python3 -m pip install --user pipx`.

### Install `notebook` itself

```bash
curl -fsSL https://raw.githubusercontent.com/apoorva-01/notebook-cli/main/notebook \
  -o ~/.local/bin/notebook && chmod +x ~/.local/bin/notebook
```

Make sure `~/.local/bin` is in your `PATH`. (It already is if you installed pipx via Homebrew.)

Or clone and symlink:

```bash
git clone https://github.com/apoorva-01/notebook-cli.git
ln -s "$(pwd)/notebook-cli/notebook" ~/.local/bin/notebook
```

## Quick start (per project)

```bash
cd /path/to/your/project

notebook init             # interactive: create new, pick existing, or paste URL
notebook update .         # uploads plan + docs + key code as one bundle
notebook claude install   # writes a NotebookLM context block into CLAUDE.md
```

After that, every meaningful change:

```bash
notebook diff             # preview
notebook update .         # re-upload (replaces the prior bundle in the notebook)
```

## All commands

### `notebook init [URL_OR_ID]`

Bind the **current project** to a NotebookLM notebook. Writes `.notebook.json` at the project root.

- **No argument (interactive)** — prompts for one of:
  1. **Create a new notebook** → asks for a title → creates → binds.
  2. **Pick an existing notebook** → lists your notebooks (numbered) → binds the one you pick.
  3. **Paste a URL or ID** → parses out the UUID and binds it.
- **With an argument** — skips the prompt, uses that URL/ID. Useful in scripts / CI.

If the project is already bound, you're asked to confirm a re-bind. Pass an explicit URL/ID to force it without the prompt.

```bash
notebook init                                                            # interactive
notebook init https://notebooklm.google.com/notebook/72b05864-9b4b-...   # explicit
notebook init 72b05864-9b4b-439a-ac9f-ee60c88d1e71                       # bare UUID
```

### `notebook update [PATH]`

Bundle the project at `PATH` (default: `cwd`) and upload it as a single Markdown source. Replaces any prior bundle with the same title.

**What gets bundled** (in order, deduped):

1. **Plan** — first `*.md` under `<project>/**/plans/`, else the most recent file in `~/.claude/plans/`.
2. **Top-level docs** — `README*`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `DEPLOY.md`, `ARCHITECTURE.md`, `PARITY*.md`, `PORTING*.md`, `docs/**/*.md`.
3. **Manifests** — `package.json`, `pyproject.toml`, `Cargo.toml`.
4. **Code skeleton** — `lib/**`, `src/**`, `app/**`, `components/**`, `sources/**` for `.js .ts .mjs .tsx .py`.

**Caps:** 64 KB per file (truncated with a marker), 1.5 MB total bundle.

**Skips:** `node_modules`, `.next`, `.venv`, `dist`, `build`, `.git`.

**Side effects:**
- Saves the bundle locally to `/tmp/notebook_update_<repo>.md` for inspection.
- Caches the bundle to `<project>/.last_bundle.md` so `notebook diff` works next time.
- Records `last_update_at` + `last_update_bytes` in `.notebook.json`.

```bash
notebook update .
notebook update /path/to/some/other/project
```

### `notebook plan-only [PATH]`

Like `update`, but **plan + docs only** — no code. Uploaded as a separate source titled `<repo> — Plan & Docs` so it lives alongside the full bundle.

Use when:
- Code volume drowns out strategic docs in NotebookLM's retrieval.
- You want plan-level Q&A without code citations.

Caches separately to `<project>/.last_plan_bundle.md`.

```bash
notebook plan-only .
```

### `notebook diff [--plan] [PATH]`

Unified diff between the current local bundle and the last-uploaded one. The compile-timestamp line is stripped from both sides so it doesn't show as noise.

Flags:
- `--plan` (or `-p`) — diff the plan-only bundle instead of the full one.

Output:
- No changes → `✓ No changes since last upload.` (exit 0)
- Changes → standard unified diff + summary `— X lines · + Y lines` on stderr (exit 0)
- No baseline yet → hint to run `notebook update` first (exit 1)

```bash
notebook diff
notebook diff --plan
```

### `notebook claude install`

Inject a NotebookLM context block into the project's `CLAUDE.md`. Creates the file if it doesn't exist; replaces an existing `<!-- notebook:begin -->…<!-- notebook:end -->` block in place.

The injected block tells Claude Code to:
- Query NotebookLM **first** for plan / architecture / research / progress questions.
- Treat the local repo as the source of truth for running code.
- Refresh the notebook via `notebook update .` after meaningful changes.

```bash
notebook claude install
```

### `notebook ask "QUESTION"`

Pass-through to `notebooklm ask`, auto-scoped to this project's bound notebook.

```bash
notebook ask "summarize the migration plan and current progress"
notebook ask "what trade-offs were considered for the queue layer?"
```

### Anything else

Any command not listed above is forwarded verbatim to `notebooklm`. The wrapper is additive, not a replacement.

```bash
notebook list                      # → notebooklm list
notebook source list               # → notebooklm source list
notebook create "Some new notebook"
```

## Files written by the CLI

| Path | Purpose | Commit? |
|---|---|---|
| `<project>/.notebook.json` | Notebook id + last-upload timestamps | Yes — small, useful for teammates |
| `<project>/.last_bundle.md` | Cached previous full upload (for `notebook diff`) | No |
| `<project>/.last_plan_bundle.md` | Cached previous plan-only upload | No |
| `<project>/CLAUDE.md` (block only) | Tells Claude Code to query NotebookLM | Yes |
| `~/.notebooklm/storage_state.json` | Auth session for the underlying CLI | No (private credentials) |

**Recommended `.gitignore` additions:**

```
.last_bundle.md
.last_plan_bundle.md
```

`.notebook.json` is safe to commit — it only stores the public notebook id + timestamps.

## Typical workflow loop

```bash
# After editing code/docs/plan
notebook diff                # eyeball what changed
notebook update .            # if the changes are worth re-indexing

# Or, plan-level changes only
notebook diff --plan
notebook plan-only .

# Ask the notebook anything
notebook ask "what was the rationale for picking BullMQ over a custom queue?"
```

## Multi-project use

`.notebook.json` is per-project. The wrapper auto-detects the binding by walking up from `cwd` until it finds `.notebook.json` (up to 20 levels). Run `notebook init` again to rebind.

For parallel agents or CI, the underlying CLI also supports `NOTEBOOKLM_PROFILE` and `NOTEBOOKLM_HOME` env vars — see [`notebooklm-py` docs](https://github.com/teng-lin/notebooklm-py#cicd-multiple-accounts-and-parallel-agents).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `error: no notebook bound to this project` | `notebook init` in the project root |
| `Aborted!` on `notebooklm login` | Login script prompts for Enter — must run in an interactive terminal, not a background job |
| `Playwright not installed` | `pipx inject notebooklm-py playwright && ~/.local/pipx/venvs/notebooklm-py/bin/playwright install chromium` |
| Notebook chat says "drop sources here" | The notebook has zero sources — `notebook update .` to upload one |
| Want to start over | `rm <project>/.notebook.json <project>/.last_*_bundle.md` and re-run `notebook init` |
| `error: interactive init requires a terminal` | `notebook init` was run without a TTY — pass an explicit URL/ID instead |

## How it works

`notebook` is a single Python file (no dependencies of its own) that:

1. Reads/writes a `.notebook.json` at the project root for binding state.
2. Walks the project directory with priority globs to assemble a Markdown bundle.
3. Caps per-file and total size so the bundle stays useful for retrieval.
4. Calls `notebooklm` to delete the prior source-by-title and upload the new bundle.
5. Caches each uploaded bundle locally for `diff`.

Read the source: it's ~300 lines, [./notebook](./notebook).

## Credits

- Underlying NotebookLM API + CLI: [`notebooklm-py`](https://github.com/teng-lin/notebooklm-py) by [@teng-lin](https://github.com/teng-lin) (Apache 2.0).
- This wrapper: MIT.

## License

[MIT](./LICENSE)
