# Harness v2 Evolution Plan

> Status: Planning (Brainstorm)
> Date: 2026-04-16
> Sources: [gstack](https://github.com/garrytan/gstack), [everything-claude-code](https://github.com/affaan-m/everything-claude-code)

## Task Description

1. 두 레포에서 채택할 만한 추가 패턴 분석
2. 작업 이어서 진행하는 특화 커맨드 (`/checkpoint`) 설계
3. 웹 개발 요청에 특화된 에이전트 설계

---

## Part A: 채택할 패턴 (우선순위별)

### Tier 1 — 즉시 가치 (높은 ROI)

| # | 패턴 | 출처 | 핵심 가치 | 구현 범위 |
|---|------|------|-----------|-----------|
| 1 | **`/checkpoint` 커맨드** | gstack | 세션 간 작업 재개, 브랜치 전환 후 복귀 | 커맨드 1개 + 스킬 1개 |
| 2 | **`/health` 코드 품질 대시보드** | gstack | build/lint/test/dead-code 통합 점수 (0-10), 트렌드 추적 | 스킬 1개 |
| 3 | **`/ship` 배포 파이프라인** | gstack | 리뷰→테스트→버전→PR→푸시 비대화식 파이프라인 | 커맨드 1개 + 스킬 1개 |
| 4 | **웹 개발 전문 에이전트** | ECC | a11y + performance + SEO + 디자인 품질 통합 | 에이전트 1-2개 |
| 5 | **Fix-first 코드 리뷰** | gstack | 기계적 수정 자동, 판단 필요 사항만 배치 질문 | 기존 review 강화 |

### Tier 2 — 높은 가치 (중기)

| # | 패턴 | 출처 | 핵심 가치 |
|---|------|------|-----------|
| 6 | **AI Slop Detection** | gstack | AI가 만든 뻔한 UI 패턴 탐지 (보라색 그래디언트, 3열 그리드, 거품 radius 등) |
| 7 | **Silent Failure Hunter** | ECC | 삼켜진 예외, 빈 catch, 스택트레이스 손실 탐지 |
| 8 | **Hook 프로필 (minimal/standard/strict)** | ECC | 상황별 훅 조합 전환 |
| 9 | **Diff-aware 검증** | gstack | 변경된 파일만 테스트/리뷰 (피처 브랜치 최적화) |
| 10 | **`/retro` 회고** | gstack | git 분석 기반 주간 회고, 세션 감지, 생산성 메트릭 |

### Tier 3 — 탐색적 (장기)

| # | 패턴 | 출처 | 비고 |
|---|------|------|------|
| 11 | GAN 평가 프레임워크 | ECC | 코드 품질 경쟁 평가 (planner→generator→evaluator) |
| 12 | Conductor 멀티워크플로우 | gstack | 10-15 동시 스프린트 조율 |
| 13 | Conversation Analyzer | ECC | 대화 트랜스크립트에서 예방 가능한 실수 탐지 |

### 채택하지 않을 것

| 패턴 | 이유 |
|------|------|
| Browse headless browser (gstack) | Playwright MCP로 이미 커버 |
| Platform adapters (Cursor/Codex/Kiro) | 단일 플랫폼 사용 |
| Telemetry/analytics (gstack) | 개인 프로젝트에 과도 |
| Healthcare reviewer (ECC) | 도메인 특화, 범용 불필요 |

---

## Part B: `/checkpoint` 커맨드 설계

### 목적

중단된 작업을 이어서 진행. 세션 간, 브랜치 간, 컴팩션 후 모두 커버.

### 핵심 기능

```
/checkpoint               # 가장 최근 체크포인트 로드 + 계속
/checkpoint list          # 저장된 체크포인트 목록
/checkpoint save [title]  # 현재 작업 상태 명시적 저장
/checkpoint [id]          # 특정 체크포인트 복원
```

### 체크포인트 저장 내용

```markdown
# Checkpoint: {title}
**Branch**: {current git branch}
**Timestamp**: {ISO datetime}
**Plan**: {_docs/ 플랜 파일 경로, 있으면}

## Current Progress
- [x] Completed steps
- [ ] Remaining steps

## Modified Files
{git status snapshot — staged + unstaged}

## Key Decisions
- {결정}: {근거}

## Verified Approaches
- {작동 확인된 접근}: {증거}

## Failed Approaches
- {실패한 접근}: {이유}

## Blockers / Gotchas
- {주의 사항}

## Next Steps
1. {다음에 할 일 — 구체적으로}
2. ...
```

### 저장 위치

```
.claude/session-state/
├── checkpoints/
│   ├── latest.md                    # 최신 (항상 덮어씀)
│   ├── checkpoint-20260416-1430.md  # 타임스탬프별 아카이브
│   └── checkpoint-20260416-1100.md
```

### 자동 저장 트리거

| 트리거 | 동작 |
|--------|------|
| `/checkpoint save` | 수동 저장 |
| Stop 훅 | 자동 저장 (session-stop.sh 강화) |
| 컴팩션 전 | 자동 저장 (pre-compact.sh 강화) |
| 팀 워크플로우 페이즈 완료 | 각 페이즈 끝에 자동 저장 |

### 복원 워크플로우

```
1. /checkpoint 입력
2. latest.md 읽기
3. 브랜치 확인 — 현재 브랜치와 체크포인트 브랜치 비교
4. 플랜 파일 로드 (있으면)
5. 수정된 파일 목록으로 현재 상태와 비교
6. Next Steps 출력 → 바로 작업 시작
```

### 구현 파일

| 파일 | 유형 |
|------|------|
| `.claude/commands/checkpoint.md` | 커맨드 정의 |
| `.claude/skills/checkpoint/SKILL.md` | 체크포인트 관리 스킬 |
| `.claude/hooks/session-stop.sh` (수정) | 자동 저장 통합 |
| `.claude/hooks/pre-compact.sh` (수정) | 자동 저장 통합 |

---

## Part C: 웹 개발 전문 에이전트 설계

### 접근 방식

하나의 "web-developer" 만능 에이전트보다, **역할별 전문 에이전트 2개** 구성:

### 에이전트 1: `web-architect`

**역할**: 웹 개발 요청의 아키텍처 설계 + 기술 선택

```markdown
---
name: web-architect
model: opus
description: "웹 프론트엔드/풀스택 아키텍처 설계 전문. 컴포넌트 구조, 상태 관리, 
API 레이어, 라우팅, 성능 최적화 전략을 설계한다."
---
```

**담당 영역**:
- 컴포넌트 계층 구조 설계
- 상태 관리 패턴 선택 (React Query, Zustand, Jotai 등)
- API 레이어 설계 (REST/GraphQL, 캐싱, 에러 핸들링)
- 라우팅 구조 (App Router, Pages Router, file-based)
- 번들 최적화 전략 (code splitting, lazy loading)
- Core Web Vitals 목표 설정

**프로젝트 프로필 참조**:
- `stack.md`, `structure.md`, `code-style.md`, `ui-components.md`, `state-management.md`

### 에이전트 2: `web-reviewer`

**역할**: 웹 구현물의 품질 + 접근성 + 성능 + SEO 종합 검증

```markdown
---
name: web-reviewer
model: sonnet
description: "웹 구현물의 품질 검증 전문. 접근성(WCAG 2.2), 성능(Core Web Vitals),
SEO, 디자인 품질, AI Slop 탐지를 수행한다."
---
```

**검증 체크리스트** (5개 카테고리):

1. **접근성 (A11y)**
   - WCAG 2.2 AA 준수
   - 시맨틱 HTML (heading hierarchy, landmarks, ARIA)
   - 키보드 내비게이션 + focus-visible
   - 색상 대비 4.5:1 이상
   - alt 텍스트, aria-label

2. **성능 (Performance)**
   - FCP < 1.8s, LCP < 2.5s, TBT < 200ms, CLS < 0.1
   - 번들 크기 < 200KB (gzipped)
   - 이미지 최적화 (next/image, WebP, lazy loading)
   - 폰트 로딩 전략 (font-display: swap)

3. **SEO**
   - title/meta description 고유성
   - Open Graph + JSON-LD 스키마
   - heading 구조 (단일 h1, 순차적)
   - canonical URL, robots.txt, sitemap

4. **디자인 품질**
   - 시각적 계층 구조
   - 타이포그래피 일관성 (font scale, line-height)
   - 반응형 레이아웃 (모바일 퍼스트, 44px 터치 타깃)
   - 인터랙션 상태 (hover, focus, active, disabled, loading, error, empty)

5. **AI Slop Detection** (gstack 차용)
   - 보라색/바이올렛 그래디언트
   - 3열 피처 그리드 (아이콘 원 + 제목 + 설명)
   - 모든 것 가운데 정렬
   - 균일한 둥근 border-radius
   - 장식용 blob/원/물결 구분선
   - 이모지를 디자인 요소로 사용
   - 카드의 컬러 왼쪽 보더
   - 제네릭 히어로 문구 ("Welcome to...", "Unlock the power of...")
   - 쿠키커터 섹션 리듬

**출력 형식**:
```markdown
## Web Quality Report
| Category | Grade | Score | Key Issues |
|----------|-------|-------|------------|
| A11y     | B+    | 85    | Missing alt on 3 images |
| Performance | A  | 92    | Good CWV scores |
| SEO      | C     | 68    | Missing JSON-LD schema |
| Design   | A-    | 88    | Minor spacing inconsistency |
| AI Slop  | A     | 95    | No detected patterns |

**Overall Web Quality: B+ (85.6)**
```

### 팀 워크플로우 통합

```
Phase 1: web-architect (planning 참여 — Arch FE 보완/대체 가능)
Phase 4: web-reviewer (verification 참여 — Tester 보완)
Phase 5: web-reviewer (final review 참여 — security + web quality)
```

### 구현 파일

| 파일 | 유형 |
|------|------|
| `.claude/agents/web-architect.md` | 에이전트 정의 |
| `.claude/agents/web-reviewer.md` | 에이전트 정의 |

---

## Part D: 구현 우선순위 로드맵

### Sprint 1 — 핵심 (즉시)

| # | 항목 | 파일 수 |
|---|------|---------|
| 1 | `/checkpoint` 커맨드 + checkpoint 스킬 | 4 |
| 2 | `web-architect` + `web-reviewer` 에이전트 | 2 |
| 3 | Stop/PreCompact 훅에 자동 체크포인트 통합 | 2 (수정) |

### Sprint 2 — 확장 (단기)

| # | 항목 | 파일 수 |
|---|------|---------|
| 4 | `/health` 코드 품질 대시보드 스킬 | 1 |
| 5 | `/ship` 배포 파이프라인 커맨드 + 스킬 | 2 |
| 6 | Silent Failure Hunter 에이전트 | 1 |

### Sprint 3 — 고급 (중기)

| # | 항목 |
|---|------|
| 7 | Hook 프로필 시스템 (minimal/standard/strict) |
| 8 | Diff-aware 검증 (변경 파일만 테스트) |
| 9 | `/retro` 회고 커맨드 |
| 10 | Fix-first 코드 리뷰 강화 |

---

## Cross-Review Notes

### Arch A (FE) 관점
- web-architect는 기존 team-architect-fe와 역할이 겹침 → **보완 관계로 설계**
  - team-architect-fe: 팀 워크플로우 내 설계 (Phase 1)
  - web-architect: 독립 웹 개발 요청 시 직접 호출 가능
- AI Slop Detection은 web-reviewer에 포함 → 디자인 리뷰 품질 크게 향상

### Arch B (BE) 관점
- /checkpoint의 체크포인트 포맷은 git status와 동기화 필수
- /ship 파이프라인은 기존 verification-loop과 통합 필요
- 웹 에이전트의 SEO/성능 검증은 백엔드 API 레이턴시와도 연관

### 합의 사항
- /checkpoint는 **기존 session-state 인프라** 위에 구축 (새 디렉토리 불필요)
- web-architect/web-reviewer는 **독립 에이전트** + 팀 워크플로우 통합 모두 지원
- Sprint 1부터 시작, 나머지는 사용 피드백 후 결정

---

[View Plan Diagram](./plan-harness-v2.visual.html)
