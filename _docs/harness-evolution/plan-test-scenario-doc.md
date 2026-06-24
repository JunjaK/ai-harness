---
title: test-scenario-doc 범용 스킬 + /test-scenario-doc command 통합
status: processing
scope: harness
created: 2026-06-24
updated: 2026-06-24
related: []
---

# test-scenario-doc 통합 — 설계 spec

> 사람 최종검수 레이어 도구. 자체완결 인터랙티브 QA 체크리스트 HTML 생성 스킬을 하네스 범용 스킬로 벤더링하고, **사람이 별도 요청 시** 호출하는 `/test-scenario-doc` command를 신설한다.

## 결정 (대화에서 확정)
- **배포**: `~/.claude/skills/test-scenario-doc/`(개인 스킬)을 하네스 `skills/test-scenario-doc/`로 **벤더링**(3파일, 바이트 일치 검증) + **개인 복사본 제거**(같은 `name` 두 곳 → 충돌·drift 방지, 단일 출처 = 하네스).
- **배선**: 워크플로우 자동생성 ❌ → **사람 요청 시에만** `/test-scenario-doc` command. 스킬 = 엔진(템플릿+가이드), 커맨드 = 명시적 진입점 (`/team-init`→`project-analyzer` 패턴과 동형).
- **위치**: 테스트 피라미드의 사람 최종검수 레이어 — vitest(단위) → e2e/agentic(자동) → **/test-scenario-doc(사람 수동 QA)**. `agentic-testing`(에이전트 검증) 바로 위.

## 구성
- `skills/test-scenario-doc/{SKILL.md, assets/test-scenarios-template.html, evals/evals.json}` — 벤더링(faithful copy, 무수정)
- `commands/test-scenario-doc.md` — 신규 command (on-demand, default 산출 위치 `_docs/qa/`)
- 등재: `CLAUDE.md`(Commands + Skills 표), `README`(Commands + Skills 표 + 트리)

## 검증
- 바이트 일치(SKILL 7467 / template 26399 / evals 1901) ✅, 개인 복사본 제거 확인 ✅
- 구조: command 존재 + 등재 grep ✅.
- ⚠️ 이미지 붙여넣기 UX **라이브 육안확인 미실시**(원 작성자 노트 — `file://…assets/test-scenarios-template.html` 열어 파일첨부/붙여넣기 1회 확인 권장).

## 미해결 / 후속
- eval 3종 실행 / description 트리거 최적화 / `.skill` 패키징 — 후속(원 작성자 노트).
