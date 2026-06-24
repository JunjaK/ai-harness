---
title: Agentic Testing 레이어 (adapter × mode-aware)
status: processing
scope: harness
created: 2026-06-23
updated: 2026-06-23
related: [_docs/harness-evolution/impl-agentic-testing.md]
---

# Agentic Testing 레이어 — 설계 spec

> Slack Engineering, *"Agentic Testing: Where Agents Fit in the E2E Testing Stack"* 의 방법론을
> 이 하네스에 **스택 무관 어댑터 × 모드 인식 오케스트레이션**으로 편입한다.

## 1. 배경 & 출처

- **출처**: <https://slack.engineering/agentic-testing-where-agents-fit-in-the-e2e-testing-stack/>
- **핵심 명제**: *"Tests enforce journeys. Agents verify goals."* 결정적 테스트는 **정해진 여정**을 강제하고(click→click→assert), 에이전트는 **목표 달성**을 검증한다(goal→agent adapts→verify).
- **피라미드 위치**: 단위 → 통합 → **E2E(결정적)** → **Agentic(꼭대기, 탐색)**. 결정적 E2E를 **대체하지 않고 보완**.
- **아티클 실측(200+ run)**: 단순 플로우 MCP 0% 실패 / 복잡 플로우 MCP ~12%, CLI ~20%, Generated 테스트 ~48%. → 생성 테스트가 가장 깨지기 쉬움.
- **비용**: API 종량 기준 $15–30·5–11분/run. **본 하네스는 Claude Code 구독 기반이라 달러 게이트는 불필요**; 통제 대상은 *시간(wall-clock)·노이즈(중복 spec)* 뿐.

### 현 하네스 현황 (대조)
- `skills/e2e-testing/SKILL.md` = 결정적 Playwright(POM·셀렉터·flaky 수정)만. agentic 개념 없음.
- Playwright MCP가 이미 연결됨 (`mcp__plugin_playwright_playwright__*`).
- `team-tester`(Sonnet)가 Phase 4 검증에서 E2E를 담당.
- `project-analyzer` 스킬 + `/team-init`/`/team-init --update` 가 `.claude/project-profile/`(9개 파일, `stack.md`·`testing.md` 포함)을 생성/갱신.

## 2. 목표 / 비목표

**Goals**
- 결정적 E2E 통과 후·사람 최종검수 직전(**Phase 4.5**)에 도는 **탐색적 목표검증 게이트**.
- 동시에 **결정적 테스트 생성기**: 1회 탐색 → 재사용 가능한 결정적 spec으로 결정화 → 싼 CI 레이어로 회귀. (*explore once, regress forever*)
- **스택 무관**: 드라이버(Explorer)+에미터(Generator)를 어댑터로 추상화. base = web/TS, 1급 어댑터로 Spring/Kotlin·Flutter/Dart.
- **모드 인식**: 표준(단일 에이전트) vs ultracode(Workflow 오케스트레이션) 자동 전환.

**Non-goals**
- Playwright **CLI** 실행 모델(아티클상 신뢰도 낮음) — 채택 안 함.
- **고빈도 CI** 실행 — agentic은 Phase 4.5 한정, 회귀는 생성된 결정적 spec이 담당.
- 달러 기반 게이트·사람 승인 게이트(구독 기반이므로 불필요).
- web 전용 하드코딩(어댑터로 일반화).

## 3. 핵심 원칙 & 위치

- 배너: **"Tests enforce journeys. Agents verify goals. Explore once, regress forever."**
- 위치: **Phase 4.5** — `team-tester` Phase 4 = PASS 이후, Phase 5(보안/최종) 이전. 비차단 탐색 게이트.

## 4. 아키텍처 — 두 직교 축

파이프라인 골격은 고정. **표면/스택**(축1)이 드라이버·에미터·동시성을 채우고, **오케스트레이션 모드**(축2)가 단일 에이전트 vs Workflow 팬아웃을 고른다.

### 4.0 하드 선행조건 — project-profile (MUST)

