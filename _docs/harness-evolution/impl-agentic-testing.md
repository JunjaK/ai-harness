---
title: Agentic Testing 레이어 — 구현 계획
status: processing
scope: harness
created: 2026-06-23
updated: 2026-06-23
related: [_docs/harness-evolution/plan-agentic-testing.md]
---

# Agentic Testing 레이어 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 결정적 E2E 통과 후 도는 *탐색적 목표검증 + 결정적 테스트 생성* 레이어(Phase 4.5)를, 스택 무관 어댑터와 모드 인식 오케스트레이션으로 하네스에 편입한다.

**Architecture:** 2단계 파이프라인(Explorer→Generator)을 골격으로, 표면/스택은 `project-profile`에서 감지해 드라이버·에미터·동시성 어댑터를 주입한다(base=web/TS). 오케스트레이션 모드(표준=단일 에이전트 / ultracode=Workflow 팬아웃)는 최상위 오케스트레이터가 결정한다.

**Tech Stack:** Claude Code 스킬/에이전트 마크다운, Playwright MCP(`mcp__plugin_playwright_playwright__*`), Workflow 도구(`agent/parallel/pipeline/phase/log/budget`), `project-analyzer` 프로필 시스템.

**산출물 성격 주의:** 이 계획의 태스크는 대부분 **마크다운 저작**(스킬/에이전트/문서)이다. 따라서 표준 TDD "실패 테스트→구현→통과" 대신 **(1) 계약에 맞춰 저작 → (2) 구조 검증(필수 섹션/등록/교차링크 존재 + 모순 없음) → (3) 커밋** 패턴을 쓴다. 실행 가능한 코드(예: ultracode Workflow 스크립트)는 예시/문서로만 존재하며 독립 단위테스트 대상이 아니다.

## Global Constraints

- **리터럴 지시(Opus 4.7/4.8):** 모든 규칙은 MUST-style. "keep it simple/when appropriate/as needed" 같은 모호한 수식어 금지 — 구체 조건·정량 기준으로 작성. (CLAUDE.md §1)
- **link don't duplicate:** 새 스킬은 기존 스킬(`e2e-testing`·`springboot-tdd`·`kotlin-testing`·`verification-loop`)을 **링크**로 참조; 내용 복제 금지.
- **base 어댑터 = web/TS** (Playwright MCP / `.spec.ts` / `e2e-testing` house-style). Spring-Kotlin·Flutter는 1급 어댑터.
- **ultracode 신호 = 내장 모드에 정렬.** `CLAUDE_HARNESS_ULTRACODE=1` env는 헤드리스/비-Claude-Code용 **선택적 override**로만. effort(`max`)와 오케스트레이션 토폴로지는 분리.
- **모드 스위치는 오케스트레이션 레이어:** 스킬·스폰된 서브에이전트는 `workflow()`/`pipeline()`을 호출할 수 없다. Workflow 도구는 최상위 오케스트레이터만 호출. `agents/team-agentic-tester.md`는 표준 모드 실행기.
- **신규 update command 금지:** 기존 `/team-init --update` 를 staleness 감지로 **강화**.
- **project-profile 하드 선행조건:** 프로필 없으면 ABORT. 어댑터는 `stack.md`+`testing.md`에서 결정.
- **에이전트 모델:** `team-agentic-tester` = `model: opus`, effort `xhigh`(self-repair 2회 실패 시에만 `max`).
- **`_docs/**` 문서:** `docs-lifecycle` YAML frontmatter(`title/status/scope/created/updated/related`) + `index.md` 동시 갱신.
- **커밋:** main에서 직접 진행(사용자 승인). 태스크당 1커밋. 메시지 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

# Phase A — Agentic Testing 레이어 (표준 모드, 독립 출하 가능)

> Phase A 완료 시점 = 표준 모드 agentic-testing이 동작하는 마일스톤(ultracode 없이도 가치 출하).

### Task A1: 프로필에 "Agentic Testing Adapter" 섹션 + 생성시점 HEAD 기록

