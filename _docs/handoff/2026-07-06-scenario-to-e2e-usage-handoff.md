---
title: scenario-to-e2e 스킬 — 타깃 프로젝트에서 돌려보기 (사용법 핸드오프)
status: complete
topic: scenario-to-e2e
kind: handoff
scope: harness
created: 2026-07-06
updated: 2026-07-06
related:
  - skills/scenario-to-e2e/SKILL.md
  - skills/test-scenario-doc/SKILL.md
  - skills/e2e-testing/SKILL.md
  - skills/agentic-testing/SKILL.md
---

# scenario-to-e2e — 타깃 프로젝트 실행/테스트 사용법

> **인수자에게 (타깃 프로젝트 담당 agent)**: 이 문서 하나로 `scenario-to-e2e` 스킬을 네 프로젝트에서
> 켜고 → 테스트 시나리오 문서로 Playwright e2e를 생성·검증하고 → **스킬이 제대로 동작했는지** 확인할
> 수 있다. 목적은 이 스킬을 실제 프로젝트에서 처음 돌려보는 것. 스킬 명세 자체는 `junjak-ai-harness`
> 플러그인의 `skills/scenario-to-e2e/SKILL.md`에 있다(복붙 말고 링크로 참조).

## ⚠️ 단 하나만 읽는다면

스킬은 `junjak-ai-harness` 플러그인 **v1.7.0**에 들어있고 방금 푸시됨(`JunjaK/ai-harness@59dd50a`).
마켓플레이스는 **버전 캐시** — 네 프로젝트에서 **플러그인을 v1.7.0으로 업데이트해야** 스킬이 보인다
(버전 안 오르면 update 해도 no-op). 급한 1회 테스트면 SKILL.md를 `.claude/skills/`에 직접 복사(STEP 0-B).

## TL;DR 상태

| 항목 | 상태 |
|---|---|
| 스킬 작성 (`skills/scenario-to-e2e/SKILL.md`) | ✅ v1.7.0 |
| 커밋/푸시 | ✅ `main` `59dd50a` (base `7e21118`) |
| 버전 bump(plugin+marketplace) + 문서 갱신 | ✅ |
| **실제 프로젝트에서 E2E 생성·실행 검증** | ✅ **검증 완료 (2026-07-06)** |

> ✅ **검증 결과 (2026-07-06)**: 타깃 프로젝트에서 GROUNDED 실행 — **green 3**(L1/L2/N1) · **scaffold/fixme 1**(X1
> 소셜로그인 부재, 셀렉터 발명 없이 ⚠배너+TODO) · **self-repair 1회**(L2 invalid-cred: red→실 affordance
> `.n-message` 교정→green; repo가 주석 처리해둔 assert를 스킬이 실 affordance로 확정). 4개 규율(green-gate ·
> no-fabrication · honest scaffold · self-repair) 전부 실증. → 스킬 정상.
> **후속 반영(v1.7.1)**: 관찰된 auth-state 파일 분리 케이스(예: `*.noauth.spec.ts`) → SKILL.md Output에
> "auth-state로 나뉜 프로젝트는 `pre` 기준 라우팅" 한 줄 추가.

## STEP 0 — 타깃 프로젝트에서 스킬 활성화 (A 또는 B)

**A) 마켓플레이스 (정식)**
1. `junjak-ai-harness` 플러그인이 이미 설치돼 있으면 → `/plugin`에서 **update** → 버전이 **v1.7.0**인지 확인.
2. 미설치면 → 마켓플레이스 `JunjaK/ai-harness` 추가 후 install.
- 확인: 스킬 목록에 `scenario-to-e2e`가 뜨면 OK. 안 뜨면 버전이 아직 1.6.x → 캐시. 다시 update.

**B) 로컬 복사 (빠른 1회 테스트, 업데이트 기다리기 싫을 때)**
- 이 파일을 타깃 프로젝트로 복사:
  `C:\Users\harin\dev\personal\ai-harness\skills\scenario-to-e2e\SKILL.md`
  → 타깃 `<project>\.claude\skills\scenario-to-e2e\SKILL.md`
- 즉시 프로젝트-레벨 스킬로 잡힘. **테스트 끝나면 삭제**(정식 v1.7.0으로 대체) — 안 지우면 로컬본이 플러그인본을 가린다(Gotcha 2).

## STEP 1 — 입력 준비 (test-scenario-doc)

스킬의 입력 = `test-scenario-doc`의 `SCENARIOS` config가 **SSOT**. 임의로 쓴 자유형 목록은 안 됨.
- **이미 QA 체크리스트 HTML이 있으면**: 그 `.html` 경로를 주면 스킬이 `<script id="ts-config">`를 파싱한다.
- **없으면**: 먼저 `/test-scenario-doc`으로 테스트할 기능의 시나리오 문서를 만든다. 각 카드에
  `id / group / steps[] / expect / fail`이 채워져 있어야 매핑된다(`steps`는 구체 동작, `expect`/`fail`은
  관측 가능한 문구).

## STEP 2 — GROUNDED 전제조건 (실측 + green-gate 하려면)

