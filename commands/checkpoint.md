---
description: "Checkpoint — save or restore work state across sessions, branches, and compactions; the harness work-state command, distinct from Claude Code's built-in /resume."
---

# Checkpoint — Save and Restore Work State

Save or resume interrupted work via checkpoint files. Supports cross-session, cross-branch, and post-compaction recovery.

> Note: This is a custom `/checkpoint` command for work-state management.
> It does not replace Claude Code's built-in `/resume` (which resumes a previous conversation).

## Usage

```
/checkpoint                   # Load most recent checkpoint and continue work
/checkpoint list              # Show all saved checkpoints
/checkpoint save [title]      # Manually save current work state
/checkpoint load [id]         # Load a specific checkpoint by timestamp
```

## Routing

Invoke the `checkpoint` skill, which owns the checkpoint format, storage layout, save/restore procedure, and cleanup rules. This command only maps arguments onto that skill's sections:

| Argument | Route to `checkpoint` skill |
|----------|-----------------------------|
| *(none)* | **Restore Checkpoint** → Load Process, source `latest.md` (fall back to `.claude/session-state/last-session.md`; if neither exists, report "No checkpoint available") |
| `save [title]` | **Save Checkpoint** → Manual Save, using `[title]` as the checkpoint title |
| `load [id]` | **Restore Checkpoint** → Load Process, matching `[id]` against checkpoint timestamps or titles |
| `list` | **Storage** layout → list `.claude/session-state/checkpoints/`, parse each header, display as a table of #, timestamp, title, branch |

## Auto-Save Triggers

Checkpoints are automatically saved by hooks:
- **Session Stop** (`session-stop.sh`): Saves checkpoint from `current.md` before archiving
- **Pre-Compact** (`pre-compact.sh`): Saves checkpoint before context compression
- **Team Workflow**: Each phase completion triggers checkpoint via verification-loop

## Related

- Skill: `checkpoint` — Checkpoint format and management details
- Skill: `continuous-learning` — Session state management
- Hook: `session-stop.sh` — Auto-checkpoint on session end
- Hook: `pre-compact.sh` — Auto-checkpoint before compaction

ARGUMENTS: $ARGUMENTS
