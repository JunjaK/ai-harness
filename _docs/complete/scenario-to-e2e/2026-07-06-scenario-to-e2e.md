---
title: scenario-to-e2e — 타깃 프로젝트 실행/검증 기록 (v1)
status: complete
topic: scenario-to-e2e
kind: impl
scope: harness
created: 2026-07-06
updated: 2026-07-07
related:
  - skills/scenario-to-e2e/SKILL.md
  - skills/test-scenario-doc/SKILL.md
  - skills/e2e-testing/SKILL.md
  - skills/agentic-testing/SKILL.md
---

# scenario-to-e2e — 타깃 프로젝트 실행/검증 기록 (v1)

> `scenario-to-e2e` 스킬(`test-scenario-doc`의 `SCENARIOS`를 SSOT로 Playwright e2e 생성)을 실제 타깃 프로젝트에서 처음 돌려 **스킬 동작을 검증한 기록** + 재사용 가능한 실행 런북. 스킬 명세 자체는 `skills/scenario-to-e2e/SKILL.md`(링크, 복제 X).

## 1. 목적 / 비목적

- **목적**: 스킬을 실제 프로젝트에서 처음 실행해 **스킬의 행동**(생성물 품질이 아니라)이 올바른지 검증.
- **비목적**: 타깃 프로젝트의 정식 e2e 스위트 구축 — 생성 spec은 부산물.

## 2. 검증 결과 (2026-07-06 · 결론: 스킬 정상)

GROUNDED 모드(실앱을 몰아 셀렉터 실측 + 생성 spec을 실행해 green-gate)로 실행:

- **green 3** — L1 / L2 / N1
- **scaffold/fixme 1** — X1(소셜로그인 부재): 셀렉터 발명 없이 `⚠ UNVERIFIED` 배너 + TODO로 정직 하향
- **self-repair 1회** — L2(invalid-cred): red → 실 affordance `.n-message`로 교정 → green. repo가 주석 처리해둔 assert를 스킬이 실 affordance로 확정
- **4개 규율 전부 실증** — green-gate · no-fabrication · honest scaffold · self-repair
- **후속 반영 (v1.7.1)** — 관찰된 auth-state 파일 분리 케이스(예: `*.noauth.spec.ts`) → SKILL.md Output에 "auth-state로 나뉜 프로젝트는 `pre` 기준 라우팅" 한 줄 추가

## 3. 실행 런북 (재사용)

### STEP 0 — 스킬 활성화 (A 또는 B)
- **A) 마켓플레이스(정식)**: `junjak-ai-harness` 플러그인 update → 버전 확인. 마켓플레이스는 **버전 캐시**라 버전이 안 오르면 update 해도 no-op.
- **B) 로컬 복사(빠른 1회)**: `skills/scenario-to-e2e/SKILL.md`를 타깃 `<project>/.claude/skills/`에 복사 → 즉시 프로젝트-레벨 스킬로 잡힘. **테스트 후 삭제**(로컬본이 플러그인본을 가림).

### STEP 1 — 입력 준비 (test-scenario-doc = SSOT)
스킬 입력 = `test-scenario-doc`의 `SCENARIOS` config. 임의 자유형 목록 불가.
- QA 체크리스트 HTML 있으면 그 `.html` 경로 → `<script id="ts-config">` 파싱.
- 없으면 `/test-scenario-doc`으로 먼저 생성. 각 카드에 `id / group / steps[] / expect / fail`.

### STEP 2 — GROUNDED 전제조건 (셋 다 필요)
1. 앱이 떠 있고 SETUP_HTML의 base URL로 접속 가능.
2. Playwright driver 하나 — Playwright MCP 연결 또는 agent-browser CLI+skill.
3. 타깃에 Playwright 설치(`@playwright/test` + 브라우저) — 생성 spec을 실제로 돌려 green-gate 하려면 필수.

→ 하나라도 없으면 **SCAFFOLD 폴백**(셀렉터 TODO + `⚠ UNVERIFIED` 배너, 리포트에 unverified 명시 — 조용한 skip 없음). **권장: Playwright가 세팅된 프로젝트를 대상으로** — green-gate가 이 스킬의 핵심 검증점.

### STEP 3 — 실행
담당 agent에게 자연어: **"`<시나리오 doc 경로>`로 Playwright e2e 만들어줘"**. 로그인 비번은 env / `storageState`로만(하드코딩 금지). 출력: `tests/e2e/from-scenarios/`(또는 프로젝트 기존 E2E 디렉토리) 밑 그룹별 `.spec.ts` + 요약 리포트.

### STEP 4 — 스킬 동작 검증 체크리스트
생성물 품질이 아니라 **스킬의 행동**을 본다:
- [ ] 입력 `SCENARIOS`를 정확히 읽음 — 그룹/카드 수 일치, `id`가 test 이름 프리픽스로 보존?
- [ ] **셀렉터를 안 지어냄** — 생성 spec의 셀렉터가 실제 DOM에 존재? 못 찾은 카드는 scaffold(TODO)로 내렸나?
- [ ] **안 돌려보고 "완료" 안 함** — 실제 실행 후 정직 분류(green / `fail` 재현 → 실패 테스트 남기고 사람 에스컬레이션 / 안정화 실패 → `test.fixme`)?
- [ ] **SCAFFOLD 폴백** — 앱/driver 없을 때 `⚠ UNVERIFIED` + 리포트 명시, 조용한 skip 없음?
- [ ] 백엔드/생성 타입 안 건드림, 시크릿 평문 하드코딩 없음?
- [ ] 요약 리포트(green / failing-bug / fixme / unverified 카운트) 나옴?

## 4. 실전 함정 (Gotcha)

1. **버전 캐시**: 플러그인 버전이 안 오르면 update 해도 no-op.
2. **로컬 복사본 드리프트**: STEP 0-B 복사본이 플러그인본을 가림 → 테스트 후 삭제.
3. **Playwright 미설치**: green-gate 불가 → 기껏해야 scaffold. 제대로 검증하려면 Playwright 있는 프로젝트.
4. **driver = 브라우저 1개 공유**: 탐색 레인 직렬화(agentic-testing 정책). 같은 브라우저로 병렬 탐색 금지.
5. **시크릿**: 로그인 비번은 env/`storageState`로만. spec·리포트에 평문 절대 금지.
6. **입력 포맷 고정**: `test-scenario-doc`의 `SCENARIOS` 구조 필수. 손으로 쓴 목록/마크다운은 매핑 안 됨.

## 5. 범위 경계

- 이 실행의 목적 = **스킬 동작 검증**이지 타깃 프로젝트의 정식 e2e 스위트 구축이 아님(생성 spec = 부산물).
- **스킬이 오작동하면 → 타깃에서 패치 금지.** ai-harness의 `skills/scenario-to-e2e/SKILL.md`로 피드백해 거기서 iterate. 타깃엔 로컬 복사본만, 고치지 않는다.
- 이 기록은 scenario-to-e2e **v1 사용법**. 스킬 명세가 바뀌면 별도 갱신.

## 6. 커밋 / 참고

- **커밋**: `59dd50a` (v1.7.0) · `03444ef` (v1.7.1 후속) · base `7e21118`
- **스킬**: `skills/scenario-to-e2e/SKILL.md`
- **입력 스킬**: `test-scenario-doc` (`/test-scenario-doc`)
- **house style**: `e2e-testing` · **규율(generate→run→green)**: `agentic-testing`
- **실행 명령 예**: `npx playwright test tests/e2e/from-scenarios/` (타깃 PM에 따라 `bunx` / `pnpm exec`)
