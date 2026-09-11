# `_workspace/` — throwaway run output

Gitignored except this file. Everything here is disposable — delete any of it, any time,
without asking. Nothing in here is an input to anything.

**Before writing here, read this file** — it says which context folder a file belongs in.
**After adding a new context folder, add a row below** so the next session reuses it
instead of inventing a second folder for the same purpose.

## Layout

One folder per purpose, named for that purpose. A bare file at `_workspace/` root — or at
the repo root — is a defect, not a shortcut.

| Folder | What goes in it |
|--------|-----------------|
| `e2e/` | Playwright / agent-browser run output: `<YYYY-MM-DD>-<test-name>/` containing `screenshots/`, `artifacts/` (traces, videos, failure shots), `report/` (HTML + `results.json`), `run.log` |
| `scratch/` | one-off scripts, intermediate JSON, command output too long to keep in context |

Full E2E artifact spec: `reference/e2e-testing.md` §Artifact Layout.

## Rules

- Pass an **explicit path** to every capture call. A relative filename resolves to the repo
  root — that scatter is exactly what this bucket exists to stop.
- **Vendor state paths win.** Auth/session state is not a byproduct: Playwright storage
  state stays at `playwright/.auth/` (its own published convention), never relocated here.
- Nothing here is committed, so nothing here may be the only copy of anything.