어댑터 해석의 SSOT를 프로필에 심는다. 이후 모든 태스크가 이 계약에 의존한다.

**Files:**
- Modify: `skills/project-analyzer/SKILL.md` (Step 6 §"Analyze Testing", Step 9 §"Generate Index")
- Modify: `skills/project-analyzer/resources/profile-templates.md` (§6 testing.md 템플릿, §9 index.md 템플릿)

**Interfaces:**
- Produces (이후 태스크가 의존하는 계약):
  - `testing.md` 에 **"## Agentic Testing Adapter"** 섹션. 필수 필드 4개:
    - `Surface: web | backend | mobile` (감지: `stack.md` 언어/프레임워크)
    - `Driver: playwright-mcp | http | maestro|patrol|mobile-mcp`
    - `Emitter house-style: <skill name>` (web→`e2e-testing`, backend-kotlin→`springboot-tdd`+`kotlin-testing`, flutter→`integration_test` 규약)
    - `Concurrency: serial-shared-browser | parallel-stateless | serial-per-device`
  - `index.md` 에 **`Profile-Generated-At: <git HEAD short sha>`** 라인(생성/갱신 시 기록).

- [ ] **Step 1: `project-analyzer` Step 6 확장**

`skills/project-analyzer/SKILL.md` 의 "### Step 6: Analyze Testing → `testing.md`" 본문에 다음 지시를 추가:

```markdown
Additionally, derive the **Agentic Testing Adapter** for `testing.md` (template §6):
- Surface: `web` if a browser UI (React/Vue/Svelte/Angular/Next…); `backend` if API-only (Spring/Express/FastAPI…); `mobile` if Flutter/React-Native.
- Driver / Emitter / Concurrency: fill per the Adapter table in `agentic-testing` SKILL.
- If Surface=mobile and no mobile driver (maestro/Patrol/mobile-MCP) is detectable, set `Driver: UNAVAILABLE` and note it.
```

- [ ] **Step 2: `profile-templates.md` §6 에 어댑터 블록 추가**

`resources/profile-templates.md` §6(testing.md 템플릿) 끝에 추가:

```markdown
## Agentic Testing Adapter
- Surface: <web | backend | mobile>
- Driver: <playwright-mcp | http | maestro | patrol | mobile-mcp | UNAVAILABLE>
- Emitter house-style: <e2e-testing | springboot-tdd + kotlin-testing | integration_test>
- Concurrency: <serial-shared-browser | parallel-stateless | serial-per-device>
- Generated spec dir: <tests/e2e/ | src/test/ | integration_test/>
```

- [ ] **Step 3: index 템플릿에 생성시점 HEAD 추가**

`project-analyzer` Step 9 + `profile-templates.md` §9(index.md 템플릿)에 `Last updated` 옆에 한 줄 추가:

```markdown
Profile-Generated-At: <current git HEAD short sha>
```

- [ ] **Step 4: 구조 검증**

Run:
```bash
grep -n "Agentic Testing Adapter" skills/project-analyzer/SKILL.md skills/project-analyzer/resources/profile-templates.md
grep -n "Profile-Generated-At" skills/project-analyzer/SKILL.md skills/project-analyzer/resources/profile-templates.md
```
Expected: 양쪽 파일 모두 두 토큰이 매칭(섹션 + 템플릿).

- [ ] **Step 5: Commit**

```bash
git add skills/project-analyzer/SKILL.md skills/project-analyzer/resources/profile-templates.md
git commit -m "feat(profile): add Agentic Testing Adapter section + generated-at HEAD"
```

---

### Task A2: `/team-init --update` staleness 감지 강화

**Files:**
- Modify: `commands/team-init.md` (§"Update Mode")

**Interfaces:**
- Consumes: `Profile-Generated-At` (A1).
- Produces: `--update` 가 (a) HEAD drift 감지 (b) 어댑터 섹션 누락 감지 → 갱신 트리거.

- [ ] **Step 1: Update Mode 본문 확장**