- agentic-testing은 `.claude/project-profile/`의 `index.md`+`stack.md`+`testing.md`를 **MUST read**.
- 프로필이 **없으면 즉시 ABORT** + `"먼저 /team-init 실행"` 안내. (프로필 없이는 어댑터 결정 불가)
- **Staleness 게이트**: `index.md`에 기록된 *생성 시점 git HEAD*와 현재 HEAD의 drift를 검사. drift 과다 또는 "Agentic Testing Adapter" 섹션 누락 시 → `/team-init --update` 요구 후 진행. (신규 command 생성 X — 기존 `--update` 강화)

### 4.1 축1 — 스택 무관 어댑터 (base = web/TS)

`project-analyzer` Step 6(`testing.md`)에 **"Agentic Testing Adapter"** 서브섹션을 추가하여 SSOT로 삼는다. 에미터는 새로 만들지 않고 **각 스택의 기존 테스트 스킬을 house style로 위임**한다(CLAUDE.md "link don't duplicate").

| 표면 | Explorer 드라이버 | Generator 에미터 (house-style 위임) | 동시성 정책 | 상태 |
|---|---|---|---|---|
| **웹/TS (base·레퍼런스)** | Playwright MCP | `.spec.ts` ← `e2e-testing` | 공유 브라우저 1개 → **Explorer 직렬** | 즉시 가동 |
| **Spring/Kotlin (백엔드 API)** | HTTP 호출 | `WebTestClient`/`@SpringBootTest`+Testcontainers ← `springboot-tdd`·`kotlin-testing` | 무상태 → **진짜 병렬**(워커별 DB 격리) | 즉시 가동 |
| **Flutter/Dart (모바일 UI)** | maestro·Patrol·모바일 MCP | `integration_test`·maestro yaml | 단일 디바이스 → **디바이스당 직렬**(다중 디바이스 시 팬아웃) | **드라이버 가용 시**(없으면 문서화+스킵) |
| **교차 여정 (Flutter→Spring)** | UI 구동 + 백엔드 상태 단언 | 양 레이어 | 상위 둘에 종속 | 후속 |

- **표면 감지**: `stack.md`의 언어/프레임워크 + `testing.md`의 테스트 프레임워크에서 결정.
- **드라이버 부재 처리**: 모바일 드라이버(maestro/Patrol/모바일 MCP)가 연결돼 있지 않으면 해당 goal을 **실행하지 않고** "driver unavailable"로 리포트에 명시(무음 스킵 금지).

### 4.2 축1 — 2단계 파이프라인 (Explorer → Generator)

1. **Explorer** (Sonnet + 어댑터 드라이버): goal을 자율 탐색(navigate→snapshot→act→wait→assert)하여 **목표 달성 여부 + 발견 경로 + 증거**를 기록. 스텝 상한(기본 ~25)·앱 도달 가능성으로 시간 통제.
2. **Generator** (Opus 4.8): 발견 경로를 어댑터 에미터로 **결정적 테스트로 결정화** → **자체 실행하여 green 확인**(self-repair 최대 2회, 끝내 red면 폐기). green인 spec만 커밋.
- 목표 미달(`met=false`) → spec 생성 안 함, **사람 에스컬레이션**.

### 4.3 축2 — 모드 인식 (standard vs ultracode)

- **신호(정렬)**: Claude Code **내장 ultracode 모드**에 정렬한다(런타임이 신호). 헤드리스/비-Claude-Code 컨텍스트용으로 `CLAUDE_HARNESS_ULTRACODE=1` env 플래그를 **선택적 override**로만 둔다(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 선례와 동형). effort(`max`)와 오케스트레이션 토폴로지는 **분리**됨 — ultracode는 `/effort max`에 편승하지 않는다.
- **스위치 위치 = 오케스트레이션 레이어**: 스킬(마크다운)·스폰된 서브에이전트는 `pipeline()`/`workflow()`를 호출할 수 없다. Workflow 도구는 **최상위 오케스트레이터**(team-workflow/team-leader)가 호출할 때만 실행된다. 따라서:
  - **표준**: 오케스트레이터가 `team-agentic-tester` 에이전트를 Agent 도구로 dispatch(순차).
  - **ultracode**: 오케스트레이터가 agentic-testing **Workflow 스크립트**를 실행(팬아웃).
  - **Graceful fallback**: `workflow()` 호출 불가 시 무조건 표준.
