---
name: checkpoint
description: "Save and restore work state across sessions, branches, and compactions. Use when saving progress before stopping, switching branches, or when the /resume command is invoked."
---

# Checkpoint Management

Persist work state for cross-session recovery. Checkpoints capture everything needed to resume work without re-reading the entire codebase.

## Checkpoint Format

```markdown
# Checkpoint: {title}
**Branch**: {git branch name}
**Timestamp**: {YYYY-MM-DD HH:MM}
**Plan**: {_docs/ plan file path, or "none"}

## Current Progress
- [x] Completed step 1
- [x] Completed step 2
- [ ] Remaining step 3
- [ ] Remaining step 4

## Modified Files
{output of git status --short, staged + unstaged}

## Key Decisions
- {Decision}: {Rationale}

## Verified Approaches
- {Approach}: {Evidence it works — test pass, build success, etc.}

## Failed Approaches
- {Approach}: {Why it failed — error message, wrong assumption, etc.}

## Blockers / Gotchas
- {Anything the next session needs to watch out for}

## Next Steps
1. {Concrete, actionable next task}
2. {Second task}
3. {Third task}
```

## Storage

```
.claude/session-state/checkpoints/
├── latest.md                          # Always the most recent (overwritten)
├── checkpoint-20260416-1430.md        # Timestamped archive
├── checkpoint-20260416-1100.md        # Older checkpoint
└── ...
```

- `latest.md` is always overwritten with the newest checkpoint
- Timestamped copies are kept for history (max 10, oldest auto-cleaned)
- Checkpoints from team workflow phases are prefixed: `phase1-baseline.md`, `phase3-worktree-auth.md`

## Save Checkpoint

### Manual Save

When user runs `/resume save [title]` or when explicitly asked:

1. Capture git state:
   ```bash
   git branch --show-current
   git status --short
   ```
2. Summarize conversation progress (completed/remaining from tasks or context)
3. Write checkpoint file using the format above
4. Save to both `latest.md` and timestamped file

### Auto-Save (Hook Triggered)

Hooks trigger checkpoint saves at these events:
- **Session Stop**: `session-stop.sh` promotes `current.md` content to checkpoint
- **Pre-Compact**: `pre-compact.sh` saves current state before compression
- **Phase Completion**: Team workflow saves after each phase

Auto-save uses `current.md` as source — the session state file maintained during work.

## Restore Checkpoint

### Load Process

1. Read checkpoint file (latest.md or specific)
2. Parse all sections
3. Compare current branch with checkpoint branch:
   - Same branch: proceed normally
   - Different branch: warn user, suggest `git checkout {branch}`
4. Check if plan file exists → load for additional context
5. Check modified files against current `git status`:
   - Files still modified: "Continuing from last state"
   - Files committed since: "Changes from checkpoint have been committed"
   - New modifications: "New changes since checkpoint"
6. Present Next Steps as actionable items
7. Begin work on the first remaining step

### Branch Recovery

If checkpoint was on a different branch:
```
⚠ Checkpoint was on branch: feat/auth
   Current branch: main

Options:
1. Switch to feat/auth and continue
2. Stay on main and use checkpoint as reference only
```

## Cleanup

- Keep max **10** timestamped checkpoints
- Auto-clean when saving new checkpoint:
  ```bash
  ls -1t checkpoints/checkpoint-*.md | tail -n +11 | xargs rm -f
  ```
- `latest.md` is never auto-cleaned (always available)

## Integration with Team Workflow

| Workflow Event | Checkpoint Name | Content |
|----------------|----------------|---------|
| Plan finalized (Phase 1) | `phase1-baseline.md` | Plan summary + file assignments |
| Designer completes (Phase 3) | `phase3-worktree-{name}.md` | Implementation report + test results |
| All worktrees merged | `phase3-integration.md` | Merged state + any conflicts resolved |
| Verification pass (Phase 4) | `phase4-verified.md` | Full verification results |
| Before PR (Phase 5) | `phase5-final-gate.md` | Security review + ship decision |

## Quick Reference

```
Save:    /resume save "title"     or auto (hooks)
Load:    /resume                  or /resume [id]
List:    /resume list
Storage: .claude/session-state/checkpoints/
Format:  Branch + Progress + Decisions + Verified + Failed + Next Steps
Max:     10 timestamped + 1 latest
```