`commands/team-init.md` 의 "## Update Mode" 에 다음을 추가:

```markdown
### Staleness Detection (MUST)
On `--update`, before rescanning:
1. Read `Profile-Generated-At` from `index.md`. Compare to current `git rev-parse --short HEAD`.
2. If the profile is missing the "Agentic Testing Adapter" section (older profile), force a `testing.md` rescan.
3. Report drift: "Profile generated at <sha>, HEAD now <sha> (<N> commits behind)". Regenerate changed sections and rewrite `Profile-Generated-At`.
```

- [ ] **Step 2: 구조 검증**

Run: `grep -n "Staleness Detection\|Profile-Generated-At" commands/team-init.md`
Expected: 두 토큰 매칭.

- [ ] **Step 3: Commit**

```bash
git add commands/team-init.md
git commit -m "feat(team-init): staleness detection on --update (HEAD drift + adapter section)"
```

---

### Task A3: `skills/agentic-testing/SKILL.md` (방법론 본체 — 표준 모드 완전 정의 + ultracode 문서화)

**Files:**
- Create: `skills/agentic-testing/SKILL.md`

**Interfaces:**
- Consumes: 프로필 어댑터 계약(A1).
- Produces (team-agentic-tester·team-workflow 가 의존):
  - 선행조건 게이트(profile 필수 + staleness) — ABORT 조건.
  - 어댑터 해석 규칙(Surface→Driver/Emitter/Concurrency).
  - goal 유도 규칙(수용기준→outcomes-not-steps, 위험 우선) + 실행-여부 게이트(value/time/noise).
  - 2단계 파이프라인 계약 + self-repair(≤2, 비-green 폐기).
  - 모드 결정 규칙(4불리언 AND) — 표준/ultracode.
  - 출력 리포트 포맷(goal별 met/trustworthy/green/spec-path).

- [ ] **Step 1: frontmatter + 원칙 배너 작성**

```markdown
---
name: agentic-testing
description: "Agentic E2E testing layer (Phase 4.5). Use AFTER deterministic E2E passes and BEFORE human final review. An agent explores a goal via the stack's UI/API driver, verifies goal achievement, and crystallizes the path into a deterministic test. Stack-agnostic via project-profile adapters (web/TS base, Spring-Kotlin, Flutter)."
---

# Agentic Testing

> **Tests enforce journeys. Agents verify goals. Explore once, regress forever.**
> Position: **Phase 4.5** — after `team-tester` Phase 4 = PASS, before Phase 5. Complements (never replaces) deterministic E2E.
```

- [ ] **Step 2: 하드 선행조건 섹션 작성**

필수 규칙 verbatim:
```markdown
## Precondition (MUST — abort if unmet)
1. MUST read `.claude/project-profile/{index.md, stack.md, testing.md}`. If absent → ABORT: "Run /team-init first."
2. MUST read `testing.md` → "Agentic Testing Adapter". If missing → require `/team-init --update`.
3. Staleness: if `Profile-Generated-At` is far behind HEAD → require `/team-init --update` before running.
```

- [ ] **Step 3: 어댑터 해석 표 작성** (spec §4.1 표를 그대로 — web/backend/flutter 행, Driver/Emitter/Concurrency 열, mobile driver 부재 시 문서화+스킵 규칙 포함).

- [ ] **Step 4: goal 유도 + 실행 게이트 작성**

```markdown
## Goal derivation
- Source: plan/spec acceptance criteria. Express as OUTCOMES (not UI steps), risk-ordered (auth/payment/data first).
## Run-at-all gate (autonomous, NOT dollar-gated)
Run a goal only if ALL hold; else log skip reason:
- VALUE: no overlap with an existing passing test for this flow.
- TIME: bounded steps (~25) and target reachable.
- NOISE: deterministically assertable (subjective/aesthetic → defer to web-reviewer / impeccable).
```

- [ ] **Step 5: 2단계 파이프라인 + self-repair 작성**

