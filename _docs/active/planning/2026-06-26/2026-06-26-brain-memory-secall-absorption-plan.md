# secall → brain/harness 흡수 (rough plan)

> Status: Planning | Topic: brain-memory | Kind: plan | Created: 2026-06-26
> Mode: team-brainstorm (PLANNING ONLY — 구현 없음)
> [View Plan Diagram](./2026-06-26-brain-memory-secall-absorption-plan.visual.html)

## Task Description
오픈소스 **secall** (Rust, local-first "second brain": 세션 JSONL 자동 ingest → 정규화 → hybrid search(BM25+vector+RRF) → 2계층 Obsidian wiki + knowledge graph → MCP/REST/Web/Obsidian 인터페이스)을 분석해, 사용자의 Claude Code harness + claude-brain SSOT 생태계에 **흡수할 가치가 있는 기법**을 골라낸다. 하드 프레이밍: **결합/의존 금지 → 기법만 흡수**. 환각 방지 하드라인, 최소 ceremony/레이어, local-first, reuse-first, 공격적 스코프 컷.

## 한 줄 결론
secall의 본체 모델(세션 자동 ingest + **LLM 자동 wiki 생성**)은 사용자가 이미 거부한 **모델 C 그 자체**다 — 그리고 secall 자신의 품질 감사(p39)가 거부 근거(LLM wiki 정확성은 자동검증 불가)를 제공한다. 따라서 **시스템을 의존하지 말고**, secall이 자동 파이프라인 주변에 두른 **결정론적 안전장치 4개**만 이미 spec된 `/remember` + Stop-넛지(handoff)에 흡수한다. 벡터/임베딩·FTS5·graph 엔진·job queue·git-sync·multi-agent ingest는 전부 **SKIP** (heavy dep이거나 이미 해결됨이거나 이 규모에 YAGNI). 신규 스킬/데몬 0개, 신규 파일은 흡수가 모두 기존 handoff 구현 맵 위에 얹힌다.

## 중심 비교 — secall auto-LLM-wiki vs 사용자 agent-authored `/remember`
| | secall (auto) | 사용자 `/remember` (agent-authored) |
|---|---|---|
| authoring 주체 | 매 세션 hook이 LLM 자동 생성 | 에이전트가 세션 근거로 실제 사실만 추출 |
| 환각 노출 | **높음** — p39 spot-check: 정확성/완전성/톤 **자동채점 불가→빈칸**, placeholder가 live wikilink에 들어가 dead link 생성 | 낮음 — 근거 없으면 폐기(하드라인) |
| 신뢰 확보 수단 | 자동 파이프라인 + 결정론 lint/provenance/dedup로 **사후 방어** | 사람/에이전트-in-the-loop로 **사전 방어** |
| 판정 | = 거부된 모델 C. **depend 금지** | 채택됨. secall의 결정론 레이어만 여기 흡수 |

→ secall의 **자동성은 버리고**, 자동 파이프라인이 신뢰를 얻으려 두른 **결정론 레이어만** 가져온다. 이 레이어들은 author가 LLM이든 agent든 무관하게 가치 있고, agent-authored 모델에선 환각 방지를 **더 강화**한다.

## Plan

### Frontend (Arch A) — consumption/recall/wiki/authoring 측
모두 `commands/remember.md`(handoff 구현 맵에서 만들 파일) + 네이티브 "# Memory" 포맷 규약에 얹힌다. 신규 레이어 0.

