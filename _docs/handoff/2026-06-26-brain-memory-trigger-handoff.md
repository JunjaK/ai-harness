---
title: brain-memory 기록 트리거(/remember + Stop 넛지) 설계 handoff
status: planning
topic: brain-memory
kind: handoff
scope: harness
created: 2026-06-26
updated: 2026-06-26
related:
  - skills/brain-connect/SKILL.md
  - skills/continuous-learning/SKILL.md
  - hooks/hooks.json
  - hooks/session-stop.sh
  - commands/checkpoint.md
---

# brain-memory 기록 트리거 Handoff

> **인수자(ai-harness 담당 agent)에게**: 이건 **구현 전 설계 합의** handoff 다. 설계는 수렴했고 **구현은 0%**. 아래 "구현 맵"의 파일을 만들면 된다.
> 발단: 별도 claude-brain SSOT 세션에서 **11개 프로젝트 메모리 namespace 를 brain 에 junction·동기화**하는 작업을 끝냈다(자세한 건 그 repo 의 `memory/ai-harness/claude-brain-ssot.md`). 그 결과 brain memory 의 **recall·sync 는 자동**이 됐는데, **"무엇을 기록할지(authoring)를 촉발하는 트리거가 없다"** 는 갭이 드러났다. 이 handoff 가 그 갭을 메우는 기능이다.

## ⚠️ 단 하나만 읽는다면

지금 brain memory(`~/.claude/projects/<key>/memory/` = Claude Code 네이티브 메모리, brain 으로 junction 됨)에 **기록을 시키는 트리거가 전무**하다 — 에이전트가 시스템 프롬프트 "# Memory" 규칙대로 기분 내킬 때만 쓴다(확률적). 이 기능은 그걸 **명시 트리거(`/remember`)** + **결정적 넛지(Stop 훅)** 로 만든다. **단 작성은 끝까지 에이전트-authored — 자동 요약/지어내기 금지(사용자 하드라인: 환각 데이터).** **확정**: 모델 A(`/remember` 명령 + Stop 넛지) + **명령·훅 둘 다 brain 연결 시에만 기능**(미연결=동작 안 함, 로컬 fallback 기록 없음). 남은 건 구현뿐.

## TL;DR 상태
| 영역 | 상태 |
|---|---|
| 설계 합의 (재사용 지점·경계·포맷) | ✅ 수렴 |
| 트리거 모델 | ✅ **A 확정** — `/remember` + Stop 넛지, **둘 다 brain 연결 시에만 기능** |
| 구현 (command / hook / skill) | ❌ 미착수 |
| 런타임 검증 | ❌ 미착수 |

## 배경 — 이미 있는 것 & 갭 (재탐색 불필요)

| 구성요소 | 위치 | 이 기능과의 관계 |
|---|---|---|
| **brain-connect** 스킬 | `skills/brain-connect/SKILL.md` | brain contract + junction 배선/감지 근거. "brain 연결됐나?" 게이트 로직을 여기서 재사용 |
| **continuous-learning** 스킬 | `skills/continuous-learning/SKILL.md` | 세션→패턴/instinct 추출. **단 저장소가 다름**: `.claude/session-state/`(프로젝트 repo 로컬) ≠ brain `memory/<project>/`(cross-machine 동기화). **합치지 말 것** |
| continuous-learning 의 핵심 원칙 (159행) | — | "스킬 발동 ~50–80% 확률, **훅은 100% 결정적**". → 트리거는 훅으로, **작성은 에이전트로** |
| 훅 배선 | `hooks/hooks.json` | `Stop`→`session-stop.sh` 이미 매 세션 끝에 돈다. 넛지는 여기 얹는다 |
| Stop 훅 본문 | `hooks/session-stop.sh` | 현재 session-state 아카이브 + checkpoint 저장 + `echo` 안내. 끝부분에 비차단 넛지 추가 지점 |
| brain memory 실체 | `~/.claude/projects/<key>/memory/` | **Claude Code 네이티브 per-project 메모리**가 brain 으로 junction 된 것. 포맷 = `<slug>.md`(frontmatter: name/description/metadata.type) + `MEMORY.md` 인덱스. 마이그레이션된 `<brain>/memory/carbon/` 등이 실제 예시 |