기본 모드 GROUNDED = 실제 앱을 몰아 **셀렉터 실측** + 생성 spec을 **실행해 green 확인**. 진짜 가치는 여기.
셋 다 있어야 GROUNDED로 간다:
1. **앱이 떠 있고** SETUP_HTML의 base URL로 접속 가능.
2. **Playwright driver** 하나: 세션에 Playwright MCP(`mcp__plugin_playwright_playwright__*`) 연결, 또는
   agent-browser CLI+skill 설치.
3. 타깃 프로젝트에 **Playwright 설치**(`@playwright/test` + 브라우저) — 생성 spec을 실제로 돌려 green-gate 하려면 필요.

→ 하나라도 없으면 자동으로 **SCAFFOLD 폴백**: 셀렉터 TODO + `⚠ UNVERIFIED` 배너로 뽑고, 리포트에 unverified로
명시(조용한 skip 없음).
**권장: 이미 Playwright가 세팅된 프로젝트를 테스트 대상으로 골라라** — green-gate가 이 스킬의 핵심 검증 포인트라서.

## STEP 3 — 실행

담당 agent에게 자연어로: **"`<시나리오 doc 경로>`로 Playwright e2e 만들어줘"** → 설명 매칭으로 스킬 발동
(슬래시 커맨드 아님 — 스킬이라 Skill 툴/자연어 트리거).
- 로그인 계정이 SETUP_HTML에 있으면 **비밀번호는 env / `storageState`로** 넘겨라. 하드코딩 금지(스킬도 그렇게 매핑함).
- 출력: `tests/e2e/from-scenarios/`(또는 프로젝트 기존 E2E 디렉토리) 밑에 그룹별 `.spec.ts` + 요약 리포트.

## STEP 4 — 스킬이 제대로 했는지 검증 (테스트의 본질)

생성물의 품질이 아니라 **스킬의 행동**을 본다:
- [ ] 입력 `SCENARIOS`를 정확히 읽었나 — 그룹/카드 수 일치, `id`가 test 이름 프리픽스로 보존?
- [ ] **셀렉터를 지어내지 않았나** — GROUNDED 생성 spec의 셀렉터가 **실제 DOM에 존재**? 못 찾은 카드는
      scaffold(TODO)로 내렸나, 아니면 그럴듯한 `getByTestId`를 발명했나?
- [ ] **안 돌려보고 "완료"라 안 했나** — spec을 실제 실행하고 정직하게 분류했나:
      green / 앱이 `fail` 증상 재현 → 실패 테스트로 남기고 **사람 에스컬레이션** / 안정화 실패 → `test.fixme`.
- [ ] **SCAFFOLD 폴백** — 앱/driver 없을 때 `⚠ UNVERIFIED` 배너 + 리포트에 unverified 명시, 조용한 skip 없나?
- [ ] 백엔드/생성 타입 안 건드렸나, 시크릿 평문 하드코딩 없나?
- [ ] 요약 리포트(green / failing-bug / fixme / unverified 카운트)가 나오나?

## Gotcha (모르면 시간 날리는 것)

1. **버전 캐시**: 플러그인 버전이 안 오르면 update 해도 no-op. 반드시 **v1.7.0** 확인.
2. **로컬 복사본 드리프트**: STEP 0-B 복사본은 프로젝트 로컬 스킬이라 플러그인본을 **가린다**. 테스트 후 삭제.
3. **Playwright 미설치 프로젝트**: green-gate 불가 → 기껏해야 scaffold. 스킬을 제대로 검증하려면 Playwright 있는 프로젝트.
4. **driver = 브라우저 1개 공유**: 탐색 레인 **직렬화**(agentic-testing 정책). 같은 브라우저로 병렬 탐색 금지.
5. **시크릿**: 로그인 비번은 env/`storageState`로만. spec·리포트에 평문 절대 금지.
6. **입력 포맷 고정**: test-scenario-doc의 `SCENARIOS` 구조여야 한다. 손으로 쓴 목록/마크다운은 매핑 안 됨.

## 범위 경계 (out-of-scope)

- 이 테스트의 목적 = **스킬 동작 검증**이지 타깃 프로젝트의 정식 e2e 스위트 구축이 아님. 생성 spec은 부산물.
- **스킬이 오작동하면 → 타깃에서 패치하지 말 것.** ai-harness의 `skills/scenario-to-e2e/SKILL.md`로
  피드백해서 거기서 iterate(v1.8.0 bump). 타깃엔 로컬 복사본만, 고치지 않는다.
- 이 문서는 scenario-to-e2e **v1 사용법**. 스킬 명세가 바뀌면 별도 갱신.

## 참고

- 스킬: `skills/scenario-to-e2e/SKILL.md`
  (절대경로 `C:\Users\harin\dev\personal\ai-harness\skills\scenario-to-e2e\SKILL.md`)
- 커밋: `JunjaK/ai-harness@59dd50a` (v1.7.0) · base `7e21118`
- 입력 스킬: `test-scenario-doc` (`/test-scenario-doc`)
- house style: `e2e-testing` · 규율(generate→run→green): `agentic-testing`
- 실행 명령 예: `npx playwright test tests/e2e/from-scenarios/` (타깃 PM에 따라 `bunx` / `pnpm exec`)
