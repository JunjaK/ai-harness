---
title: brain-memory 기록 트리거 — 약한 연결 유지 결정 (harness 미통합)
status: complete
topic: brain-memory
kind: handoff
scope: harness
created: 2026-06-26
updated: 2026-06-26
related:
  - skills/brain-connect/SKILL.md
  - skills/continuous-learning/SKILL.md
  - memory/ai-harness/claude-brain-ssot.md
---

# brain-memory 기록 트리거 — 결정: 약한 연결 유지 (harness 미통합)

> **인수자에게**: 이건 **구현 지시가 아니라 결정 기록**이다. 한때 harness 에 `/remember` + Stop 넛지를 넣는 안(모델 A)을 설계했으나 — **데이터 중복/충돌 진단 결과 coupling 이 깊어져 brain-connect 의 brain-agnostic 원칙을 깬다**고 판단, **harness 에는 만들지 않기로 확정(2026-06-26)**. 아래는 근거와 대안.

## ⚠️ 결정 (한 줄)

**harness 에 brain-memory 기록 트리거(`/remember`·Stop 넛지)를 추가하지 않는다.** 약한 연결만 유지:

| 역할 | 담당 | |
|---|---|---|
| **작성(authoring)** | Claude Code **native "# Memory"** 메커니즘 | 상시 규칙. 사용자가 "기억해둬" 한마디로 결정적 발동 |
| **운반/sync** | **claude-brain** `sync.ps1` | SessionStart pull / SessionEnd push |
| **배선·recall·계약** | **brain-connect** 스킬 | junction + 계약, brain-agnostic (harness 는 brain 내부 모름) |

→ harness 는 brain memory 작성에 **무지(無知)** 한 상태를 유지. 명시 명령이 꼭 필요해지면 → **claude-brain repo 쪽**(저장소 소유자 곁), harness 아님.

## 왜 통합 안 하나 (근거 — 보존)

**1. coupling 이 brain-connect 원칙을 깬다.** harness `/remember` 를 제대로 만들면 harness 가 brain 내부를 알아야 함 — junction 감지, namespace 매핑, **MEMORY.md 인덱스 조작**, **dedup**, **pull-before-write**, cross-machine 인지. brain-connect 대전제(**harness=brain-agnostic, 계약만**)를 정면으로 뒤집음. 저장소 포맷의 소유자는 claude-brain → 작성 도구도 거기 있어야 포맷 변경에 lockstep(harness 에 두면 brain 이 포맷 바꾸는 순간 조용히 깨짐).

**2. 갭이 이미 메워져 있음.** 원 발단은 "native 메모리 작성이 확률적"이었는데 — native "# Memory"가 이미 junction 된 dir 에 작성하고 claude-brain 이 운반함. 사용자가 "기억해둬" 하면 결정적 발동. `/remember` 는 그 위 **설탕**일 뿐. marginal 이득 vs 큰 coupling 비용 = 비대칭.

**3. 데이터 중복/충돌 진단이 통합을 비추천으로 굳힘.** dedup 이 **100% 에이전트 판단, 구조적 강제 0**(유니크 키·결정적 slug 없음). 트리거를 harness 로 늘리면 노출만 커짐:

| 중복 경로 | 메커니즘 | git 가 잡나 |
|---|---|---|
| **cross-machine 의미 중복** | 회사컴 `slug-a`, 집컴(pull 전) 같은 사실 `slug-b` → 파일·인덱스 2개. 파일명이 달라 textual 충돌 없음 | ❌ 조용히 통과 |
| proactive + 명시 동일세션 | native 가 이미 저장한 걸 재조회 없이 또 저장 | n/a |
| MEMORY.md 중복 줄 | 인덱스 체크 없이 append | n/a |
| 진화하는 사실 | 갱신 대신 새 slug 생성 → stale+current 공존 | n/a |

claude-brain 에 이미 **144 파일/11 namespace** → "기존 전부 훑어 갱신"은 비현실적 retrieval 문제. 중복은 recall 을 오염(=correctness 저하). 이 위험은 brain-memory 가 **유발**하는 게 아니라 트리거를 늘려 **노출**시키는 것.

## 만약 나중에 명시 트리거를 원하면 (brain-side 설계 노트)

harness 아니라 **claude-brain repo** 에 둔다(store + 포맷 + dedup 로직과 co-locate). 그때 필수 구조 방어:
- **결정적 slug**: 같은 사실 = 같은 파일명 → cross-machine 재저장이 조용한 중복 대신 **덮어쓰기/충돌로 표면화**(silent-dup 의 단일 최대 방어).
- **pull-before-write + enumerate**: 쓰기 전 `sync.ps1 pull` 로 최신화 + `memory/<ns>/` 나열·`MEMORY.md` 대조 → 있으면 갱신.
- **MEMORY.md 유니크 체크**: append 전 동일 slug 줄 grep → in-place 갱신.
- 작성은 끝까지 에이전트-authored, **자동요약/지어내기 금지**(환각 하드라인). durable 없으면 "저장 안 함"이 정답.

## 배경 (재탐색 불필요)

- **brain memory 실체**: `~/.claude/projects/<key>/memory/` = Claude Code 네이티브 per-project 메모리가 brain 으로 junction 된 것. 포맷 = `<slug>.md`(frontmatter: name/description/metadata.type) + `MEMORY.md` 인덱스. 예시: claude-brain `memory/<ns>/*.md`.
- **경계 (중요)**: `continuous-learning`(HOW=패턴/instinct, `.claude/session-state/`, 프로젝트 로컬) ≠ brain memory(WHAT=facts, `memory/<project>/`, cross-machine). **합치지 말 것** — 서로 링크만.
- **발단**: claude-brain SSOT 세션에서 11 namespace junction·동기화 완료(그 repo `7f2cf48`, `memory/ai-harness/claude-brain-ssot.md`). recall·sync 자동화 후 "작성 트리거 없음" 갭이 보였고 → 본 결정으로 종결(native 가 그 갭을 이미 메움).

## 참고
- 약한 연결 계약: `skills/brain-connect/SKILL.md`.
- **기각된 harness-통합 설계 상세**(모델 A: `commands/remember.md` + `session-stop.sh` 넛지, 둘 다 brain 게이트, junction 감지·hook 충돌 분석 등): git 히스토리 **`4f529d7`** 의 이전 버전 참조. 위 근거로 기각 — **만들지 말 것.**
- 동기화 배경: claude-brain `memory/ai-harness/claude-brain-ssot.md` (HEAD `7f2cf48`).
