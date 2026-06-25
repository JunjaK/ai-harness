---
title: harness 문서저장 시스템 (3-버킷 × LLM Wiki)
status: processing
topic: doc-storage
kind: plan
scope: harness
created: 2026-06-23
updated: 2026-06-23
related: []
---

# harness 문서저장 시스템 (3-버킷 × LLM Wiki) — 설계 spec

> ERT의 **3-버킷 문서저장 구조**를 하네스 일반 feature로 이식하고, 그중 agent 버킷(`.claude/wiki/`)을
> **Andrej Karpathy의 LLM Wiki 패턴**(복리로 쌓는 영속 지식베이스)으로 운영한다.

## 1. 배경 & 출처

- **출처 1 — 3-버킷 핸드오프**: `ert-dms-monorepo/_docs/active/planning/2026-06-23-doc-storage-3bucket-harness-handoff.md`. ERT repo에 적용한 3-버킷(`_docs`/`.claude·wiki`/`_note`)을 개인 하네스로 일반화 이식하는 것이 핸드오프의 핵심.
- **출처 2 — Karpathy LLM Wiki**: RAG식 매(쿼리)-재유도가 아니라, LLM이 **영속·복리 위키**(상호링크 마크다운)를 점진 구축·유지. raw sources → wiki → schema 3레이어, ingest/query/lint 연산, `index.md`(카탈로그) + `log.md`(연대기).