- `agents/team-agentic-tester.md`는 **표준 모드 실행기**의 정의. ultracode 파이프라인은 별도 Workflow 스크립트.

| 측면 | 표준(기본/폴백) | ultracode |
|---|---|---|
| 실행 | 단일 `team-agentic-tester`, goal 순차 | `pipeline()` 팬아웃(어댑터 동시성 정책 준수) |
| 검증 | 단일 판단 | 다관점 verify(회의자 + 기준심사, **합의해야 채택**) + vacuity guard 교차참조 |
| 생성 spec | generate→run→repair ×2, 비-green 폐기 | 동일, 단 spec 실행(headless)은 팬아웃 |
| 엣지 | 없음 | bounded completeness-critic(≤2 라운드) |

**모드 결정 규칙 (MUST — 4불리언 AND)**
```
selectMode(ctx):
  IF NOT workflowCallable():              RETURN STANDARD   # 하드 폴백
  IF NOT ultracodeActive(ctx):            RETURN STANDARD   # 내장 신호 또는 env override
  IF derivedGoalCount(ctx) < 2:           RETURN STANDARD   # goal 1개면 팬아웃 이득 없음
  IF NOT targetReachable(ctx):            RETURN STANDARD
  RETURN ULTRACODE
```
**goal별 실행-여부 게이트(자율, 비-달러)**: VALUE(기존 `*.spec`와 무중복) · TIME(스텝 한도·앱 가동) · NOISE(결정적 단언 가능; 주관/심미는 `web-reviewer`·`impeccable`로 이관) 모두 통과해야 실행. 스킵은 **사유 로깅 필수**.

### 4.4 ultracode Workflow 스케치 (어댑터-파라미터화, 예시)

> 실제 Workflow API에 충실: `agent / parallel / pipeline / phase / log / budget`.
> 드라이버/에미터/동시성은 어댑터에서 주입. 아래는 web 어댑터(공유 브라우저 → Explorer 직렬) 예시.

```js
// 어댑터에서: driver(=playwright-mcp), emitter(=e2e-testing), serializeExplorer=true
const goals = (await agent(deriveGoalsPrompt, { model:'sonnet', schema: GOALS }))
  .goals.filter(g => g.worthRunning);          // VALUE/TIME/NOISE 게이트

// 공유 브라우저면 Explorer 차선을 mutex로 직렬화. Generator·headless 실행은 팬아웃.
let lane = Promise.resolve();
const onBrowserLane = serializeExplorer ? (fn => (lane = lane.then(fn, fn))) : (fn => fn());

const results = await pipeline(goals,
  goal => onBrowserLane(() => agent(explorePrompt(goal), { model:'sonnet', schema: VERDICT })),
  async v => {                                  // Generator + self-repair
    if (!v.met) { log(`UNMET ${v.goalId} → 사람 에스컬레이션`); return { ...v, green:false, spec:null }; }
    let a=0, spec=null, green=false, err='';
    while (a<=2 && !green) {
      spec = await agent(genPrompt(v, err, a, emitterHouseStyle), { model:'opus', schema: SPEC });
      const run = await agent(runHeadless(spec.specPath), { model:'sonnet', schema: RUN });
      green = run.green; err = run.failTail; a++;
    }
    if (!green) log(`DISCARD ${v.goalId}: 2회 수선 실패`);
    return { ...v, green, spec: green ? spec : null };
  }
);

// 다관점 verify (배리어 의도적: 리포트가 전체를 필요로 함)
const audited = await parallel(results.filter(r=>r.met).map(r => async () => {
  const [skeptic, judge] = await Promise.all([
    agent(skepticPrompt(r), { model:'opus', schema: V }),   // 거짓 'met'? vacuity guard
    agent(criteriaPrompt(r), { model:'sonnet', schema: V }),// 원 수용기준 충족?
  ]);
  return { ...r, trustworthy: skeptic.verdictReal && judge.satisfies };
}));
return {
  verifiedTrustworthy: audited.filter(a=>a.trustworthy && a.green),
  verifiedButNotCrystallizable: audited.filter(a=>a.trustworthy && !a.green),
  unmetGoals: results.filter(r=>!r.met),
  distrustedVerdicts: audited.filter(a=>!a.trustworthy),
};
```
- **백엔드 어댑터**: `serializeExplorer=false` → Explorer도 팬아웃(워커별 DB 격리). 동일 골격, 동시성 정책만 다름.
- `workflow()`는 1단계만 중첩되므로, completeness-critic 라운드는 **워크플로우가 아니라 파이프라인을 재귀**시켜 구현.

