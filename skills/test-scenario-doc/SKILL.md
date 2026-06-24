---
name: test-scenario-doc
description: >-
  Generate a self-contained, interactive HTML test-scenario / QA checklist document — grouped
  scenarios with checkable steps, pass/fail/hold verdicts, a sticky progress bar, localStorage
  auto-save, a copyable markdown summary, an image-embedded HTML result report, and per-scenario
  screenshot attachment (file picker + clipboard paste). Use this whenever the user wants a manual
  test plan, QA checklist, regression-test doc, acceptance/smoke test scenarios, a "테스트 시나리오
  문서", release verification steps, or any structured way to track manual verification of a feature,
  bug fix, or merge — even if they only say "track what to test", "make a QA checklist", or "write
  test scenarios" without naming this format. Prefer this over hand-writing a one-off HTML each time.
---

# Test Scenario Doc

Produces **one self-contained `.html` file** a human opens in a browser to run a manual test pass:
grouped scenario cards, each with checkable steps, a 통과/실패/보류 (pass/fail/hold) verdict, a free-text
note, and a **screenshot drop** (attach a file *or* paste from clipboard). Progress and every input
auto-save to `localStorage`, so the tester can close and reopen without losing work. Two export
buttons: a copyable markdown summary, and an **image-embedded HTML report** for sharing results
(verdicts + notes + screenshots in one file) — because `localStorage` can't be shared.

No build step, no server, no dependencies. Works offline by double-clicking the file.

## How to build one

1. **Copy the template** `assets/test-scenarios-template.html` to the destination (ask the user where,
   or default to `docs/` in a repo / the cwd). A good name encodes topic + version, e.g.
   `docs/checkout-regression-test-scenarios.html`.
2. **Edit ONLY the `<script id="ts-config">` block.** Everything else (CSS, render runtime, image
   handling, exports) is fixed and tested — leave it alone. The config block holds `META`, `LABELS`
   (optional), `MODE_LABEL`, `GROUPS`, `SETUP_HTML`, and `SCENARIOS`. Replace the example values with
   the real test pass.
3. Hand the user the file path and tell them they can open it directly (`file://…`) and that progress
   is saved per `storageKey`.

The template ships with a tiny working example so you can see the exact shapes. Mirror them.

## The config data model

```js
const META = {
  title: 'Checkout · <span style="color:var(--accent)">회귀 테스트</span>', // header (HTML ok)
  subtitle: '...한 줄 설명 · 작성 2026-06-24',
  storageKey: 'ts:checkout-regression:v1',  // see "Versioning" below — MUST be unique per doc
  exportTitle: '# 체크아웃 회귀 결과',        // markdown export heading
};
const LABELS = {};            // omit for Korean defaults; override per key for other languages
const MODE_LABEL = { S:'스모크', R:'회귀', E:'엣지' };  // tag id → pill label; colors auto-assigned
const GROUPS = [ { id:'g1', title:'G1. 결제 흐름', lead:'한 줄 설명(선택)' } ];
const SETUP_HTML = `<h2>환경</h2><table>...</table>`;   // optional intro (env, rules); '' to omit
const SCENARIOS = [ /* cards — see fields below */ ];
```

Each scenario:

| field | required | what it is |
|---|---|---|
| `id` | ✓ | short code shown in the chip — `S1`, `R3`, `C2`. Keep them short and scannable. |
| `group` | ✓ | one of `GROUPS[].id` |
| `mode` | – | one of `MODE_LABEL` keys → a colored pill (test type) |
| `title` | ✓ | what this scenario verifies (the headline) |
| `edge` | – | tiny mono caption: the area/dependency/fix/commit under test |
| `pre` | – | precondition / setup before the steps |
| `steps` | ✓ | array of action strings; each renders as a checkable line |
| `expect` | ✓ | what PASS looks like — concrete and observable |
| `fail` | – | the symptom if it fails — concrete |
| `ref` | – | code/commit/issue pointer |

## Writing scenarios that are actually useful

The whole value is that a tester (often not the author) can follow each card without guessing. So:

- **One observable behavior per card.** If the title needs "and", split it. A card the tester can mark
  pass/fail unambiguously is worth three vague ones.
- **Steps are concrete actions in order** — "검색창에 빈 값으로 Enter", not "test empty search". The
  tester should be able to do exactly what you wrote.
- **`expect` / `fail` must be checkable** — name the real button label, route, number, or message. "Cat.1
  = 납품량 × 배출계수 (0 아님)" beats "calculation is correct". When you know the actual UI string from
  the code or the conversation, use it verbatim; it removes ambiguity and doubles as a regression anchor.
- **Ground it in reality, don't invent.** Pull routes, labels, fixture values, commit hashes from the
  codebase or the current conversation. If a detail is genuinely unknown, write the step at the level you
  do know and say what to confirm — never fabricate a precise-looking value you can't back up. If the doc
  is for verifying work that just happened in this session, mine that history (what changed, what the user
  reported) for the scenarios.
- **Group by intent** (smoke / regression / new-feature / edge / locale), and use `mode` pills for the
  test *type*. Lead each group with one orienting sentence.
- **Put environment + ground rules in `SETUP_HTML`** (URLs, login, "refresh-then-enter to repro cold
  load", "input = real click+type, not console") so the tester has everything in one page. Use the note
  boxes: `<div class="note amber|blue|green">…</div>`.

## Versioning (re-test rounds)

When the same feature is re-tested after fixes/changes, make a **new file** (`…-ver2.html`) and bump
`storageKey` (`:v2`) so it doesn't share saved state with the previous round. Carry over only what still
needs checking: **drop already-passed scenarios**, keep failures/holds for re-verification, and add new
ones for whatever changed. A short "vs previous round" table at the top (what was excluded, what's new)
helps the tester trust the doc.

## Screenshots (built in — nothing to wire)

Every scenario card has an image row: **파일 첨부** (file picker, multi-select) and a **paste zone**
(click it, then Ctrl+V to drop a clipboard screenshot). Images are downscaled (max 1600px, JPEG) and
stored in `localStorage` with the rest of the state, shown as thumbnails (click to zoom, × to remove).
The **이미지 포함 결과 HTML** button downloads a standalone report with verdicts, notes, and embedded
screenshots — that's how a tester shares results, since `localStorage` stays in their browser.

You don't configure any of this; it's part of the fixed runtime. Just mention it exists when you hand
over the file.

## Language

UI chrome (chip labels, buttons, the `통과/실패/보류` verdicts, export text) defaults to **Korean**.
For a non-Korean doc, override `LABELS` (e.g. `{ pass:'Pass', fail:'Fail', hold:'Hold', exportBtn:'Copy
summary', … }`); any key you omit falls back to the Korean default. Match the scenario *content* language
to the testers.

## Gathering the scenarios

If the user pointed at a feature/PR/bug, derive scenarios from it (read the diff/spec, or the
conversation history if the work happened here). If the scope is fuzzy, ask what areas matter and what
"done" looks like before filling the template — a handful of sharp, grounded scenarios beats a long
generic list.