```markdown
## Pipeline (Explorer → Generator)
1. Explorer (Sonnet + adapter driver): goal→adapt→verify; record met?, observed path, evidence.
2. Generator (Opus): crystallize path via the emitter house-style skill → RUN the generated test → keep only if green (self-repair ≤2, else DISCARD). met=false → no spec, escalate to human.
Generated tests MUST obey the emitter skill's conventions (e.g. e2e-testing: getByRole>...>getByTestId, waitForResponse/waitFor never waitForTimeout).
```

- [ ] **Step 6: 모드 결정 규칙 + ultracode 문서 섹션 작성** (spec §4.3 표 + selectMode 4불리언 규칙 verbatim. ultracode 상세 동작은 Phase B에서 본문 확정 — 여기서는 "standard fully specified; ultracode summarized + see Ultracode Orchestration" 로 작성).

- [ ] **Step 7: 출력 리포트 포맷 + 교차참조 작성**

```markdown
## Report format (extends team-tester report)
Per goal: id, outcome, met, trustworthy (ultracode verify), green, specPath|null, skipReason|null.
Sections: Verified+crystallized / Verified-not-crystallizable / Unmet (human escalation) / Distrusted verdicts.
## See also (link, do not duplicate)
- skills/e2e-testing/SKILL.md (web emitter conventions)
- skills/verification-loop/SKILL.md (vacuity guard — applied to "met" claims)
- skills/team-workflow/SKILL.md (Phase 4.5 + Orchestration Mode)
```

- [ ] **Step 8: 구조 검증**

Run:
```bash
test -f skills/agentic-testing/SKILL.md && \
grep -c "MUST\|Phase 4.5\|Explorer\|Generator\|Precondition\|selectMode\|Adapter" skills/agentic-testing/SKILL.md
```
Expected: 파일 존재 + 핵심 토큰 다수 매칭.

- [ ] **Step 9: Commit**

```bash
git add skills/agentic-testing/SKILL.md
git commit -m "feat(skill): add agentic-testing methodology (adapters, pipeline, precondition, modes)"
```

---

### Task A4: `agents/team-agentic-tester.md` (표준 모드 실행기)

**Files:**
- Create: `agents/team-agentic-tester.md`

**Interfaces:**
- Consumes: `agentic-testing` 스킬(A3), 어댑터 house-style 스킬, `team-tester` 리포트.
- Produces: `subagent_type: team-agentic-tester` 로 team-workflow 가 dispatch 하는 표준 모드 실행기.

- [ ] **Step 1: frontmatter + 역할 작성**

```markdown
---
name: team-agentic-tester
model: opus
description: "Agentic testing specialist (Phase 4.5). Standard-mode executor: explores goals via the project's adapter driver, verifies goal achievement, and crystallizes deterministic tests. Runs after team-tester PASS, before Phase 5."
---

# Role
Top-of-pyramid agentic tester. Unifies (1) exploratory goal-verification gate and (2) deterministic test generator. Standard-mode (sequential) executor; ultracode mode is run by the orchestrator via the Workflow tool, not by this agent.
```

- [ ] **Step 2: MUST-read + 선행조건 첫 스텝 작성**

```markdown
## Before starting (MUST, in order)
1. Invoke the `agentic-testing` skill. Enforce its Precondition gate (profile present + adapter section + not stale) — ABORT per skill if unmet.
2. MUST read: project-profile {index, stack, testing}, plan doc (acceptance criteria), team-tester verification report, and the emitter house-style skill named in `testing.md`.
```

- [ ] **Step 3: 7-step 표준 루프 작성**

```markdown
## Standard-mode loop (per goal, sequential)
1. Derive goals from acceptance criteria (outcomes, risk-ordered).
2. Apply run-at-all gate (value/time/noise); log skips.
3. Explorer pass via adapter driver (Sonnet effort); record met/path/evidence.
4. If met=false → escalate (human), no spec.
5. Generator pass: emit deterministic test via house-style skill.
6. Run the generated test; self-repair ≤2; discard if not green.
7. Emit report (skill format).
```