## 5. 컴포넌트 & 계약 (spec 델타)

### 신규
- **`skills/agentic-testing/SKILL.md`**
  - frontmatter(`name: agentic-testing`, "Phase 4.5, after E2E PASS, before Phase 5"), 원칙 배너.
  - 하드 선행조건(profile 필수 + staleness), 어댑터 해석 규칙(표면→드라이버/에미터/동시성).
  - goal 유도(수용기준 → outcomes-not-steps, 위험 우선순위), 실행-여부 게이트(value/time/noise).
  - 2단계 파이프라인 계약(`e2e-testing` 등 house-style 스킬 **링크**, 중복 금지), self-repair(≤2, 비-green 폐기).
  - **두 모드** 문서 + 모드 결정 규칙 verbatim + 공유 드라이버 동시성 주의.
  - 검증 신뢰(다관점 + `verification-loop` vacuity guard 교차참조), 출력 포맷(`team-tester` 리포트 확장).
- **`agents/team-agentic-tester.md`**
  - frontmatter(`name: team-agentic-tester`, `model: opus`), 역할(꼭대기 레이어, 게이트+생성기 통합, **표준 모드 실행기**).
  - effort `xhigh`(self-repair 2회 실패 시에만 `max`).
  - MUST-read(profile index/stack/testing, plan 문서, team-tester 리포트, 어댑터 house-style 스킬).
  - 첫 스텝 = 선행조건/모드 판정, 7-step 표준 루프, 에스컬레이션 재사용(`team-tester` 포맷: Simple=셀렉터/wait drift, Fundamental=목표 도달 불가).

### 수정
- **`skills/project-analyzer/SKILL.md` + `resources/profile-templates.md`**: `testing.md`에 "Agentic Testing Adapter" 섹션(표면·드라이버·에미터·동시성) + `index.md`에 *생성 시점 git HEAD* 기록.
- **`commands/team-init.md`**: `--update`에 **staleness 감지**(HEAD drift, 어댑터 섹션 누락) 명문화.
- **`skills/team-workflow/SKILL.md`**: "Orchestration Mode" preamble(신호 1회 판독), **Phase 4.5 단계** 삽입(team-tester PASS 조건부), ultracode일 때 명시된 4개 팬아웃을 `parallel`/`pipeline`로.
- **`agents/team-leader.md`**: "Orchestration Strategy" 결정 + Plan Output에 "Orchestration" 필드.
- **`CLAUDE.md` / `README.md`**: Skills/Agents 표에 `agentic-testing`·`team-agentic-tester` 추가, "Ultracode Orchestration" 섹션, `CLAUDE_HARNESS_ULTRACODE` env(선택적 override) 명시, effort≠topology 주석.

### 불변(포인터만)
- `skills/e2e-testing/SKILL.md`, `agents/team-tester.md` — agentic 레이어로의 1줄 포인터만 추가. 생성 spec은 이들 규약(POM·셀렉터 우선순위·wait 패턴)을 **그대로 준수**.

## 6. 롤아웃 — ultracode → Workflow (opt1: agentic-testing + 검증된 4개 팬아웃)

ultracode AND `workflow()` 가용일 때 다음을 Workflow로 실행. 그 외 모든 경우는 현행 경량 `Agent()`/`TeamCreate` 경로 유지(가드).

