---
description: "Meta-Prompt — compile a raw context dump into a self-contained prompt for a cold context: a new session, a /team-run task string, a subagent, another tool, or a running agent session (brief file + one-line send). Output is a portable prompt, not a design doc."
---

# Meta-Prompt — context dump → portable prompt

Turn an unrefined brain-dump into a **self-contained prompt** for a cold context. This is a **prompt compiler**, not a planner: it produces a prompt, not a design doc, and does NOT run the full `brainstorm` skill (whose output is a `_docs` design doc + team handoff — the wrong artifact here).

Speed is the point: the user dumps raw, the compiler fills gaps and sharpens. Each conditional block below applies only when its trigger holds; a short paste-target prompt skips all of them.

## Usage

```
/meta-prompt <raw dump>   # compile the dump into a portable prompt
/meta-prompt              # ask the user to dump the idea unrefined, then compile
```

## Steps

1. **Ingest.** `<raw dump>` is the source. Empty → ask the user to dump the idea **unrefined** (no self-editing — sharpening is the compiler's job).
2. **Gap pass.** If the dump already supports a sharp prompt, skip to step 3. Only when a load-bearing gap exists, run **one** batched round with `brainstorm`'s Unknowns-First framing — labeled options (`AskUserQuestion`, A/B/C), no 2-3 approaches, no design doc. Ask about: purpose, target (table below), any success condition the dump left vague, and whether this redoes a result the user rejected.
3. **Measure environment facts.** Applies when the prompt states facts about the receiver's environment (installed tools and versions, paths, licenses, ports, whether build / test / screenshot run there). Each such fact is a value you checked in this session — the command and its output — or `[FILL: …]`. When the prompt tells the receiver to run a verification loop (compile, test, capture a screenshot), run that loop once yourself before delivery, in a scratch project if the real one does not exist yet, and write the version and minimal setup that passed. A loop you could not run is written into the prompt as unverified.
4. **Compile** under these hard rules:
   - **Explicit success conditions** — replace every vague modifier with a concrete condition (CLAUDE.md "Literal instruction following": "keep it clean" → the actual checklist). The reader knows exactly when it is done.
   - **Self-contained** — no "the above" / "as discussed" / this conversation. Name real absolute paths, commands, and constraints.
   - **No hallucination** — never invent a fact the user did not give or step 3 did not measure. An unfilled gap is an explicit `[FILL: …]`.
   - **Rejection evidence** — when the prompt redoes work the user rejected, include a section that quotes the user's words, lists the evidence paths (captures, logs, the rejected build), and numbers the symptoms. State that reproducing any listed symptom is a failure.
   - **Env-tuned** — length and format match the target (table below).
5. **Structure an agentic prompt.** Applies when the target is an agentic session (fresh session, another CLI agent, a running session). Use each block whose trigger holds:
   - **Three layers** — trigger: the dump contains decided items and items left to the receiver. Put every decided item in exactly one layer: **Fixed** (the receiver does not change it) · **Defaults** (the user's stated preferences; the receiver may depart and records each departure with its reason in a named file) · **Receiver designs** (open, with the success conditions that judge it).
   - **Gated stages** — trigger: the scope spans more than one milestone, or the receiver runs without the user watching. Ordered stages, each with a completion condition and the evidence that proves it (file path or command). Name the stage that blocks every later one — the riskiest core slice — and say later stages do not start until it passes.
   - **Final report format** — same trigger as gated stages. Per stage: **done** (evidence path + command run) / **done, unverified** (what was not checked and why) / **not done** (reason). Anything only the user can check (real device, feel, taste) is listed as unverified with a check order.
   - **Resume rule** — trigger: the run is long enough to compact or restart. Name a progress file in the target repo (e.g. `docs/PROGRESS.md`), updated after each stage with finished stages, next step, decisions, blockers; on resume the receiver re-reads the prompt file and the progress file first. The receiver never edits the prompt file.
6. **Deliver** by target:
   - **Paste target** (chat, `/team-run` string, subagent prompt, or any prompt the user will paste themselves) — output the prompt in one fenced block; offer to save it to the scratchpad.
   - **Running agent session** (another terminal, an Orca pane, tmux) — only a session the user named. Run the pre-send check below, write the prompt to a file inside the **target repo** (its docs convention; none → `docs/BRIEF.md`), send exactly one line — `Read <absolute path> and carry it out.` — through the `session-relay` skill (Claude → Claude: `SendMessage`; any leg with Codex: Orca mail), and report the file path with the delivery evidence that skill names (stored / started / answered).
   - Never write the prompt to the sending repo's `_docs/` — a throwaway prompt would pollute the docs lifecycle.

### Pre-send check (running agent session)

Read the receiving session's **working directory**, **permission mode**, and **writable scope** before sending. When the working directory is not the target repo, or the mode skips approval prompts (`bypassPermissions`, YOLO, full-auto), the prompt MUST carry a **Boundaries** section:

- the only write location (absolute path), and that the working directory it started in is read-only;
- read-only sources (absolute paths) and the git commands that change state that are forbidden there;
- external services, databases, running containers, and ports it must not touch;
- what it may never do without the user: push, add a remote, open a PR, deploy, install system software.

## Target tuning

| Target | Tuning |
|--------|--------|
| Fresh agentic session / another Claude Code | Dense, no length cap; point at real repo paths and existing patterns. Step 5 blocks apply. |
| Running agent session (Orca, tmux, another CLI) | Same as above, delivered as a file + one-line send (step 6) with the pre-send check. |
| `/team-run "…"` task string | One tight imperative paragraph — goal + constraints + done-condition. |
| Subagent prompt | Fully self-contained; add a structured output schema when a downstream gate consumes a field. |
| Plain chatbot (ChatGPT / Claude.ai) | ≤ ~4000 chars, no repo assumptions, everything the model needs inlined. |
| Image-gen / research | Short visual descriptors, or a framed research question with scope bounds. |

The ~4000-char figure is a **chatbot guide, not a universal cap** — an agentic target has no structural reason to be truncated.

## Related

- `brainstorm` skill — the questioning discipline (Unknowns-First, success criteria) borrowed here; use it directly when the goal is an **approved design** that flows into implementation.
- `handoff` skill — passes **live work state** (done / left / how to resume) to another session, not a from-scratch prompt.
- `session-relay` skill — the send route and delivery evidence for step 6.

ARGUMENTS: $ARGUMENTS
