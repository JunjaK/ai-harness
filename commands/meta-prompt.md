---
description: "Meta-Prompt — compile a raw context dump into an optimized, self-contained prompt to inject into a fresh environment (new session, /team-run task string, subagent, or another tool). Borrows brainstorm's questioning discipline; terminal output is a portable prompt, not a design doc."
---

# Meta-Prompt — context dump → optimized portable prompt

Turn an unrefined brain-dump into a **portable, self-contained prompt** you can paste into a cold context — a fresh agentic session, a `/team-run "…"` task string, a subagent prompt, or a plain chatbot. This is a **prompt compiler**, not a planner: it produces a prompt string, not a design doc, and does NOT run the full `brainstorm` skill (whose terminal is a `_docs` design doc + team handoff — the wrong artifact here).

Meta-prompting's whole point is speed: dump raw, let the compiler fill the gaps and sharpen. Do not over-ceremony it.

## Usage

```
/meta-prompt <raw dump>   # compile the dump into a portable prompt
/meta-prompt              # ask the user to dump the idea unrefined, then compile
```

## What It Does

1. **Ingest.** `<raw dump>` is the source. Empty → ask the user to dump the idea **unrefined** (no self-editing — the raw dump is the input, sharpening is the compiler's job).
2. **Gap pass (borrowed, not full brainstorm).** If the dump is already enough to write a sharp prompt, **skip this and compile**. Only when a load-bearing gap exists, run **one** round using `brainstorm`'s Unknowns-First framing — surface the missing pieces as labeled options (`AskUserQuestion`, A/B/C) so the user picks fast; a single batched round, no 2-3 approaches, no design doc. Ask about: purpose, target environment (below), and any success condition the dump left vague.
3. **Compile** the portable prompt under four hard rules:
   - **Explicit success conditions** — replace every vague modifier with a concrete condition (per CLAUDE.md "Literal instruction following": "keep it clean" → the actual checklist). The reader must know exactly when it's done.
   - **Self-contained** — zero references to "the above" / "as discussed" / this conversation. It must stand alone in a cold context, naming real file paths / commands / constraints directly.
   - **No-hallucination guard** — never invent a fact the user did not give. A gap that couldn't be filled in step 2 becomes an explicit `[FILL: …]` placeholder in the output, never a fabricated value. (§3 hard-line.)
   - **Env-tuned** — length and format match the target (table below).
4. **Deliver** — output the prompt in a single fenced block for easy copy. Offer to also save it to the scratchpad. Do **NOT** write it to `_docs/` — a throwaway prompt artifact would pollute the docs lifecycle.

## Target-environment tuning

Ask or infer the target in step 2, then tune:

| Target | Tuning |
|--------|--------|
| Fresh agentic session / another Claude Code | Dense, no hard length cap; point at real repo paths and existing patterns. |
| `/team-run "…"` task string | One tight imperative paragraph — goal + constraints + done-condition. |
| Subagent prompt | Fully self-contained; add a structured output schema when a downstream gate consumes a field. |
| Plain chatbot (ChatGPT / Claude.ai) | ≤ ~4000 chars, no repo assumptions, everything the model needs inlined. |
| Image-gen / research | Env-specific — short visual descriptors, or a framed research question with scope bounds. |

The ~4000-char figure is a **chatbot-target guide, not a universal cap** — an agentic target has no structural reason to be truncated.

## Related

- `brainstorm` skill — the questioning discipline (Unknowns-First, one-at-a-time, success criteria) this command borrows; use it directly when the goal is an **approved design** that flows into implementation, not a portable prompt.
- CLAUDE.md "Literal instruction following" — the vague-modifier → explicit-condition rule the compiler enforces.
- `handoff` skill — when the goal is to pass **live work state** (done / left / how-to-resume) to another session, not to compile a from-scratch prompt.

ARGUMENTS: $ARGUMENTS
