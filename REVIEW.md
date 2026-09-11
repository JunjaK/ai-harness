# Review instructions

Policy for any review pass over this repo — `/code-review`, a review subagent, or a human
reading a diff. This repo ships **prompts and rules, not runtime code**, so "does it compile"
is not the question. The question is whether an agent reading the changed text at 3am,
with no memory of this conversation, does the right thing.

## Passes

Run four passes and tag each finding with its pass.

- **Consistency** — a rule changed in one file but not its mirrors. This repo states the same
  fact in several places on purpose (`CLAUDE.md` router → `.claude/rules/` → the skill →
  `README.md`); a half-applied change is the most common defect here. Every rule edit gets a
  repo-wide grep for the old wording before it counts as done.
- **Literalness** — vague modifiers in agent-facing text. `keep it simple`, `if needed`,
  `as appropriate`, `when relevant` are defects: each MUST be replaced with a specific
  condition or an explicit trigger list. A rule an agent can rationalize around is not a rule.
- **Release discipline** — behavior changed without a version bump in BOTH
  `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, a missing `CHANGELOG.md`
  entry, a stale README "Latest" block, or a `description` field whose summary no longer
  matches the skill. Version-cached distribution means an unbumped change ships as a no-op.
- **Contradiction** — the new text conflicts with an existing rule rather than replacing it.
  Two rules that disagree resolve to whichever the model happens to read last.

## What Important means here

Reserve **Important** for findings that would make an agent do the wrong thing: a rule that
contradicts another, a vague modifier on a safety-relevant instruction, a destructive
operation without a gate, a hard-coded model version, a doc-bucket rule that would let an
agent reorganize an append-only collection, or a version bump that will not reach users.

Everything else — wording, ordering, table formatting, heading style — is a nit.

## Cap the nits

Report at most five nits per review; summarize the rest as a count.

## Do not report

- `_docs/complete/**` and `_docs/deprecated/**` — historical records. They are allowed to
  describe the world as it was, including model versions that were current then.
- `CHANGELOG.md` entries for already-released versions.
- Prose style in `_workspace/**` (untracked anyway) or in this file's own tone.
- Anything a hook already enforces deterministically — say so once, do not re-flag per file.

## Feeding findings back

If a review raises the same finding a second time, the fix includes writing the rule into
`CLAUDE.md` or the relevant `.claude/rules/` file in the same change. A review that keeps
catching the same class of mistake is reporting a missing rule, not a bad diff.
