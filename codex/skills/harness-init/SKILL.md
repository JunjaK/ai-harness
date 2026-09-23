---
name: harness-init
description: Analyze an existing code repository and record a concise, evidence-based project profile for later Codex work. Use for first-time setup or when the profile is stale; do not use on an empty repo.
---

# Project profile

Work in the user's target repository, not the AI Harness plugin repository unless
that is the target. This is the Codex equivalent of Claude's `/team-init`; it
does not call a Claude skill or require Claude files in the target.

1. Check `git status --short --branch` and preserve existing changes. Read the
   nearest `package.json` before choosing a JS/TS stack. Inspect lockfiles,
   build/test configs, CI, and representative source and test files. Record only
   conventions supported by files; mark missing or uncertain details `unverified`.
2. Write `.codex/project-profile/index.md` with the current short commit SHA,
   date, stack, package manager, build/type/lint/test commands actually declared
   by the project, source/test layout, API and generated client locations, state
   and UI patterns, deployment evidence, and links to the files supporting each
   finding. Omit sections that do not apply. Never invent a command or default
   framework. Do not install packages.
3. If updating an existing profile, change only facts that the new scan disproves
   and preserve user-added notes. If other work already changed the same file,
   integrate it without overwriting. Do not create `.claude/project-profile/` or
   `.claude/wiki/` for a Codex-only project.
4. Report the profile path, observed stack and checks, plus unknowns. A profile
   is descriptive; source code and current configuration win if they diverge.
