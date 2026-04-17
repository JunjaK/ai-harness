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

## Workflow

### `/checkpoint` (no args) — Load Latest

1. Read `.claude/session-state/checkpoints/latest.md`
2. If not found, check `.claude/session-state/last-session.md`
3. If not found, report "No checkpoint available"
4. Display checkpoint content:
   - Current branch vs checkpoint branch (warn if different)
   - Progress (completed / remaining steps)
   - Key decisions made
   - Next Steps (actionable items)
5. Check if plan file exists (from checkpoint's `Plan:` field)
   - If yes, read the plan for additional context
6. Ask: "Continue from where you left off?" and proceed with Next Steps

### `/checkpoint save [title]` — Save Checkpoint

1. Gather current state:
   - `git branch --show-current` → current branch
   - `git status --short` → modified files
   - Current task progress (from conversation context)
2. Write checkpoint to `.claude/session-state/checkpoints/latest.md` using the format from the `checkpoint` skill
3. Also write timestamped copy: `checkpoint-{YYYYMMDD-HHMM}.md`
4. Confirm: "Checkpoint saved: {title}"

### `/checkpoint list` — List Checkpoints

1. List all files in `.claude/session-state/checkpoints/`
2. Parse each file's header (title, branch, timestamp)
3. Display as table:
   ```
   | # | Timestamp        | Title              | Branch       |
   |---|------------------|--------------------|--------------|
   | 1 | 2026-04-16 14:30 | Auth implementation | feat/auth   |
   | 2 | 2026-04-16 11:00 | API design done     | main        |
   ```

### `/checkpoint load [id]` — Load Specific

1. Match `[id]` against checkpoint timestamps or titles
2. Load and display (same as `/checkpoint` no-args flow)

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
