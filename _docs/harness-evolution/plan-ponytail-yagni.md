---
title: ponytail YAGNI decision-ladder 통합
status: processing
scope: harness
created: 2026-06-23
updated: 2026-06-23
related: []
---

# ponytail YAGNI decision-ladder 통합 — 설계 spec

> ponytail("the best code is the code you never wrote")의 YAGNI 결정 사다리를 하네스의 빌드-결정 에이전트에 *기질*로 증류하고, 계획·코드 두 게이트에서 over-engineering을 검수한다. 출처: <https://github.com/DietrichGebert/ponytail>

## 결정 (대화에서 확정)
- ponytail = **강한 런타임 의존**(impeccable 동형): `/ponytail-review` 호출 실패 시 ABORT + `/plugin install ponytail@ponytail` 안내. `plugin.json` manifest 미수정(5522155 교훈: 외부 마켓플레이스 manifest 의존은 로딩 깨짐 위험).
- "persona" = architect/designer가 ponytail식 **YAGNI 기질**을 갖게 함(= decision ladder 규율, 캐릭터 아님).
- 미니멀리즘은 **솔루션 복잡도만**; 테스트·검증·보안·접근성 불가침("lazy, not negligent").

## 구성
1. **단일 출처**: `coding-standards` §4 YAGNI를 7-rung **Decision Ladder** + 가드 + ponytail 포인터로 확장.
2. **기질 참조**: `team-architect-fe/be/infra`·`team-designer`·`web-architect`가 §4 ladder를 MUST 적용(스폰 서브에이전트에 닿도록 각 `.md`에 명시).
3. **계획 게이트(Phase 1)**: `plan-review`에 "Over-Engineering / YAGNI" 차원 추가(사다리로 architect 계획 검수).
4. **코드 게이트(Phase 4)**: `team-tester`에 `/ponytail-review` on diff 단계(미설치 시 ABORT + 설치 안내).
5. **종합**: `team-leader`가 두 게이트 결과를 승인게이트에서 종합판단.
6. **등재**: `CLAUDE.md`(Code Minimalism via ponytail) + `README`(설치).

## 적용 범위
기질 = architects + designer + web-architect / 종합 = team-leader / 제외 = tester(검수=철저함, 단 `/ponytail-review` *실행*은 함)·web-reviewer(AI Slop와 중복).

## 검증
- `coding-standards` §4에 ladder + 가드 존재; 5개 에이전트가 §4 참조; `plan-review`에 YAGNI 차원; `team-tester`에 `/ponytail-review` 단계(ABORT 포함); `CLAUDE.md`/`README` 등재.
- grep 구조 검증 + 가드 문구("lazy, not negligent", 불가침 목록) 존재 확인.

## 미해결 / 후속
- ponytail 모드(lite/full/ultra) 기본값 — 후속(현재 full 가정).
- `/ponytail-audit`(레포 전체) 정기 실행 — 후속.