- **[ABSORB-now] A. provenance `sources:`** — 각 메모리 항목에 출처 1줄(세션 id / commit hash / 파일경로). brain이 이미 prose로 commit hash를 박는 중 → **정형화는 신규 레이어 아님**. secall content-hash/union-merge는 **안** 가져옴(stable slug가 이미 dedup 키). 꽂는 곳: `remember.md` 절차(c) + 포맷 규약.
- **[ABSORB-now] B. source-대조 guard** — 추출 스텝을 "추출 + 각 사실을 세션 turn/코드/git 근거에 대조 → 미근거 폐기"로 강화. handoff의 환각 하드라인을 *passive 금지 → active 검증 절차*로. secall p39 "원본 세션 미전달→사실검증 불가" finding을 뒤집은 것. 꽂는 곳: `remember.md` 절차(b). **코드 0, 프롬프트 문구.**
- **[ABSORB-now] C. 결정론 구조 lint** — brain memory에 대한 secall L001/L002 + p39 link-교훈 인스턴스(전부 LLM 0): (1) `<slug>.md`↔`MEMORY.md` 1:1 고아/누락, (2) `[[...]]`/상대링크 실재 파일 해석, (3) 프론트매터 필수필드. continuous-learning §7 + wiki 스킬 lint **규율 재사용**. 꽂는 곳: `remember.md` 꼬리 셀프체크 + (선택) on-demand `/brain-lint`. **Stop hook 매세션 실행은 비추**(노이즈·매세션 PowerShell).
- **[ABSORB-later] D. stale-source pruning** — `sources:`가 사라진 세션/commit 가리키면 **삭제 아니라 flag만**. provenance(A) 깔린 후. brain memory는 세션보다 오래 사는 게 정상 → 약한 신호, **감사용만**.
- **[SKIP] E. 2계층 immutable-raw + derived vault** — 사용자는 이미 암묵 2계층(세션 transcript=raw, brain memory=derived). raw-vault 구축은 secall 본체 복제 = depend. provenance로 연결만(A).
- **[SKIP] F. backlink graph 엔진 / G. 별도 AI review 백엔드 / H. 벡터 wiki search** — F는 C에 접힘(MEMORY.md가 이미 `[[]]` 사용), G는 ceremony+secall 자체 버그, H는 secall 자신이 임계 미달인데 강행한 케이스(brain ~148 tiny 파일은 index로 충분).
- **[SKIP-but-note] I. insight-report 자기감사 패턴** — continuous-learning learnings/instincts와 90% 중복. file:line 앵커+severity 태그만 미세 개선. 임계경로 아님.

### Backend (Arch B) — ingestion/index/search/graph/sync 엔진 측
**근거 사실**: brain corpus = 148 `.md` / ~990KB curated markdown, Claude Code가 네이티브로 in-context 로드, recall+git-sync 이미 자동. secall 엔진은 수천 raw JSONL용(SQLite/FTS5 + ONNX/Ollama + HNSW + serve 데몬). **3 orders of magnitude + 런타임 모델 자체가 다름** → 거의 모든 엔진 기능 SKIP.

- **[ABSORB-now] #4. LLM-edge 환각 guard 형태** — secall `parse_llm_edges`의 *형태*(출력 스키마 강제 + relation allowlist + reject-empty + provenance 라벨)를 `/remember` 추출에 이식: 타입 안 맞는 사실은 coerce 말고 drop, 근거 없으면 drop, `**Why:/**How to apply:**`를 provenance 앵커로. = persona "스키마로 구조 강제". **markdown 명령 1개, 런타임 0.**
- **[ABSORB-now] #5. "원본 안 주면 guard는 가짜"** — `/remember`의 판정 근거는 **실제 세션 turn/diff/파일**을 가리켜야 함(소스는 라이브 세션에 in-context). 별도 요약-only LLM verify 패스 금지(secall `wiki.rs:463` 실패 그 자체).
- **[ABSORB-now] #6. silent-fail 금지(skipped/failed는 표면화)** — persona "조용한 실패=결함"과 1:1. `remember.md`(후보 N개 중 M개 저장, 2개 skip 이유), sync hook(나중). write path마다 1줄 count/요약. **메커니즘 없이 보고 습관.**
- **[ABSORB-now] #7. upsert-by-stable-key (해시는 제외)** — slug/경로를 안정 키로 in-place upsert + 인덱스 1줄. **이미 handoff에 있음** — secall `indexer.rs`가 옳은 규율임을 확인. **SHA-256은 명시적으로 안 함**(비싼 downstream 없음, git이 동일 내용 no-op). Q-A가 "임베딩 추가"로 뒤집히면 그때 재검토.
- **[ABSORB-later] #10. conflict pre-check + loud stop** — sync 스크립트가 rebase/merge/unmerged 상태(`.git/rebase-merge`, `MERGE_HEAD`, `diff --diff-filter=U`) 감지 시 조용히 진행 말고 명확히 중단. ROI 낮음(호스트-고유 파일, 충돌 드묾) → 나중 하드닝.
- **[SKIP] #1 벡터/임베딩(Ollama BGE-M3+HNSW+ONNX), #2 BM25/FTS5+Kiwi, #3 RRF, #8 graph 엔진, #9 git-sync(이미 해결), #11 wiki conflict merge, #12 job queue/cancel, #13 multi-agent JSONL ingest, #14 MD-as-SSOT(이미 그 아키텍처)** — heavy dep이거나 이미 해결됐거나 이 규모에 YAGNI.

