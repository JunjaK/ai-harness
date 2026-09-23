# AI Harness in Codex

This repository contains two separate adapters. Keep the Claude Code files in
`commands/`, `agents/`, `skills/`, `hooks/`, and `.claude-plugin/` working when
changing the Codex adapter.

For Codex work on this repository, use the repository skills in
`.agents/skills/`. The three supported entry points are `$harness-init`,
`$harness-team`, and `$harness-debug`. Their instructions are self-contained;
do not execute Claude's `Agent()`, `Skill()`, `Workflow`, or slash-command syntax.

Check `git status` before editing. Preserve other sessions' changes. Edit only
the paths needed for the request and verify the result. Do not write to user
level `~/.codex` or `~/.agents` configuration from this repository.

The Codex plugin is `codex/` and its manifest is
`codex/.codex-plugin/plugin.json`. Repository skill links point to that package's
real skill bodies. Codex discovers `codex/hooks/hooks.json` within the plugin;
it is separate from Claude's `hooks/hooks.json`. A target project does not
inherit this file merely by installing the plugin; the bundled skills carry
their own rules.
