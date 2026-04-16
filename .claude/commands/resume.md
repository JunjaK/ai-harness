# Resume — Checkpoint-Based Work Continuation

Resume interrupted work by loading saved checkpoints. Supports cross-session, cross-branch, and post-compaction recovery.

## Usage

```
/resume               # Load most recent checkpoint and continue
/resume list          # Show all saved checkpoints
/resume save [title]  # Manually save current work state
/resume [id]          # Load a specific checkpoint by timestamp
```

## Workflow

### `/resume` (no args) — Load Latest

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

### `/resume save [title]` — Save Checkpoint

1. Gather current state:
   - `git branch --show-current` → current branch
   - `git status --short` → modified files
   - Current task progress (from conversation context)
2. Write checkpoint to `.claude/session-state/checkpoints/latest.md` using the format from the `checkpoint` skill
3. Also write timestamped copy: `checkpoint-{YYYYMMDD-HHMM}.md`
4. Confirm: "Checkpoint saved: {title}"

### `/resume list` — List Checkpoints

1. List all files in `.claude/session-state/checkpoints/`
2. Parse each file's header (title, branch, timestamp)
3. Display as table:
   ```
   | # | Timestamp        | Title              | Branch       |
   |---|------------------|--------------------|--------------|
   | 1 | 2026-04-16 14:30 | Auth implementation | feat/auth   |
   | 2 | 2026-04-16 11:00 | API design done     | main        |
   ```

### `/resume [id]` — Load Specific

1. Match `[id]` against checkpoint timestamps or titles
2. Load and display (same as `/resume` no-args flow)

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
