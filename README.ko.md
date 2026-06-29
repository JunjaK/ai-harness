# AI Harness — Multi-Agent Team Workflow

[English](README.md) · **한국어** · [日本語](README.ja.md)

Claude Opus를 위한 재사용 가능한 Claude Code 하네스입니다. 그린필드 프로젝트 부트스트랩(research → scaffold → profile)과 더불어 5단계 멀티 에이전트 팀 워크플로(TDD, 에스컬레이션 루프, worktree 병렬화), 완결된 테스트 스택, 라이프사이클이 관리되는 문서 저장 시스템, 코드 미니멀리즘 규율, 그리고 본능 기반 학습을 제공합니다.

## Overview

전문화된 AI 에이전트들이 정의된 단계를 거쳐 협업하며 기능 구현, 버그 수정, 코드 리팩터링을 수행합니다. 핵심 팀 워크플로 외에도 하네스는 다음을 추가로 제공합니다.

- **테스트 스택** — 유닛(Vitest) → 결정론적 E2E(Playwright) → **agentic E2E**(Phase 4.5: 에이전트가 목표를 검증하고 결정론적 테스트로 결정화) → **휴먼 QA**(`/test-scenario-doc`, 인터랙티브 체크리스트). [`agent-browser`](https://agent-browser.dev/) CLI + 스킬이 설치되어 있으면 E2E / QA / smoke를 위한 **우선 온디맨드 브라우저 드라이버**가 되며 — 암호화된 **Auth Vault**를 통한 헤드리스 로그인(비밀번호는 절대 LLM에 도달하지 않음)을 포함합니다 — 설치되어 있지 않으면 Playwright 경로로 폴백합니다.
- **문서 저장(3개 버킷)** — `_docs/`(프로젝트, 라이프사이클 관리) · `_note/`(사람 소유, 에이전트 읽기 전용) · `.claude/wiki/`(지식을 누적해 나가는 에이전트 관리형 **LLM 위키**)로, 이식 가능한 소유권 판별 기준으로 분류됩니다.
- **코드 미니멀리즘** — `ponytail` YAGNI 의사결정 사다리를 설계 시점에 적용하고 Phase 4에서 검토합니다.
- **본능 기반 학습** — `continuous-learning`이 원자적이고 확신도가 매겨지며 프로젝트 범위로 한정된 본능을 포착해, 이를 스킬 / 커맨드 / 에이전트로 진화시킵니다.
- **Ultracode 오케스트레이션** — 활성화되면 fan-out 단계가 Workflow 도구를 통해 실행됩니다.

### Team Roles

| Role | Agent | Model | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | opus | 항상 (Phase 1, Gate, Escalation) |
| Architect A (Frontend) | `team-architect-fe` | opus | Phase 1 (B와 병렬) |
| Architect B (Backend) | `team-architect-be` | opus | Phase 1 (A와 병렬) |
| Architect C (Infra/Security) | `team-architect-infra` | opus | Phase 1 (온디맨드) + Phase 5 (항상) |
| UI/UX Master | `team-uiux-master` | opus | Phase 2 (조건부) |
| Designer x N | `team-designer` | opus | Phase 3 (병렬, worktree 격리) |
| Tester x N | `team-tester` | sonnet | Phase 4 (병렬) |
| Agentic Tester | `team-agentic-tester` | opus | Phase 4.5 (조건부, Tester PASS 이후) |
| Web Architect | `web-architect` | opus | 웹 아키텍처 (단독 또는 FE 보완) |
| Web Reviewer | `web-reviewer` | sonnet | 웹 품질 감사 (a11y, CWV, SEO, AI-slop) |

### Workflow Phases

```
Phase 1: Planning
  Leader drafts plan → Arch A + B detail (parallel) → Cross-review → File assignment

Phase 2: UI/UX (conditional)
  UI/UX Master reviews and proposes changes

Leader Approval Gate
  Approve → Phase 3 | Reject → Phase 1

Phase 3: Implementation (TDD)
  Designer x N in parallel worktrees (Red-Green-Refactor)

Phase 4: Verification
  Tester x N (unit + E2E, loop until pass)

Phase 4.5: Agentic Testing (conditional)
  Agent explores goals → verifies → crystallizes deterministic tests
  (then human QA via /test-scenario-doc, before final sign-off)

Phase 5: Final Security Review
  Arch C security & infra audit → SHIP or escalate
```

### Escalation

- 각 에이전트가 스스로 판단: 단순 수정(재시도, 최대 3회) vs 근본적 문제(상위로 에스컬레이션)
- 전역 재계획 한도: 무한 루프 방지를 위해 3사이클
- `/team`과 `/team-run` 모두 에스컬레이션 이벤트를 사용자에게 보고

## Commands

| Command | Description |
|---------|-------------|
| `/team-new` | 그린필드 — 빈 저장소 → deep-research → scaffold → 시드된 프로필, 이후 `/team-run`으로 인계 |
| `/team-init` | 기존 프로젝트 분석 → 프로필 생성 (코드가 있는 프로젝트에서는 먼저 실행할 것!) |
| `/team` | 인터랙티브 모드 — 사용자가 계획 단계에 참여 |
| `/team-run` | 자율 모드 — 완전 자동 실행 |
| `/team-brainstorm` | 계획만 — Leader + Architects가 논의, 구현 없음 |
| `/checkpoint` | 세션, 브랜치, 컴팩션을 가로질러 작업 상태 저장 / 복원 |
| `/docs-sweep` | 오래된 `_docs/`를 정리하고 고아 문서 불변식을 재검증 |
| `/test-scenario-doc` | 온디맨드 휴먼 QA 체크리스트 HTML (사람 수용 레이어) |
| `/brain-connect` | 선택적 개인 **brain** SSOT(머신 간 페르소나 + 자동 메모리)를 하네스와 페어링하거나, 기존 것을 재배치 |

## Installation (Plugin)

이 하네스는 **Claude Code 플러그인**으로 배포됩니다.

```bash
# 1. Add the marketplace
/plugin marketplace add JunjaK/ai-harness

# 2. Install the plugin
/plugin install junjak-ai-harness@ai-harness
```

### Required User Configuration

플러그인 매니페스트는 환경 변수나 권한을 설정할 수 없습니다. 다음을 **user** 또는 **project** `settings.json`에 추가하세요.

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"
  },
  "permissions": {
    "allow": [
      "Edit",
      "Write",
      "LSP",
      "Bash(git *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(bun *)",
      "Bash(bunx *)",
      "Bash(pnpm *)",
      "Bash(npx *)"
    ]
  }
}
```

> `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`은 **필수**입니다 — `/team`, `/team-run`, `/team-brainstorm`은 cross-review를 위해 `TeamCreate`에 의존합니다.
>
> `CLAUDE_HARNESS_ULTRACODE=1`은 **선택**입니다 — 런타임 ultracode 신호가 없는 헤드리스 / 비-Claude-Code 환경에서 ultracode 오케스트레이션(Workflow 도구 fan-out)을 강제하는 명시적 오버라이드입니다. CLAUDE.md "Ultracode Orchestration"를 참고하세요.

### Dependencies

위 env 플래그와 함께, 하네스는 몇 가지 외부 도구를 사용합니다. 완전한 경험을 위해 설치하세요 — 각 도구는 없을 때 어떤 일이 일어나는지와 함께 아래에 설명되어 있습니다.

| Tool | Used for | Without it |
|------|----------|-----------|
| **impeccable** plugin · [impeccable.style](https://impeccable.style/) | UI/UX 디자인 품질 — `team-uiux-master` / `web-architect` / `web-reviewer` 에이전트가 `Skill("impeccable:impeccable", "<sub-command> [target]")`로 호출 | 해당 에이전트들이 멈추고 설치를 요청 |
| **ponytail** plugin · [repo](https://github.com/DietrichGebert/ponytail) | YAGNI 미니멀리즘 — Phase 4가 diff에 대해 `/ponytail-review` 실행 | Phase 4가 설치를 요청 (의사결정 사다리는 `coding-standards` §4에도 정제되어 있음) |
| **agent-browser** CLI + skill · [agent-browser.dev](https://agent-browser.dev/) | E2E / QA / smoke를 위한 우선 온디맨드 브라우저 드라이버 + 헤드리스 Auth-Vault 로그인(비밀번호는 절대 LLM에 도달하지 않음) | Playwright `e2e-testing` / `agentic-testing` 경로로 폴백 |

```bash
/plugin marketplace add pbakaus/impeccable && /plugin install impeccable@impeccable
/plugin install ponytail@ponytail
npm i -g agent-browser && agent-browser install   # skill ships with the CLI
```

impeccable과 ponytail은 워크플로를 실행하기 전에 설치되어 있어야 합니다. agent-browser는 선택이지만 매끄러운 브라우저 작업을 위해 권장됩니다.

### First Run

```
/team-init                        # Scan project → generate .claude/project-profile/
/team "Add user authentication"   # Start a workflow
```

`/team-init`은 프로젝트에 `.claude/project-profile/`을 생성합니다 — 모든 에이전트가 여러분의 스택과 컨벤션에 맞춰 동작합니다.

## Customization

### Adapting to Your Stack

에이전트들은 기본적으로 프레임워크에 종속되지 않습니다. 프로젝트에 맞게 특화하려면 다음과 같이 하세요.

1. **team-architect-fe.md** — 프론트엔드 컨벤션 추가 (컴포넌트 패턴, 상태 관리, 스타일링)
2. **team-architect-be.md** — 백엔드 컨벤션 추가 (API 패턴, ORM, 데이터베이스)
3. **team-architect-infra.md** — 보안 체크리스트 추가 (인증 패턴, env 관리)
4. **team-designer.md** — 테스트 프레임워크와 TDD 패턴 추가
5. **team-tester.md** — 테스트 러너 커맨드와 E2E 설정 추가

### Document Storage (3 buckets)

문서는 이식 가능한 판별 기준 *"에이전트 CLI를 교체해도 — 이것이 여전히 의미가 있는가?"* 를 사용해 **소유자** 기준으로 분류됩니다. → 예 = 프로젝트 / 사람 (저장소 루트의 `_` 접두사); 아니오 = 에이전트 전용 (`.claude/`).

| Bucket | Owner | Holds |
|--------|-------|-------|
| `_docs/` | project | 계획, 스펙, ADR — 라이프사이클 관리 (`planning → processing → complete`), 완료 시 사이드카 병합 |
| `_note/` | human | 개인 / 리서치 / 임시 노트 — **에이전트 읽기 전용** (명시적 요청 시에만 편집), frontmatter 없음 |
| `.claude/wiki/` | agent | **LLM 위키** — 누적되고 상호 연결된 지식 (ingest / query / lint); SSOT를 링크할 뿐 절대 복제하지 않음 |

핸드오프는 `_docs/handoff/`에 위치합니다. `/team-init`이 `_note/README.md`와 `.claude/wiki/`를 부트스트랩합니다. 규칙은 `docs-lifecycle`과 `wiki` 스킬에 있으며, `_docs/index.md`는 모든 계획 변경 시 갱신됩니다.

## Supporting Skills

에이전트가 워크플로 단계 동안 참조하는 스킬들입니다.

| Skill | Phase | Purpose |
|-------|-------|---------|
| `greenfield-bootstrap` | `/team-new` | G0 intake → G1 deep-research → G2 stack decision → G3 user gate → G4 scaffold → G5 seeded profile |
| `plan-review` | Phase 1 | 구현 전 계획에 대한 비판적 검토 + 사전 계획 이끌어내기 |
| `brainstorm` | Pre-Phase 1 (solo) | 가벼운 단독 설계 대화 → `_docs/` 설계 (자동 커밋 없음); `/team-brainstorm`의 단독 카운터파트 |
| `coding-standards` | Phase 3 | 범용 코드 품질 기준선 (strict TS) |
| `tdd-workflow` | Phase 3 | Red-Green-Refactor TDD 사이클 (Vitest 4.x) |
| `systematic-debugging` | Phase 3-4 | 일반 디버깅 방법론 (근본 원인 → 패턴 → 가설 → 수정); `debug`가 그 위에 TS/LSP를 얹음 |
| `debug` | Phase 3-4 | LSP 기반 디버깅 패턴 (TS) |
| `e2e-testing` | Phase 4 | Tester를 위한 Playwright E2E 패턴 |
| `agentic-testing` | Phase 4.5 | 어댑터 기반 agentic E2E — 목표 탐색 → 검증 → 결정론적 테스트로 결정화 |
| `agent-browser-e2e` | On-demand | CLI + 스킬이 설치되어 있으면 E2E/QA/smoke + 암호화된 Auth Vault를 통한 헤드리스 로그인(비밀번호가 LLM에 도달하지 않음)에 `agent-browser` CLI를 우선 사용; 1회 게이트, 그렇지 않으면 Playwright로 폴백. 단계에 고정 연결되지 않음 |
| `test-scenario-doc` | Human acceptance | 인터랙티브 휴먼 QA 체크리스트 HTML — `/test-scenario-doc`로 온디맨드 |
| `verification-loop` | Phase 4-5 | 6단계 품질 게이트 (build, type, lint, test, security, diff) |
| `contract-sync` | Phase 0 / BE→FE handoff | 백엔드 계약 변경 후 생성된 API 클라이언트를 재생성한 뒤, 타입 체크 + 소비 지점 교차 점검 |
| `security-review` | Phase 5 | Architect C를 위한 OWASP Top 10 체크리스트 |
| `requesting-code-review` | Phase 3-5 / on-demand | 작업 사이 / 머지 게이트 전에 code-reviewer 서브에이전트(맞춤 컨텍스트) 디스패치 |
| `plan-visualizer` | Phase 1+ | 계획의 HTML 다이어그램 (team, phases, files, deps) |
| `project-analyzer` | Setup | 프로젝트 구조 분석 → 프로필 생성 |
| `brain-connect` | Setup (per-machine) | 선택적 개인 **brain** SSOT(머신 간 페르소나 + 자동 메모리)를 하네스와 페어링 — 페르소나 `@import` + 메모리 junction + 옵트인 sync 훅; 의존성 없음, 범용 커넥터 템플릿 동봉 |

크로스커팅 스킬 (모든 단계): `token-optimization`, `continuous-learning`, `parallelization`, `dispatching-parallel-agents`, `subagent-orchestration`, `checkpoint`, `docs-lifecycle`, `handoff`, `wiki`.

일반적인 API 설계 패턴은 Claude Code 내장 `api-design` 스킬을 직접 사용하세요 (하네스는 이를 래핑하지 않습니다).

## Plugin Structure

```
junjak-ai-harness/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Marketplace definition (single-repo)
├── agents/                      # 10 specialized agents
│   ├── team-leader.md
│   ├── team-architect-fe.md
│   ├── team-architect-be.md
│   ├── team-architect-infra.md
│   ├── team-uiux-master.md
│   ├── team-designer.md
│   ├── team-tester.md
│   ├── team-agentic-tester.md
│   ├── web-architect.md
│   └── web-reviewer.md
├── commands/                    # 8 slash commands
│   ├── team-new.md              # /team-new
│   ├── team-init.md             # /team-init
│   ├── team.md                  # /team
│   ├── team-run.md              # /team-run
│   ├── team-brainstorm.md       # /team-brainstorm
│   ├── checkpoint.md            # /checkpoint
│   ├── docs-sweep.md            # /docs-sweep
│   └── test-scenario-doc.md     # /test-scenario-doc
├── hooks/
│   ├── hooks.json               # Plugin hook registration
│   ├── session-stop.sh
│   ├── pre-compact.sh
│   └── post-edit-warn.sh
└── skills/                      # 28 workflow skills
    ├── team-workflow/
    ├── greenfield-bootstrap/
    ├── project-analyzer/
    ├── tdd-workflow/
    ├── verification-loop/
    ├── contract-sync/
    ├── docs-lifecycle/
    ├── handoff/
    ├── wiki/
    ├── agentic-testing/
    ├── test-scenario-doc/
    ├── security-review/
    ├── systematic-debugging/
    ├── dispatching-parallel-agents/
    ├── requesting-code-review/
    ├── brainstorm/
    └── ... (14 more)
```

### CLAUDE.md Note

플러그인은 사용자 프로젝트에 `CLAUDE.md`를 주입할 수 없습니다. 이 저장소 루트의 `CLAUDE.md`는 하네스의 운영 원칙을 문서화합니다. 전체 규칙 세트를 원하는 사용자는 관련 섹션을 자신의 프로젝트 `CLAUDE.md`에 복사하세요.

## License

MIT