**갭**: 위 어디에도 **brain memory 에 써라** 를 촉발하는 트리거가 없다. continuous-learning 은 `.claude/session-state/` 만 채운다.

## 확정된 결정 — 모델 A + brain 연결 게이트

> **확정 (사용자, 2026-06-26)**: 모델 **A** = `/remember` 명령 + Stop 훅 넛지. **단 명령·훅 모두 brain 연결(junction) 시에만 기능** — 미연결이면 동작하지 않는다(설계 #1). 로컬-only 미동기화 기록은 하지 않는다. 아래 표는 선택 근거 기록용.

| | 트리거 모델 | trade-off |
|---|---|---|
| **A (추천)** | `/remember` 명령 + Stop 훅 **비차단 넛지** | 자동성(훅 100% 알림)+명시성(온디맨드) 둘 다, 노이즈 최소. 작성은 에이전트 |
| B | `/remember` 명령만 | 가장 안전·조용, 단 빼먹을 수 있음(스킬/사용자 호출 의존) |
| C | Stop 훅이 자동 **작성**까지 | 가장 자동, **검수 없는 기록 = 환각 위험 → 비추천** (사용자 하드라인 위반) |

> 넛지(A)는 **echo 만** 한다(예: `💡 이번 세션에 durable 한 사실 있으면 /remember 로 brain 에 저장`). Stop 을 `decision: block` 으로 막아 강제 작성시키지 말 것 — 매 세션 차단은 침습적. 작성 여부는 에이전트/사용자 판단.

## 설계 (합의됨)

1. **brain-연결 게이트 (확정)**: 명령·훅 **둘 다 brain 연결(junction) 시에만 기능**. 미연결이면 — `/remember` 는 **쓰지 않고** "brain 미연결: `/brain-connect` 먼저" 안내만, Stop 넛지는 **침묵**. **로컬-only(미동기화) 기록은 하지 않는다** (분산·혼동 방지 — 사용자 결정). harness 는 여전히 특정 brain 에 비의존(연결 여부만 감지).
2. **포맷 재사용**: 네이티브 "# Memory" 포맷 그대로(frontmatter + `MEMORY.md` 인덱스). **새 포맷 만들지 말 것.** 타입은 user|feedback|project|reference.
3. **작성 주체**: 에이전트가 세션에서 **실제 사실만** 추출. 자동 요약 금지. user/feedback/project 는 `**Why:** / **How to apply:**` 동반(네이티브 규칙).
4. **경계**: continuous-learning(HOW=패턴/instinct, 로컬) vs 이 기능(WHAT=facts, cross-machine). 서로 **링크만**. `/remember` 가 continuous-learning 의 learnings 를 덮어쓰지 않는다.
5. **범위 컷**: 완전 자동작성(세션 자동요약→memory)은 **이번 범위 아님**. 원하면 후속으로 draft→사용자 검수 모드 별도 설계.

## 구현 맵 (만들 것)

1. **`commands/remember.md`** — `/remember` 슬래시 명령. `commands/checkpoint.md`·`commands/brain-connect.md` 구조 미러. 절차:
   - (a) **게이트**: 프로젝트 key 계산 → `~/.claude/projects/<key>/memory` 가 junction(brain 연결)인지 감지. **미연결이면 (d)로 — 아무 기록 안 함.**
   - (b) 세션에서 durable·non-obvious 사실 추출(코드/깃에 이미 있는 건 제외 — 네이티브 Memory 규칙). **durable 한 게 없으면 "저장할 항목 없음"으로 종료 — 명령 충족하려 지어내지 말 것(환각 하드라인).**
   - (c) 네이티브 포맷으로 `<slug>.md` 작성 + `MEMORY.md` 인덱스 한 줄 추가. 기존 파일 있으면 갱신(중복 생성 금지).
   - (d) **미연결이면 기록하지 않고** "brain 미연결 — `/brain-connect` 먼저" 안내만 (로컬 fallback 기록 금지 — 확정).
2. **`hooks/session-stop.sh` 확장** — 끝부분에 비차단 넛지. 게이트: **brain 연결**(저렴한 bash-native 감지 — 아래 Gotcha; 매 세션 PowerShell 호출 회피) + substantive 세션(Edit/Write 발생 또는 `current.md` 존재). 단순 `echo` 만, 미연결이면 침묵.
3. **(선택) `skills/<name>/SKILL.md`** — "기억해둬" 같은 cue 에 자동 발동시키고 싶을 때만. 최소주의면 명령+훅으로 충분(레이어 1개 절약). 사용자 성향상 **스킬은 생략 가능**.
4. **`_docs/index.md`** — 이미 이 handoff 행 + topic `brain-memory` 를 추가해둠(아래 참고). 구현 spec/plan 문서 생기면 index 갱신.

## Gotcha 모음

- **junction 감지(bash/Windows)**: Git Bash 에서 junction 은 디렉토리로 보이고 `test -L` 이 **false** → 신뢰 불가. **분리 권장**: 훅(매 세션·크로스플랫폼)은 **bash-native** `realpath`/`readlink -f` 가 `~/.claude` 밖(brain repo)으로 빠지는지로 판정해 **매 세션 PowerShell 호출을 피한다**; `/remember` 명령(에이전트)은 PowerShell `(Get-Item '<path>' -Force).LinkType -eq 'Junction'` 로 확실히 판정.
- **버전 bump**: 구현 시 `commands/remember.md` + 훅 변경 = 기능 → plugin+marketplace **v1.4.0 bump + 문서(CLAUDE.md Commands 표·README) 갱신** 필수(harness 릴리스 규칙).
- **project key 계산**: `<절대 cwd>` 의 `: \ /` 를 `-` 로 치환(= Claude Code 키 규칙). `~` 안 풀림 주의 — 항상 절대경로.
- **환각 금지(하드라인)**: 모델 C(자동작성) 채택 금지. 작성은 항상 에이전트가 세션 근거로. 의심되면 안 쓰는 게 맞음.
- **continuous-learning 와 혼동 금지**: 저장 경로가 다르다(`.claude/session-state/` vs `memory/<project>/`). 이 명령은 후자만 건드린다.
- **MEMORY.md 인덱스 누락**: `<slug>.md` 만 쓰고 인덱스 빠뜨리면 recall 라우팅이 샌다. 항상 인덱스 한 줄 동반.
- **sync push 가드**: brain 의 `SessionEnd`→`sync.ps1 push` 는 트리가 dirty 일 때만 push. `/remember` 가 파일을 쓰면 dirty → 자동 push 됨(정상). 단 사용자가 수동 커밋해 트리가 clean 이면 그 커밋은 다음 dirty 까지 push 안 됨(claude-brain handoff 의 기존 gotcha).

## 범위 경계 (out-of-scope)
- 세션 **자동 요약→memory** 자동작성: 이번 아님(환각). 후속 draft→검수 모드로 분리.
- continuous-learning / brain memory **통합**: 안 함. 둘은 별개 시스템.
- 이 handoff 는 **ai-harness 기능** 작업. claude-brain 의 namespace junction·동기화 작업은 별개(그 repo `7f2cf48`에서 완료).

## 참고
- 발단 컨텍스트(11 namespace 편입·work/personal type·동기화 동작): claude-brain SSOT 메모리 `memory/ai-harness/claude-brain-ssot.md` (claude-brain repo, HEAD `7f2cf48`).
- 재사용 근거: `skills/brain-connect/SKILL.md`(contract/감지), `skills/continuous-learning/SKILL.md`(훅>스킬 원칙·경계), `hooks/hooks.json`·`hooks/session-stop.sh`(넛지 지점).
- 네이티브 메모리 포맷 실제 예시: claude-brain `memory/carbon/*.md` + `MEMORY.md`.