### Depend-path (명시적 대비, register-only)
`secall mcp`를 그대로 붙이면 과거 **모든 raw 세션** 광역 search 가능(노력 최소). 하지만 (1) Rust+Ollama+ONNX+vault = 회피 대상 heavy daemon, (2) = 거부된 자동 LLM authoring, (3) Windows는 HNSW/Kiwi 비활성, (4) brain(curated·anti-hallucination)과 secall(automatic·lossy-broad)은 철학 충돌. → **brain authoring 경로엔 절대 넣지 않음.** "몇 달 전 뭐 했더라" 식 raw-transcript 광역 회상이 *실제로 필요해지면* brain **밖** 별도 standalone 도구로만 등록.

### File Assignment (흡수 대상 — 구현은 별도 /team-run)
| 측 | 대상 파일 | 흡수 항목 |
|---|---|---|
| FE/authoring | `ai-harness/commands/remember.md` (신규, handoff 구현 맵) | A provenance, B source-guard, C lint-tail, #4 schema-drop, #5 source-grounded, #7 upsert |
| FE/authoring | 네이티브 "# Memory" 포맷 규약 | A `sources:` 위치 (Q1 의존) |
| FE/authoring | (선택) `ai-harness/commands/brain-lint.md` (신규, on-demand) | C 결정론 lint |
| BE/honesty | `ai-harness/hooks/session-stop.sh` | #6 비차단 넛지 + skipped 표면화 |
| BE/sync | `claude-brain/sync.ps1` (or sync 스크립트) | #10 conflict pre-check (later) |

## Team Composition
- Architects: A(consumption/recall/wiki/authoring) + B(ingestion/index/search/graph/sync). **둘 다 사용됨**, 결론 수렴.
- Designers/Testers: **N/A (PLANNING ONLY).** 구현은 별도 `/team-run`.
- Architect C(infra/security): NO (운영 데이터·신규 endpoint·secret 없음, local-first markdown).
- UI/UX Master: NO (시각 요소 없음).
- Orchestration: standard.

## 사용자에게 물을 것 (2-3 결정)
1. **(중심) 임베딩/검색 욕구 — Q-A.** brain을 *검색*으로 꺼낼 일이 생기나, 아니면 네이티브 in-context 로드 + 가끔 grep으로 충분한가? raw 세션 transcript를 ingest할 의향이 있나? **양쪽 다 No면(강력 추천 디폴트): secall search 엔진 전부 미구축. ~990KB curated 코퍼스엔 FTS5도 과함, 벡터/HNSW/ONNX는 부조리.** curated markdown이 수천으로 커지면 1순위는 ripgrep-with-ranking → 그다음 FTS5, **벡터는 절대 1순위 아님**. raw-transcript search가 정말 필요하면 그것만 secall standalone(brain 밖)로 분리.
2. **provenance 위치 — Q-B.** 네이티브 "# Memory" 프론트매터에 `sources:` 커스텀 키 추가(machine-lintable, 단 네이티브 파서 호환 미확인) vs 본문 `**Source:**` 라인(파서 안전, lint 약함). 이 선택이 C lint 강도 결정. (추천: 파서 호환 먼저 확인 후 frontmatter, 안 되면 본문 라인.)
3. **guard/lint 강도·배치 — Q-C.** `/remember` 환각 guard를 secall식 구조 강제(스키마+allowlist+reject-empty)까지 갈까 prose 지시로 둘까? lint는 (a)`/remember` 내부 + (c)on-demand `/brain-lint` 권장, (b)Stop 매세션은 노이즈 위험. (추천: guard는 구조 강제 채택 — 하드라인의 최저비용 보험; lint는 (a)+(c).)

## 다음 단계
구현은 이 흡수 항목들을 기존 `brain-memory` handoff 구현 맵에 머지한 뒤 별도 `/team-run "brain-memory /remember + Stop nudge"`로. 본 brainstorm은 **그 spec에 흡수할 secall 기법을 확정**하는 단계.

## Implementation Notes
(Phase 3 — N/A, planning only)

## Test Results
(Phase 4 — N/A)

## Security Review
(Phase 5 — N/A; local-first markdown, 운영 데이터 없음)

## Escalation Log
(없음)
