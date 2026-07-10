---
name: brainstorm
description: Use BEFORE any solo/low-blast creative work — designing a feature, component, behavior change, or this harness itself — to turn an idea into an approved design through a lightweight collaborative dialogue. The solo counterpart to /team-brainstorm (which owns multi-file / cross-cutting / product / architecturally-uncertain work). Harness-owned; do NOT invoke any external brainstorming skill.
---

# Brainstorm (Lightweight, Solo)

Turn an idea into a fully-formed design through natural collaborative dialogue — then hand off to the harness implementation pipeline. This is the **solo, low-ceremony** brainstorm. It is harness-owned; it replaces (and does not call) any external brainstorming skill.

## Route First (blast radius decides)

```
Multi-file / cross-cutting (API+UI+state) / product feature / auth·payments·sensitive data
  / genuine architectural uncertainty
        → STOP. Use /team-brainstorm (Leader + Architects, cross-review, visual plan).

Solo / local / throwaway / this harness / a single bounded change
        → use THIS skill.
```

When unsure which side you're on, ask the user one routing question before designing.

## Unknowns First (name what you don't know)

Before ideating, locate the unknowns — finding them now is cheap; finding them mid-implementation is expensive. Four kinds (the "map vs territory" framing — the map is the prompt/spec, the territory is the real codebase):

| Kind | What it is | How to surface it here |
|------|-----------|------------------------|
| Known knowns | what the user already stated | the request itself |
| Known unknowns | open decisions, known to be open | one-at-a-time elicitation (below) |
| Unknown knowns | "I'll know it when I see it" taste | propose 2-3 approaches / a throwaway prototype to react to |
| Unknown unknowns | blind spots not yet nameable | **Blindspot Pass** ↓ |

**Blindspot Pass** — run when entering unfamiliar territory (new area of the codebase, unfamiliar domain/library/tool, first touch of a subsystem): before proposing anything, surface the *user's* unknown-unknowns and teach them — prior art, historical decisions, common potholes, what "good" looks like here. Calibrate on their starting point ("I know nothing about X"). Skip when the territory is already well-known. This is a positive move (discover, then decide), not a gate.

## Hard Gate

Do NOT write code, scaffold, or take any implementation action until you have presented a design and the user has approved it. This applies regardless of perceived simplicity — the design can be a few sentences for a truly simple change, but you MUST present it and get approval. "Too simple to need a design" is exactly where unexamined assumptions waste the most work.

## Checklist

Create a todo per item and complete in order:

1. **Explore context (+ Blindspot Pass if unfamiliar)** — check relevant files, docs, recent commits; for an existing codebase, understand current patterns before proposing changes. In unfamiliar territory, run a Blindspot Pass (see "Unknowns First") to surface unknown-unknowns before proposing
2. **Ask clarifying questions** — one at a time; purpose, constraints, success criteria
3. **Propose 2-3 approaches** — with trade-offs and an explicit recommendation
4. **Present the design** — in sections scaled to complexity; get approval after each section
5. **Write the design doc** — to `_docs/active/planning/<created>/<created>-<topic>-design.md` (see Output Rules). Do NOT auto-commit.
6. **Spec self-review** — inline scan for placeholders, contradictions, ambiguity, scope; fix inline
7. **User reviews the spec** — ask the user to review the written file before proceeding
8. **Hand off to implementation** — see Handoff (NOT an external writing-plans skill)

## The Process

**Understanding the idea**
- Check the current state first (files, docs, recent commits).
- Assess scope: if the request is actually several independent subsystems, flag it and help decompose into sub-projects (each gets its own design → implementation cycle) rather than refining details of something that should be split. If it's genuinely multi-file/cross-cutting, that's the `/team-brainstorm` signal — route there.
- Ask questions **one at a time**. Focus on purpose, constraints, success criteria.
- **Prefer labeled options (A/B/C, 1/2/3) over prose**, with your recommendation marked — the user decides fastest from an enumerated list. Open-ended is fine when a list doesn't fit.

**Exploring approaches**
- Propose 2-3 approaches with trade-offs. Lead with your recommended option and explain why.

**Presenting the design**
- Once you understand what you're building, present it. Scale each section to its complexity (a few sentences if straightforward).
- Ask after each section whether it looks right so far.
- Cover, as relevant: architecture, components, data flow, error handling, testing.
- Reuse first: prefer existing verified patterns/components over new abstractions. Follow existing structure; include only targeted improvements that serve this goal — no unrelated refactoring.

## Output Rules (harness-native — differs from external brainstorming)

- **Save the design to `_docs/active/planning/<created>/<created>-<topic>-design.md`** (per `docs-lifecycle`). NOT to any `docs/superpowers/` path.
- **Do NOT auto-commit.** The user gates commits — leave the file staged-or-unstaged for them.
- Use the `docs-lifecycle` skill for foldering/status conventions; use `plan-visualizer` only if a diagram genuinely helps (optional, not default).

## Spec Self-Review

After writing, look with fresh eyes:
1. **Placeholders** — any TBD/TODO/incomplete/vague? Fix.
2. **Consistency** — sections contradict each other? Architecture matches the feature?
3. **Scope** — focused enough for one implementation pass, or needs decomposition?
4. **Ambiguity** — any requirement readable two ways? Pick one, make it explicit.

Fix inline, then ask the user to review the file.

## Handoff (terminal step)

Once the spec is approved, hand off to the **harness** pipeline — do NOT invoke an external `writing-plans`/`executing-plans` skill:

- Implementation that fits the team workflow (3+ files / cross-cutting / sensitive) → suggest `/team-run "<task>"` (or `/team` to stay in the loop).
- Small bounded change on this harness / local → implement directly (the harness's own work is low-ceremony; spec may be skipped only when the Scope Discipline rule in CLAUDE.md allows).
- If the work should pass to another agent or session, use the `handoff` skill.

## Key Principles

- One question at a time — don't overwhelm.
- Labeled options + explicit recommendation — match how the user decides.
- YAGNI ruthlessly — remove unnecessary features from every design.
- Always propose 2-3 approaches before settling.
- Incremental validation — present, get approval, move on.
- Be flexible — go back and clarify when something doesn't fit.