- [ ] **Step 4: 에스컬레이션 + 출력 포맷 작성** (`team-tester` 에스컬레이션 포맷 재사용: Simple=셀렉터/wait drift; Fundamental=목표 도달 불가/구현 결함. 출력은 `agentic-testing` 리포트 포맷).

- [ ] **Step 5: 구조 검증**

Run:
```bash
grep -n "model: opus\|agentic-testing\|Precondition\|Standard-mode" agents/team-agentic-tester.md
```
Expected: 매칭.

- [ ] **Step 6: Commit**

```bash
git add agents/team-agentic-tester.md
git commit -m "feat(agent): add team-agentic-tester standard-mode executor"
```

---

### Task A5: 포인터 + 등록 (e2e-testing / team-tester 포인터, CLAUDE.md·README 표)

**Files:**
- Modify: `skills/e2e-testing/SKILL.md` (상단 포인터 1줄)
- Modify: `agents/team-tester.md` (Phase 4 §5 후, Phase 4.5 인계 1줄)
- Modify: `CLAUDE.md` (Skills 표 + Agents 표 행 추가)
- Modify: `README.md` (해당 표 행 추가)

**Interfaces:**
- Consumes: A3·A4(스킬/에이전트 이름).
- Produces: 하네스 문서에서 새 스킬/에이전트 발견 가능.

- [ ] **Step 1: e2e-testing 포인터**

`skills/e2e-testing/SKILL.md` 상단 소개 문단 아래 추가:
```markdown
> This is the **deterministic** layer. For the exploratory goal-verification + test-generation layer above it, see `agentic-testing` (Phase 4.5).
```

- [ ] **Step 2: team-tester 인계 줄**

`agents/team-tester.md` "### 5. Full Test Suite — FINAL GATE" 끝에 추가:
```markdown
> On PASS, the orchestrator may invoke **Phase 4.5 agentic testing** (`team-agentic-tester`) before Phase 5. team-tester does not run it.
```

- [ ] **Step 3: CLAUDE.md 표 행 추가**

Agents 표에:
```markdown
| team-agentic-tester | Opus 4.8 | Phase 4.5 agentic testing (explore-gate + test generator) |
```
Skills 표에:
```markdown
| agentic-testing | Phase 4.5 | Adapter-based agentic E2E: explore goal → verify → crystallize deterministic test |
```

- [ ] **Step 4: README.md 동일 행 추가** (해당 Agents/Skills 표 위치).

- [ ] **Step 5: 구조 검증**

Run:
```bash
grep -rn "team-agentic-tester\|agentic-testing" CLAUDE.md README.md skills/e2e-testing/SKILL.md agents/team-tester.md
```
Expected: 4개 파일 모두 매칭.

- [ ] **Step 6: Commit**

```bash
git add skills/e2e-testing/SKILL.md agents/team-tester.md CLAUDE.md README.md
git commit -m "docs: register agentic-testing skill + team-agentic-tester agent; cross-link e2e layers"
```

---

### Task A6: team-workflow 에 Phase 4.5 배선 (표준 모드 dispatch)

**Files:**
- Modify: `skills/team-workflow/SKILL.md` (Phase 4 종료 후 Phase 4.5 삽입)
- Modify: `skills/team-workflow/resources/agents.md` (있으면 team-agentic-tester 행 추가)

**Interfaces:**
- Consumes: A4(team-agentic-tester), A3(precondition).
- Produces: Phase 4 PASS 조건부로 team-agentic-tester 를 dispatch 하는 오케스트레이션 훅(표준 모드).

- [ ] **Step 1: Phase 4.5 단계 작성**

team-workflow Phase 4 → Phase 5 사이에:
```markdown
### Phase 4.5: Agentic Testing (conditional)
Trigger: Phase 4 = PASS AND a user-facing flow changed.
1. Enforce `agentic-testing` precondition (profile present/fresh). If unmet → instruct /team-init, skip Phase 4.5 (non-blocking).
2. STANDARD mode: dispatch `subagent_type: team-agentic-tester` (sequential).
3. Consume its report: unmet/distrusted goals → escalate; green specs join the deterministic suite.
(Ultracode mode path: see "Orchestration Mode" — Phase B.)
```