### 현 하네스 상태 (대조)
- `skills/docs-lifecycle/SKILL.md` 존재 — `_docs/` 라이프사이클(상태↔폴더, merge-on-completion). 단 `active/`·`complete/` 폴더는 아직 미생성(카테고리 레이아웃 사용 중).
- `skills/continuous-learning/SKILL.md` — learnings 저장(`.claude/session-state/learnings/`), §6 reuse·index, §7 **Knowledge-Base Maintenance Contract**(이미 "a wiki" 언급 + link-don't-duplicate / same-change-same-update / self-audit), instinct·스킬진화.
- `hooks/hooks.json` — PostToolUse가 `Edit|Write` 매칭 → `post-edit-warn.sh {file_path}` (현재 JS/TS console.log 등만 검사).
- `.claude/session-state/` 폴더만 있고 비어있음. `.claude/project-profile/` 미생성. `.claude/wiki/`·`_note/` 없음.

## 2. 목표 / 비목표

**Goals**
- 3-버킷 소유권 모델을 **하네스 일반 feature**로 이식(포터블, ERT 특정값 제거).
- **포터블 판별기준**을 원칙으로 박아 새 프로젝트가 스스로 분류.
- `_note/` **read-only soft 가드**(규칙 + 경고 hook).
- `.claude/wiki/`를 **Karpathy LLM Wiki**로 운영(ingest/query/lint, 복리 합성).
- `continuous-learning`과 **중복 0**(별도 `wiki` 스킬, CL은 공급·거버넌스).
- 프로젝트 초기화 시 **부트스트랩**(/team-init).

**Non-goals**
- ERT 특정 작업(19개 노트 `_docs` 졸업, submodule pointer) — 무관.
- **hard 가드**(PreToolUse 차단 + override) — soft 채택.
- **검색엔진**(qmd 등) — `index.md`로 충분(소규모), 후속.
- 위키를 임베딩 RAG로 — `index.md` 기반 네비.
- 위키가 learnings/instinct를 흡수 — CL이 그대로 소유.

## 3. 핵심 원칙

1. **포터블 판별기준(the real IP, MUST)**: *"이 도구를 다른 agent CLI로 바꿔도 그대로 의미 있는가? → 그렇다면 프로젝트/사람 소유(repo root, `_` 접두사). agent 전용 지식이면 `.claude/` 하위."* 축은 **이름(`_`)이나 위치가 아니라 소유권·도구결합도**다. ("전부 `_`니까 같이" / "전부 `.claude` 밑으로"는 잘못된 그루핑.)
2. **`_note` read-only 불변식(load-bearing)**: agent는 `_note/`를 **명시 요청 시에만 수정**, 그 외엔 참고만. 이게 안 지켜지면 `_note`는 규칙 없던 시절의 junk drawer로 회귀(핸드오프의 출발점). **가드 배선까지가 "완료"**.
3. **Link don't duplicate(CL §7)**: wiki는 라우팅+안정 개요를 갖고 SSOT(코드/`_docs`/`_note`)를 **링크**. 사실을 복제하면 사본이 곧 stale.

## 4. 아키텍처 — 3 버킷 + 거버넌스

| 버킷 | 소유 | 위치 | 자동화 정책 | Karpathy 레이어 |
|---|---|---|---|---|
| **`_docs/`** | 프로젝트 | repo root | `docs-lifecycle`(자동이동·complete 병합·git rm) | 원천+작업 |
| **`_note/`** | 사람 | repo root, 중앙 1곳 | **agent read-only**(명시 요청 시만 수정), frontmatter·lifecycle 면제 | raw sources |
| **`.claude/wiki/`** | agent | `.claude/`(도구 결합) | agent 소유, ingest/query/lint로 유지 | the wiki |
| 거버넌스 | — | `docs-lifecycle` + `CLAUDE.md` + `.claude/wiki/schema.md` | — | schema |

- `_docs/`는 기존 `docs-lifecycle` 내부 규약 **불변**. 3-버킷은 그 **둘레에** `_note`·`.claude/wiki`를 추가하는 것.
- Karpathy 매핑: raw sources = `_note`(사람) + 외부 + `_docs`(프로젝트 원천) / wiki = `.claude/wiki/`(agent 합성) / schema = `schema.md` + 규칙.

## 5. Phase A — 3-버킷 거버넌스 (foundational, 독립 출하)

### A-1. `docs-lifecycle` 확장
`skills/docs-lifecycle/SKILL.md`에 추가:
- **3-버킷 정의** 섹션(위 표: 버킷별 소유·위치·자동화 정책).
- **포터블 판별기준**(원칙 §3.1, MUST-style).
- **`_note/` 거버넌스** 하위섹션(핸드오프 D1–D5 일반화, ERT 특정값 제거):
  - D1: `_docs`에 병합하지 않고 별도 유지(top-level 분리 = 자동화 경계선).
  - D2: root 유지(도구 무관), `.claude/`로 옮기지 않음.
  - D3: **루트 중앙 1곳**(멀티 repo·submodule이면 개인 노트로 히스토리 오염 방지; 출처는 `_note/<source>/` 하위폴더로 보존).
  - D4: 기존 노트 **원형 보존**(강제 졸업 X, 오너 판단).
  - D5: **frontmatter·lifecycle 면제**(비정형 스크래치 tier).
  - **졸업 경로**: 오너 판단으로 `_note` → `_docs` 승격 가능.

### A-2. `_note` soft 가드
- **규칙**(docs-lifecycle + CLAUDE.md): agent는 `_note/`를 명시 요청 시에만 수정. docs-lifecycle의 자동 이동·complete 병합·`git rm` 대상에서 **`_note/` 명시 제외**.
- **hook**: `hooks/post-edit-warn.sh` 확장 — `file_path`가 `_note/` 하위면 경고 출력(예: `[warn] _note/ is human-owned (agent read-only); edit only on explicit request`). `hooks.json`은 이미 PostToolUse `Edit|Write` 매칭 → **스크립트만 확장, hooks.json 변경 불필요**.

### A-3. 부트스트랩
`commands/team-init.md` + `skills/project-analyzer/SKILL.md`(+`resources/profile-templates.md`): 프로젝트 초기화 시 (없을 때만) 스캐폴드:
- `_note/README.md` — `_note` 거버넌스 요약(사람 소유·agent read-only·면제·졸업경로).
- `.claude/wiki/` — `index.md`(빈 카탈로그) + `log.md`(빈 연대기) + `schema.md`(위키 관례 스텁, Phase B에서 채움).

### A-4. CLAUDE.md 등재
3-버킷 + 판별기준을 운영규칙으로 등재(문서저장 섹션). `_note` read-only 불변식 명시.

> **마일스톤 A**: 버킷 존재 + `_note` 보호 + 새 노트가 판별기준대로 올바른 버킷에 분류됨. **wiki 없이도 바로 사용 가능.**

## 6. Phase B — LLM Wiki 스킬 (capability)

### B-1. `skills/wiki/SKILL.md` (신규) — 3 연산
- **ingest** (사용자 주도·1건씩·감독, Karpathy 선호 흐름): 원천 읽기 → 핵심 추출 → 요약/entity 페이지 작성·갱신 → `index.md` 갱신 → 관련 페이지 **교차링크** → `log.md` append. 원천(코드/`_docs`/`_note`)은 **링크**(중복 금지). 한 소스가 10–15 페이지를 건드릴 수 있음. 원천 = `_note`/`_docs`(완료 시)/learnings/외부.
- **query**: 질의 → `index.md` 먼저 → 관련 페이지 drill → **인용 답변**. 좋은 답(비교·분석·발견)은 새 wiki 페이지로 **환류**(filing back) + log.
- **lint** (주기 헬스체크): 모순 / stale(코드 변경에 뒤처진 주장) / orphan(인바운드 링크 0) / 누락 교차링크 / 페이지 없는 중요 개념 / data gap. **= CL §7 self-audit + "verify it still exists" 규율 재사용**. 새 질문·소스 제안.

### B-2. 산출물 규약(`.claude/wiki/`)
- **`index.md`**(콘텐츠 카탈로그): 페이지별 링크+한줄요약+메타, 카테고리(entities/concepts/sources)별. query는 이걸 먼저 읽음.
- **`log.md`**(append-only 연대기): 일관 prefix `## [YYYY-MM-DD] ingest|query|lint | <title>` → `grep "^## \[" log.md | tail` 파싱 가능.
- **`schema.md`**(Karpathy schema 레이어): 위키 구조·페이지 포맷·관례·워크플로우 거버넌스. CLAUDE.md/docs-lifecycle가 가리킴. 페이지 frontmatter(tags/date/source-count) 선택.
- 페이지: entity/concept/overview/comparison 등. 모두 SSOT 링크 포함.

### B-3. continuous-learning 통합 (경계 명시)
- `learnings/` = wiki **ingest 원천 하나**. 고신뢰 project-stable learning은 wiki 페이지로 승격 가능(CL §6 profile 승격과 병행 — 중복 아닌 라우팅).
- §7 KB 유지계약(link don't duplicate / same-change-same-update / self-audit) = wiki **lint의 규율 정본**. `wiki` 스킬은 §7을 **링크**(복제 X).
- 스킬진화(3+ learnings → skill)는 **CL 유지**, wiki 무관.
- **경계**: CL = 패턴·본능 생애주기(*어떻게 일하나*) / wiki = 지식 합성(*무엇이 사실인가*).

> **마일스톤 B**: `.claude/wiki/`가 살아있는 복리 위키(ingest/query/lint 동작).

## 7. 데이터 흐름

```
raw sources ─┬─ _note/ (사람, read-only)         ┐
             ├─ _docs/ (프로젝트, 완료 시)        ├─(ingest, 사용자 주도)→ .claude/wiki/
             ├─ learnings/ (CL)                   │      ├ index.md (카탈로그)
             └─ 외부(기사·논문·…)                 ┘      ├ log.md (연대기)
                                                          └ <pages>.md (링크·합성)
                          (query) 질의 → index → drill → 인용답변 ─→ (좋은 답) 환류 to wiki
                          (lint)  주기 헬스체크 = CL §7 self-audit ─→ 모순/stale/orphan 수정·질문 제안
```

## 8. 컴포넌트 & 계약 (spec 델타)

**Phase A**
- 수정 `skills/docs-lifecycle/SKILL.md` — 3-버킷 정의 + 판별기준 + `_note` 거버넌스(D1–D5 일반화) + 자동화 제외 명시.
- 수정 `hooks/post-edit-warn.sh` — `_note/` 쓰기 경고.
- 수정 `commands/team-init.md` + `skills/project-analyzer/SKILL.md`(+`resources/profile-templates.md`) — 부트스트랩 스캐폴드(`_note/README.md`, `.claude/wiki/` 스텁).
- 수정 `CLAUDE.md` — 3-버킷 + 판별기준 운영규칙.

**Phase B**
- 신규 `skills/wiki/SKILL.md` — ingest/query/lint + 산출물 규약.
- 부트스트랩 템플릿 정의 — `.claude/wiki/schema.md` 스텁 내용(project-analyzer가 생성).
- 수정 `skills/continuous-learning/SKILL.md` — learnings→wiki ingest 포인터 + §7→wiki lint 포인터 + 경계 1줄.
- 수정 `CLAUDE.md`/`README.md` — `wiki` 스킬 등재.

## 9. 검증 (acceptance)

- **Phase A**: ① 빈/둘째 프로젝트에서 "새 비정형 노트 → 어디?" 분류 dry-run이 판별기준대로 나옴(핸드오프 게이트) ② `_note/` 편집 시 경고 발화 ③ 부트스트랩이 `_note/README.md`+`.claude/wiki/` 스텁 생성.
- **Phase B**: ① ingest 1건 → 요약페이지+`index.md`+`log.md`+교차링크 갱신 ② query → 인용답변(+환류) ③ lint → 심어둔 모순/orphan 탐지.

## 10. 미해결 / 후속
1. 검색엔진(qmd 등) — 위키 규모 커지면(소규모는 `index.md`로 충분).
2. hard 가드(PreToolUse 차단) — soft가 부족하다고 판명되면.
3. 멀티 repo/submodule에서 `_note` 중앙화 위치 — 프로젝트별 판단(핸드오프 D3).
4. 외부 raw 소스 수집(Obsidian Web Clipper 등) — 사용자 워크플로우, 하네스 밖.
5. 위키 페이지 frontmatter + Dataview/Marp 등 Obsidian 연동 — 선택, 후속.

## 11. 문서 위치
하네스 `_docs/` 관례 → 본 spec `_docs/active/processing/2026-06-23/2026-06-23-doc-storage-plan.md`, `_docs/index.md` 갱신(docs-lifecycle frontmatter).
