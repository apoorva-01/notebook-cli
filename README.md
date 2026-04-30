# notebook-cli

> Turn any project on disk into a [NotebookLM](https://notebooklm.google.com/)-backed knowledge base — bundle, upload, diff, and wire into [Claude Code](https://claude.com/claude-code) with one command each.

`notebook-cli` is a wrapper around [`notebooklm-py`](https://github.com/teng-lin/notebooklm-py) that adds project-scoped commands. Bind a project to a NotebookLM notebook once, then keep the notebook in sync with your repo using `notebook update`. Ask the notebook anything with `notebook ask`. Tell Claude Code to use it for context with `notebook claude install`.

```
notebook init              # bind this project to a notebook (interactive)
notebook update .          # bundle plan + docs + key code → upload as one source
notebook diff              # preview what'll change before uploading
notebook plan-only .       # plan + docs only, as a separate source
notebook claude install    # add NotebookLM context block to CLAUDE.md
notebook ask "..."         # query the bound notebook
```

Old uploads are replaced on each run, so the notebook stays clean — no orphaned sources.

---

## Install (single command)

```bash
pipx install git+https://github.com/apoorva-01/notebook-cli
```

Then, **once per machine**, install Chromium and authenticate:

```bash
playwright install chromium    # one-time browser download (~150 MB)
notebooklm login               # opens a real browser; complete Google login, press Enter
notebooklm status              # verify auth
```

That's it — `pipx` handles the venv, pulls `notebooklm-py` + `playwright` as dependencies, and puts a `notebook` command on your `PATH`.

> **No pipx?** `brew install pipx` (macOS) or `python3 -m pip install --user pipx`.

### Alternative installs

```bash
# From PyPI (once published)
pipx install notebook-cli

# Or, direct script install (no Python packaging)
curl -fsSL https://raw.githubusercontent.com/apoorva-01/notebook-cli/main/install.sh | bash
```

---

## Quick start

```bash
cd /path/to/your/project

notebook init             # interactive: create new, pick existing, or paste URL
notebook update .         # uploads plan + docs + key code as one bundle
notebook claude install   # writes a NotebookLM context block into CLAUDE.md
```

After that, every meaningful change:

```bash
notebook diff             # preview
notebook update .         # re-upload (replaces the prior bundle)
```

---

## All commands

### `notebook init [URL_OR_ID]`

Bind the **current project** to a NotebookLM notebook. Writes `.notebook.json` at the project root.

- **No argument (interactive)** prompts for one of:
  1. **Create a new notebook** → asks for a title → creates → binds.
  2. **Pick an existing notebook** → numbered list → binds your pick.
  3. **Paste a URL or ID** → parses out the UUID and binds it.
- **With an argument** skips the prompt — useful for scripts and CI.

Re-binding a project asks for confirmation. Pass an explicit URL/ID to force without the prompt.

```bash
notebook init                                                            # interactive
notebook init https://notebooklm.google.com/notebook/72b05864-9b4b-...   # explicit
notebook init 72b05864-9b4b-439a-ac9f-ee60c88d1e71                       # bare UUID
```

### `notebook update [PATH]`

Bundle the project at `PATH` (default: `cwd`) and upload it as a single Markdown source. Replaces any prior bundle in the notebook with the same title.

**What's bundled** (in priority order, deduped):

1. **Plan** — first `*.md` under `<project>/**/plans/`, else the most recent file in `~/.claude/plans/`.
2. **Top-level docs** — `README*`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `DEPLOY.md`, `ARCHITECTURE.md`, `PARITY*.md`, `PORTING*.md`, `docs/**/*.md`.
3. **Manifests** — `package.json`, `pyproject.toml`, `Cargo.toml`.
4. **Code skeleton** — `lib/**`, `src/**`, `app/**`, `components/**`, `sources/**` for `.js .ts .mjs .tsx .py`.

**Caps:** 64 KB per file, 1.5 MB total bundle.
**Skips:** `node_modules`, `.next`, `.venv`, `dist`, `build`, `.git`.

**Side effects:** saves `/tmp/notebook_update_<repo>.md`, caches `<project>/.last_bundle.md` (used by `diff`), updates `.notebook.json`.

```bash
notebook update .
notebook update /path/to/another/project
```

### `notebook plan create [PATH]`

Generate (or refresh) a `PLAN.md` at the project root by invoking the [Claude Code](https://claude.com/claude-code) CLI non-interactively. Claude reads the codebase and emits a structured plan (Goal · Architecture · Status · Key files · Decisions · Open questions).

`notebook update` will offer to run this for you the first time it finds no plan in the project. The prompt only fires if you're in a real terminal.

Requires the `claude` CLI on your `PATH` (Claude Code).

```bash
notebook plan create        # writes PLAN.md in cwd
notebook plan create /path/to/repo
```

### `notebook plan-only [PATH]`

Like `update` but bundles **plan + docs only** — no code. Uploaded as a separate source titled `<repo> — Plan & Docs` so it lives alongside the full bundle. Useful when code volume drowns out strategic docs in retrieval.

Caches separately to `<project>/.last_plan_bundle.md`.

```bash
notebook plan-only .
```

### `notebook diff [--plan] [PATH]`

Unified diff between the current local bundle and the last-uploaded one. Compile-timestamp lines are stripped from both sides so they don't show as noise.

- `--plan` (or `-p`) → diff the plan-only bundle.
- No baseline yet → hint to run `notebook update` first.

```bash
notebook diff
notebook diff --plan
```

### `notebook claude install`

Inject a NotebookLM context block into the project's `CLAUDE.md`. Creates the file if missing; replaces an existing `<!-- notebook:begin -->…<!-- notebook:end -->` block in place.

The block tells Claude Code:
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

Forwarded verbatim to `notebooklm`. The wrapper is additive, not a replacement.

```bash
notebook list                       # → notebooklm list
notebook source list                # → notebooklm source list
notebook create "Some new notebook"
```

---

## Files written by the CLI

| Path | Purpose | Commit? |
|---|---|---|
| `<project>/.notebook.json` | Notebook id + last-upload timestamps | ✅ Small, useful for teammates |
| `<project>/.last_bundle.md` | Cached previous full upload (for `diff`) | ❌ |
| `<project>/.last_plan_bundle.md` | Cached previous plan-only upload | ❌ |
| `<project>/CLAUDE.md` (block only) | Tells Claude Code to query NotebookLM | ✅ |
| `~/.notebooklm/storage_state.json` | Auth session (managed by notebooklm-py) | ❌ private credentials |

**Recommended `.gitignore`:**
```
.last_bundle.md
.last_plan_bundle.md
```

---

## Typical workflow

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

---

## Multi-project use

`.notebook.json` is per-project. The wrapper auto-detects the binding by walking up from `cwd` until it finds `.notebook.json` (up to 20 levels). Run `notebook init` again to rebind.

For parallel agents or CI, the underlying CLI also supports `NOTEBOOKLM_PROFILE` and `NOTEBOOKLM_HOME` env vars — see [`notebooklm-py` docs](https://github.com/teng-lin/notebooklm-py#cicd-multiple-accounts-and-parallel-agents).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `error: no notebook bound to this project` | `notebook init` in the project root |
| `Aborted!` on `notebooklm login` | Login script needs an interactive terminal — not a background job |
| `Playwright not installed` | `playwright install chromium` |
| Notebook chat says "drop sources here" | The notebook has zero sources — `notebook update .` to upload one |
| Want to start over | `rm <project>/.notebook.json <project>/.last_*_bundle.md` and re-run `notebook init` |
| `error: interactive init requires a terminal` | `notebook init` ran without a TTY — pass an explicit URL/ID instead |

---

## How it works

`notebook-cli` is a single Python module (`notebook_cli.cli`) that:

1. Reads/writes a `.notebook.json` at the project root for binding state.
2. Walks the project with priority globs to assemble a Markdown bundle.
3. Caps per-file and total size so the bundle stays useful for retrieval.
4. Calls `notebooklm` to delete the prior source-by-title and upload the new bundle.
5. Caches each uploaded bundle locally for `diff`.

Source: [`src/notebook_cli/cli.py`](src/notebook_cli/cli.py).

---

## Credits

- Underlying NotebookLM API + CLI: [`notebooklm-py`](https://github.com/teng-lin/notebooklm-py) by [@teng-lin](https://github.com/teng-lin) (Apache 2.0).
- This wrapper: MIT.

## License

[MIT](./LICENSE)