- [ ] **Step 2: agents.md 행 추가**(파일 존재 시).

- [ ] **Step 3: 구조 검증**

Run: `grep -n "Phase 4.5\|team-agentic-tester" skills/team-workflow/SKILL.md`
Expected: 매칭.

- [ ] **Step 4: Commit**

```bash
git add skills/team-workflow/SKILL.md skills/team-workflow/resources/agents.md
git commit -m "feat(team-workflow): wire Phase 4.5 agentic testing (standard-mode dispatch)"
```

---

### Task A7: Phase A 검증 — 구조 일관성 + 드라이런 런북

> in-repo 실행 가능한 웹 앱이 없으므로, 구조 검증 + 실제 프로젝트용 드라이런 절차 문서화로 acceptance 한다(가짜 테스트 실행 금지).

**Files:**
- Modify: `skills/agentic-testing/SKILL.md` (말미에 "## Dry-run acceptance runbook" 추가)

- [ ] **Step 1: 교차참조 무결성 검사**

Run:
```bash
for f in agentic-testing e2e-testing verification-loop team-workflow; do test -f "skills/$f/SKILL.md" && echo "OK $f"; done
grep -n "agentic-testing" skills/team-workflow/SKILL.md CLAUDE.md README.md
```
Expected: 4개 스킬 OK + 참조 매칭(끊긴 링크 없음).

- [ ] **Step 2: 선행조건 ABORT 로직 리뷰**

`agentic-testing` SKILL 의 Precondition 이 "profile 없음 → ABORT", "어댑터 섹션 없음 → /team-init --update" 를 MUST-style로 명시하는지 육안 확인(체크박스).

- [ ] **Step 3: 드라이런 런북 작성** (실제 프로젝트에서 실행할 절차)

```markdown
## Dry-run acceptance runbook (run in a real web/TS project)
1. /team-init → confirm testing.md has Agentic Testing Adapter (Surface: web).
2. Pick one existing user-facing flow with acceptance criteria.
3. Standard mode: dispatch team-agentic-tester.
4. Confirm: (a) goal-verification report produced; (b) a generated *.spec.ts re-runs GREEN deterministically.
5. Negative: rename .claude/project-profile → confirm ABORT with "Run /team-init first."
```

- [ ] **Step 4: Commit**

```bash
git add skills/agentic-testing/SKILL.md
git commit -m "docs(agentic-testing): add dry-run acceptance runbook; close Phase A"
```

---

# Phase B — Ultracode → Workflow 오케스트레이션 (A 위에 적층)

### Task B1: CLAUDE.md "Ultracode Orchestration" 섹션 + env override + README

**Files:**
- Modify: `CLAUDE.md` (신규 "## Ultracode Orchestration" 섹션 + 내장 커맨드 표/env 컨텍스트)
- Modify: `README.md` (`CLAUDE_HARNESS_ULTRACODE` env 를 `AGENT_TEAMS` 옆에)

**Interfaces:**
- Produces: ultracode 신호 정의 + "ultracode→Workflow 우선" MUST 원칙(가드 포함). B2/B3 가 참조.

- [ ] **Step 1: 원칙 섹션 작성** — spec §6 의 MUST-style 문안을 그대로 삽입(명시 팬아웃 4지점, max-5-worktree·머지순서 override, 사용 금지 목록, **비-ultracode 가드**).

- [ ] **Step 2: env 정의** — `CLAUDE_HARNESS_ULTRACODE=1` 를 선택적 override로, effort≠topology 주석과 함께. README 동기화.

- [ ] **Step 3: 구조 검증**

