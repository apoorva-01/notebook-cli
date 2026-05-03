# notebook-cli — full context

> Custom CLI that turns any project on disk into a NotebookLM-backed knowledge base. Wraps [`notebooklm-py`](https://github.com/teng-lin/notebooklm-py) (browser-automation library by teng-lin) and adds project-scoped commands.

- **GitHub:** https://github.com/apoorva-01/notebook-cli
- **Latest tag:** v0.1.3 (2026-04-30)
- **Console binary:** `notebook` (installed via `pipx`)
- **Local working copy:** `/Volumes/SSD/Apoorva/notebook-cli/` (this folder)

---

## What it does

NotebookLM is Google's RAG product — drop sources in, ask questions, get cited answers. Each notebook lives at `https://notebooklm.google.com/notebook/<uuid>`.

Without this wrapper you'd have to:
1. Open the browser, log into NotebookLM
2. Manually upload every relevant file from your project
3. Repeat every time you change the plan / docs / code
4. Manually delete old sources to keep retrieval clean

With `notebook-cli` you:
1. Run `notebook init` once per project (binds to a notebook via UUID, saves to `.notebook.json`)
2. Run `notebook update .` whenever something meaningful changed — it bundles plan + docs + key code into one Markdown source, replaces the previous bundle, and re-uploads
3. Run `notebook claude install` once to inject a CLAUDE.md block telling Claude Code to query the notebook before answering plan/architecture questions

It's the difference between a stale notebook nobody touches and a living one that always reflects the current repo.

---

## Install

One-liner via pipx (recommended):

```bash
pipx install git+https://github.com/apoorva-01/notebook-cli
playwright install chromium     # one-time browser download (~150 MB)
notebooklm login                # one-time Google login (opens real browser)
notebooklm status               # verify auth
```

Why pipx: handles the venv, pulls `notebooklm-py` + `playwright` as deps, drops `notebook` on `$PATH` — no `python -m`, no per-project install.

Alternative installs documented in [`README.md`](./README.md):
- From PyPI (once published): `pipx install notebook-cli`
- Direct script: `curl -fsSL https://raw.githubusercontent.com/apoorva-01/notebook-cli/main/install.sh | bash`

---

## Commands (the full surface)

All implemented in [`src/notebook_cli/cli.py`](./src/notebook_cli/cli.py).

| Command | What it does |
|---|---|
| `notebook init [URL_OR_ID]` | Bind the current project to a notebook. Interactive when called with no arg — prompts: (1) create new, (2) pick existing from list, (3) paste URL/ID. Writes `.notebook.json` at project root. |
| `notebook update [PATH]` | Bundle plan + top-level docs + manifests + code skeleton into one Markdown file, delete the previous bundle from the notebook (matched by title), upload the new one. Idempotent. Caps: 64KB/file, 1.5MB total. Saves cache for `diff`. |
| `notebook plan create [PATH]` | Generate a fresh `PLAN.md` at project root by invoking the `claude --print` CLI non-interactively against the codebase. Structure: Goal · Architecture · Status · Key files · Decisions · Open questions. |
| `notebook plan import [PATH]` | Pick a Claude Code session plan from `~/.claude/plans/` (newest first, with timestamp + first heading shown) and copy it into the project as `PLAN.md`. **In v0.1.3+:** also prompts whether to (1) run the picked session through Claude Code with a customizable prompt that produces a detailed multi-section PLAN.md (Overview, Plan, Features, Architecture, Deployment, Decisions, Status), or (2) copy verbatim. |
| `notebook plan-only [PATH]` | Like `update` but **only** plan + top-level docs (README, AGENTS.md, CLAUDE.md, docs/**) — no code. Uploaded as a separate source titled `<repo> — Plan & Docs` so it lives alongside the full bundle. Useful when code volume drowns out strategic docs in retrieval. |
| `notebook diff [--plan] [PATH]` | Unified diff between current local bundle and last-uploaded one. Compile-timestamp lines stripped. `--plan` diffs the plan-only bundle. |
| `notebook claude install` | Inject a `<!-- notebook:begin -->…<!-- notebook:end -->` block into project's `CLAUDE.md`, telling Claude Code to query NotebookLM first for plan/architecture/research questions and to refresh via `notebook update .` after meaningful changes. |
| `notebook ask "QUESTION"` | Pass-through to `notebooklm ask`, auto-scoped to this project's bound notebook. |
| Anything else | Forwarded verbatim to the underlying `notebooklm` CLI (e.g. `notebook list`, `notebook source list`, `notebook create "title"`). |

---

## Missing-plan flow (the v0.1.2 enhancement)

When `notebook update` runs and no plan is found in the project, you get a 3-option prompt:

```
ℹ️  No plan file found in this project. What do you want to do?
  1) Generate a new plan with Claude Code (writes PLAN.md)
  2) Pick an existing Claude Code session plan from ~/.claude/plans/
  3) Skip — bundle without a plan
Choice [1/2/3]:
```

In non-interactive contexts (CI, piped stdin) the prompt is suppressed and update continues without a plan, hinting at `notebook plan create` / `notebook plan import`.

The "import session plan" path (option 2 + the standalone `notebook plan import`) was upgraded in v0.1.3: after picking a session, it asks whether to **rewrite the session through Claude Code** to produce a structured PLAN.md (default), or copy verbatim. The default prompt asks Claude to organize the session into Overview / Plan / Features / Architecture / Deployment / Decisions / Status sections — but you can supply your own prompt at the input.

---

## What gets bundled by `notebook update`

In priority order (deduped — first match wins per file):

1. **Plan** — `find_plan()` looks at:
   - `plan` field in `.notebook.json` (path, absolute or relative)
   - First `*.md` under `<project>/**/plans/`
   - Common project-root names: `PLAN.md`, `plan.md`, `ROADMAP.md`
   - **Project-scoped only** — does NOT fall back to `~/.claude/plans/` (that bug was fixed in v0.1.1; the global directory is shared across all sessions and grabbing the most-recent file there contaminated bundles with other projects' plans)
2. **Top-level docs** — `README*`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `DEPLOY.md`, `ARCHITECTURE.md`, `PARITY*.md`, `PORTING*.md`, `docs/**/*.md`
3. **Manifests** — `package.json`, `pyproject.toml`, `Cargo.toml`
4. **Code skeleton** — `lib/**`, `src/**`, `app/**`, `components/**`, `sources/**` for `.js .ts .mjs .tsx .py`

**Skipped paths:** `node_modules`, `.next`, `.venv`, `dist`, `build`, `.git`.

**Caps:** 64 KB per file, 1.5 MB total bundle. Files past the cap are truncated with a marker; bundle stops at the total cap with `(stopping bundle — N files matched, hit 1500KB cap)`.

**Side effects:** writes `/tmp/notebook_update_<repo>.md` (the actual upload artifact), `<project>/.last_bundle.md` (cache for `diff`), and updates `.notebook.json` with `last_update_at` + `last_update_bytes`.

---

## Files written/managed by the CLI

| Path | Purpose | Commit? |
|---|---|---|
| `<project>/.notebook.json` | Notebook id + last-upload timestamps + optional `plan` override | ✅ Small, useful for teammates |
| `<project>/.last_bundle.md` | Cached previous full upload (for `diff`) | ❌ |
| `<project>/.last_plan_bundle.md` | Cached previous plan-only upload | ❌ |
| `<project>/CLAUDE.md` (block only) | Tells Claude Code to query NotebookLM | ✅ |
| `~/.notebooklm/storage_state.json` | Auth session (managed by notebooklm-py) | ❌ private credentials |

Recommended `.gitignore`:
```
.last_bundle.md
.last_plan_bundle.md
```

---

## Architecture

Single Python module (`notebook_cli.cli`) that:

1. Reads/writes `.notebook.json` at the project root for binding state (walks up from cwd up to 20 levels to find it).
2. Walks the project with priority globs to assemble a Markdown bundle.
3. Caps per-file and total size so the bundle stays useful for retrieval.
4. Calls `notebooklm` CLI to delete the prior source-by-title and upload the new bundle.
5. Caches each uploaded bundle locally for `diff`.

Entry point in [`pyproject.toml`](./pyproject.toml):
```toml
[project.scripts]
notebook = "notebook_cli.cli:_entry"
```

`_entry()` adds `--version` handling and a first-run hint (reminds you to `playwright install chromium` + `notebooklm login` if `~/.notebooklm/storage_state.json` doesn't exist), then delegates to `main(argv)`.

`main(argv)` is a hand-rolled subcommand router — no `argparse`/`click`. Anything not matching a known subcommand is forwarded verbatim to `notebooklm` so the wrapper is additive, never a replacement.

---

## Version history

| Tag | Date | Highlight |
|---|---|---|
| v0.1.3 | 2026-04-30 | `plan import` now prompts for a custom Claude prompt (default: produce detailed PLAN.md sections from the session) |
| v0.1.2 | 2026-04-30 | Missing-plan 3-option flow in `update`; standalone `notebook plan import` |
| v0.1.1 | 2026-04-30 | Project-scoped plan resolution (bug fix — was reading other projects' plans from `~/.claude/plans/`); `notebook plan create` via `claude --print` |
| v0.1.0 | 2026-04-30 | Initial pipx-installable Python package; `init`, `update`, `plan-only`, `diff`, `claude install`, `ask` |

Each release on GitHub: https://github.com/apoorva-01/notebook-cli/releases

---

## Reference

- **Underlying library** — [`notebooklm-py`](https://github.com/teng-lin/notebooklm-py) by [@teng-lin](https://github.com/teng-lin) (Apache 2.0). Browser automation around NotebookLM (Playwright + Chromium).
- **License of this wrapper** — MIT (see [`LICENSE`](./LICENSE))
- **Source of truth** — `src/notebook_cli/cli.py` (single file, ~785 lines)

---

## Useful commands when working on the wrapper itself

```bash
# Reinstall from this local copy (editable mode)
pipx install --force --editable /Volumes/SSD/Apoorva/notebook-cli

# Or pull latest from GitHub
pipx install --force git+https://github.com/apoorva-01/notebook-cli

# Tail the install
notebook --version

# Quick smoke test on a real project
cd ~/some/project
notebook init
notebook update .
notebook diff
```