| 프로세스 | 팬아웃 형태 | 채택 |
|---|---|---|
| agentic-testing Explorer→Generator | `pipeline` | **지금** |
| Phase 1 아키텍처 (FE/BE 병렬, cross-review는 `TeamCreate` 유지) | `parallel` | **지금** |
| Phase 3 Designer(worktree 격리) → 순차 머지 | `parallel`+머지 | **지금** |
| Phase 4 Tester-per-designer | `parallel` | **지금** |
| Phase 4 pass@k / plan-review 적대 팬아웃 / Phase 5 보안 팬아웃 | — | **후속**(worktree 격리·diff 크기 게이트 필요) |

**CLAUDE.md 신규 "Ultracode Orchestration" 원칙(MUST-style 초안)**
> **Ultracode → Workflow orchestration.** 런타임이 ultracode 모드를 신호하고(또는 `CLAUDE_HARNESS_ULTRACODE=1`) `workflow()`가 호출 가능할 때, 독립 작업 단위 2개 이상·fan-out-then-barrier·per-item 다단계 형태를 갖는 하네스 프로세스는 Workflow 도구로 실행해야 한다(`parallel()`=배리어 팬아웃, `pipeline()`=per-item, `workflow()`=1단계 중첩). 매칭 패턴(adversarial-verify, perspective-diverse verify, judge-panel, completeness-critic, self-repair)을 선택하고, 하위 게이트가 구조화 필드를 소비하면 `schema`를 전달한다. 명시 팬아웃 지점은 Phase 1 아키텍처·Phase 3 Designer+머지·Phase 4 Tester-per-designer·agentic-testing Explorer→Generator. 하네스의 max-5-worktree 상한과 types→backend→frontend→tests 머지 순서가 코드 작성자에 대해 `min(16, cores-2)` 상한을 **override**한다. 단일 에이전트 작업, per-item 스트리밍 이득이 없는 순수 순차 체인, 가변 상태 공유 작업(`parallelization`의 "When NOT to Scale"), 단일 공유 Playwright MCP 브라우저의 병렬 사용, 결정적 상태파일 부기에는 **사용 금지**. **ultracode 모드가 아니면 위 전부 현행 경량 경로를 사용하며 Workflow 레이어를 도입하지 않는다.**

## 7. 데이터 흐름

```
plan/spec 수용기준 ─(goal 유도)→ Agentic Goal
   → Explorer(Sonnet+어댑터 드라이버): goal→자율적응→verify, 발견경로 기록
      ├─ ① 목표검증 리포트 + 발견경로 ─→ 사람 최종검수
      └─ ② (발견경로) Generator(Opus): 결정화 → 자체 실행 green 확인 → 커밋
            → tests/<adapter>/… (결정적 spec) ─→ 이후 싼 CI 회귀
```

## 8. 산출물 위치 & 포맷
- **목표검증 리포트**: 해당 작업 _docs 문서로 병합(`docs-lifecycle` merge-on-completion). `team-tester` 리포트 포맷 확장(목표별 met/trustworthy/green/spec 경로).
- **생성 spec**: 어댑터별 디렉터리(web `tests/e2e/`, kotlin `src/test/…`, flutter `integration_test/`). house-style 스킬 규약 준수.
- **trace/스크린샷**: `artifacts/`(탐색 trace).

## 9. 검증 (acceptance)
앱 코드가 아니라 스킬+에이전트 저작이므로, **드라이런 1회**로 검증:
1. base(web/TS) 어댑터로 기존 user-facing 플로우 하나를 끝까지 파이프라인 통과.
2. (a) 목표검증 리포트 생성 (b) 생성 spec을 **결정적으로 재실행 시 green** — 둘 다 확인.
3. project-profile 부재 시 **ABORT** 동작 확인(선행조건 게이트).

## 10. 미해결 / 후속
1. 모바일 드라이버 표준(maestro vs Patrol vs 모바일 MCP) 선택 — Flutter 어댑터 1급화 시 확정.
2. 교차 여정(Flutter→Spring) 어댑터 — 후속.
3. pass@k·plan-review·security 팬아웃 — worktree 격리 정비 후 후속.
4. Explorer 진짜 병렬(웹) — per-worktree 격리 브라우저 컨텍스트, 후속 enhancement.
5. `workflow()` 런타임 가용성 — 미가용 환경에선 표준 모드만 출하하고 ultracode 경로는 "문서화-but-dormant".