Run: `grep -n "Ultracode Orchestration\|CLAUDE_HARNESS_ULTRACODE\|MUST NOT be used\|not in ultracode" CLAUDE.md README.md`
Expected: 매칭(특히 비-ultracode 가드 문구).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "feat(harness): add Ultracode Orchestration principle + CLAUDE_HARNESS_ULTRACODE override"
```

---

### Task B2: team-workflow "Orchestration Mode" preamble + ultracode Phase 4.5 경로

**Files:**
- Modify: `skills/team-workflow/SKILL.md`

**Interfaces:**
- Consumes: B1(신호/원칙), A6(Phase 4.5 표준 경로).
- Produces: 모드 1회 판독 preamble + Phase 4.5 ultracode 분기(오케스트레이터가 Workflow 실행).

- [ ] **Step 1: Orchestration Mode preamble 작성** (기존 "Pre-Flight: Project Profile Check" 형제로):

```markdown
## Orchestration Mode (read once)
selectMode: ULTRACODE iff workflow() callable AND ultracode active (built-in signal or CLAUDE_HARNESS_ULTRACODE=1) AND the step has 2+ independent units; else STANDARD. Record the mode in the plan's Orchestration field. Workflow unavailable → STANDARD (hard fallback).
```

- [ ] **Step 2: Phase 4.5 ultracode 분기 추가** — A6 의 Phase 4.5 블록에 분기:
```markdown
3'. ULTRACODE mode: orchestrator invokes the agentic-testing Workflow pipeline (Explorer→Generator pipeline, adapter concurrency policy, perspective-diverse verdict verify, ≤2 completeness-critic rounds). Shared Playwright MCP browser → Explorer lane serialized.
```

- [ ] **Step 3: 구조 검증**

Run: `grep -n "Orchestration Mode\|selectMode\|ULTRACODE" skills/team-workflow/SKILL.md`
Expected: 매칭.

- [ ] **Step 4: Commit**

```bash
git add skills/team-workflow/SKILL.md
git commit -m "feat(team-workflow): Orchestration Mode preamble + ultracode Phase 4.5 path"
```

---

### Task B3: 검증된 4개 팬아웃 (team-workflow + team-leader)

**Files:**
- Modify: `skills/team-workflow/SKILL.md` (Phase 1 아키텍처 / Phase 3 디자이너+머지 / Phase 4 테스터별 — ultracode 조건부 팬아웃)
- Modify: `agents/team-leader.md` (Orchestration Strategy 결정 + Plan Output "Orchestration" 필드)

**Interfaces:**
- Consumes: B1·B2.
- Produces: ultracode 시 Phase 1/3/4 가 `parallel`/`pipeline` 로 실행됨을 명시(가드: 비-ultracode면 현행 경로; max-5-worktree·머지순서 유지).

- [ ] **Step 1: team-workflow 3개 팬아웃 지점에 ultracode 분기 작성** (각 지점에 "ULTRACODE: parallel/pipeline … ; else current Agent/TeamCreate path" 한 단락씩. Phase 3 는 worktree 격리 + types→backend→frontend→tests 머지 순서 유지 명시).

- [ ] **Step 2: team-leader 에 Orchestration Strategy 작성** (Team Sizing 옆 결정 + Plan Output Format 에 `Orchestration: standard|ultracode` 필드).

- [ ] **Step 3: 구조 검증**

Run: `grep -n "ULTRACODE\|Orchestration\|parallel\|pipeline\|merge order" skills/team-workflow/SKILL.md agents/team-leader.md`
Expected: 3개 팬아웃 지점 + team-leader 필드 매칭.

- [ ] **Step 4: Commit**

```bash
git add skills/team-workflow/SKILL.md agents/team-leader.md
git commit -m "feat(orchestration): ultracode fan-outs for Phase 1/3/4 + team-leader strategy"
```

---

### Task B4: agentic-testing 스킬 ultracode 섹션 확정 + Workflow 스케치 참조

**Files:**
- Modify: `skills/agentic-testing/SKILL.md` (A3 Step 6 의 ultracode 요약을 본문으로 확정)

**Interfaces:**
- Consumes: B1·B2.
- Produces: ultracode 동작(파이프라인 형태·동시성·verify·critic)의 단일 출처.

- [ ] **Step 1: ultracode 섹션 작성** — spec §4.4 의 어댑터-파라미터화 Workflow 스케치(요약형)와 동시성 정책(web 직렬 / backend 병렬 / mobile 디바이스당)을 본문에 명시. `workflow()` 1단계 중첩 한계 → critic 은 파이프라인 재귀 주석.

- [ ] **Step 2: 구조 검증**

Run: `grep -n "ultracode\|pipeline\|serial-shared-browser\|parallel-stateless\|completeness-critic" skills/agentic-testing/SKILL.md`
Expected: 매칭.

- [ ] **Step 3: Commit**

```bash
git add skills/agentic-testing/SKILL.md
git commit -m "feat(agentic-testing): finalize ultracode pipeline section + adapter concurrency"
```

---

### Task B5: Phase B 검증 — 가드·일관성 + 문서 상태 전이

**Files:**
- Modify: `_docs/harness-evolution/plan-agentic-testing.md` + `impl-agentic-testing.md` (status 전이) — 또는 docs-lifecycle 머지(완료 시).

- [ ] **Step 1: 비-ultracode 가드 일관성 검사**

Run:
```bash
grep -rn "not in ultracode\|else.*STANDARD\|current.*Agent\|MUST NOT be used" CLAUDE.md skills/team-workflow/SKILL.md skills/agentic-testing/SKILL.md
```
Expected: 모든 팬아웃/원칙에 비-ultracode 폴백 가드 존재.

- [ ] **Step 2: override 규칙 일관성** — max-5-worktree·머지순서 override 가 CLAUDE.md 원칙과 team-workflow Phase 3 에서 동일하게 진술되는지 육안 확인.

- [ ] **Step 3: 문서 상태 전이** — 구현 시작 시 `planning → processing`(docs-lifecycle), 완료·검증 후 merge 규칙으로 `complete/`. `_docs/index.md` 동기화.

- [ ] **Step 4: Commit**

```bash
git add _docs/
git commit -m "docs(agentic-testing): Phase B verification + lifecycle transition"
```

---

## Self-Review (작성자 체크)

**1. Spec coverage** — spec 섹션 → 태스크 매핑:
- §4.0 선행조건 → A3 Step2, A4 Step2, A7 Step2 ✅
- §4.1 어댑터(3면) → A1, A3 Step3 ✅
- §4.2 파이프라인+self-repair → A3 Step5, A4 Step3 ✅
- §4.3 모드/신호/결정규칙 → A3 Step6, B1, B2 ✅
- §4.4 ultracode 스케치 → B4 ✅
- §5 컴포넌트(신규2/수정6) → A1–A6, B1–B4 ✅
- §6 롤아웃 4팬아웃+원칙 → B1, B3 ✅
- §8 산출물 위치 → A3 Step7(리포트), A1(spec dir) ✅
- §9 검증 → A7(런북), B5 ✅
- §10 후속(모바일 드라이버 표준 등) → 명시적 비범위(후속) ✅

**2. Placeholder scan** — 모든 코드/구조 스텝에 실제 명령·verbatim 규칙 포함. 마크다운 본문 저작 태스크는 "필수 섹션+계약+verbatim 핵심 규칙"으로 명세(설계 산출물 성격상 전체 산문 복제는 비현실적 → 계약 altitude). placeholder 없음 ✅

**3. Type/이름 일관성** — `team-agentic-tester`(에이전트), `agentic-testing`(스킬), `Agentic Testing Adapter`(프로필 섹션), `Profile-Generated-At`(필드), `selectMode`(규칙), `Phase 4.5`(위치) — 전 태스크에서 동일 명칭 사용 ✅

**보완 발견 → 반영:** A7 은 in-repo 앱 부재로 "런북 문서화 + 구조검증"으로 acceptance(실행형 테스트 가짜 작성 회피) — Global Constraints 의 "evidence over assumptions" 와 정합.
