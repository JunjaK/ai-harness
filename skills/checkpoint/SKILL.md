---
name: checkpoint
description: "Save and restore work state across sessions, branches, and compactions. Use when saving progress before stopping, switching branches, or when the /checkpoint command is invoked."
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

`.claude/session-state/` is gitignored, throwaway runtime data in the **primary** working tree (`$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.claude/session-state`). Each session writes only its own folder, so concurrent sessions in one tree never overwrite each other.

```
.claude/session-state/
├── sessions/<session_id>/             # one folder per session; <session_id> = $CLAUDE_CODE_SESSION_ID
│   ├── current.md                     # this session's live work state
│   └── checkpoints/
│       ├── latest.md                  # newest checkpoint (overwritten)
│       ├── checkpoint-20260416-1430.md
│       └── ...                        # timestamped, max 10
├── runs/<plan-id>.json                # one /team or /team-run record per plan (see below)
└── learnings/<topic>.md               # shared across sessions (continuous-learning)
```

- Before the first write, make sure the project's `.gitignore` carries `.claude/session-state/`; append the line if it is missing and tell the user.
- `$CLAUDE_CODE_SESSION_ID` is set in every Bash tool and hook subprocess and equals the hook input's `session_id`. It survives `--resume`/`--continue` and changes on `/clear`, so a cleared session starts a new folder.
- Team workflow phase checkpoints go in the orchestrator's own `checkpoints/` with a prefix: `phase1-baseline.md`, `phase3-worktree-auth.md`.
- `runs/<plan-id>.json` (`<plan-id>` = the plan filename stem) is **orchestrator-only** (Designers/Testers never write it). It carries `owner_session`; a session that is not the owner reads it but MUST NOT write it — ask the user first, and change the owner only when the user asks to take the run over (`/checkpoint` restore or `/take-over`). Schema: `team-workflow/SKILL.md` → "State Tracking".
- Folders under `sessions/` with no file newer than 14 days are deleted at SessionEnd. `runs/` and `learnings/` are never pruned by hooks. Lessons worth keeping move to `_docs/reference/` (continuous-learning → Promote).

## Save Checkpoint

### Manual Save

When user runs `/checkpoint save [title]` or when explicitly asked:

1. Capture git state:
   ```bash
   git branch --show-current
   git status --short
   ```
2. Summarize conversation progress (completed/remaining from tasks or context)
3. Write checkpoint file using the format above
4. Save to both `latest.md` and a timestamped file in `sessions/$CLAUDE_CODE_SESSION_ID/checkpoints/`

### Auto-Save (Hook Triggered)

Hooks snapshot the session's own `current.md` at these events:
- **SessionEnd**: `session-end.sh`, once when the session terminates
- **Pre-Compact**: `pre-compact.sh`, before compression
- **Phase Completion**: the team workflow saves after each phase

The `Stop` hook (after every reply) does not touch session state.

## Restore Checkpoint

### Load Process

1. Pick the checkpoint: this session's `sessions/$CLAUDE_CODE_SESSION_ID/checkpoints/latest.md` (or a named one). If this session has none — a new or `/clear`ed session — list the other sessions' `latest.md` newest first (session id, timestamp, title, branch) and let the user choose. Never pick another session's state silently.
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
  ls -1t sessions/<session_id>/checkpoints/checkpoint-*.md | tail -n +11 | xargs rm -f
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
| **Every** phase transition | `.claude/session-state/runs/<plan-id>.json` (not a checkpoint file — a live record) | `runId`, `owner_session`, `updated_at`, `phase`, `retries`, `globalCycle`, `escalations[]`, `designerAssignments[]` — written on **every** transition, not just per-phase-completion. Schema + read/write contract: `team-workflow/SKILL.md` → "State Tracking"; routing rules that produce these writes: `team-workflow/resources/escalation.md` |

## Quick Reference

```
Save:    /checkpoint save "title"     or auto (hooks)
Load:    /checkpoint                  or /checkpoint load [id]
List:    /checkpoint list
Storage: .claude/session-state/sessions/$CLAUDE_CODE_SESSION_ID/checkpoints/
Format:  Branch + Progress + Decisions + Verified + Failed + Next Steps
Max:     10 timestamped + 1 latest
```
