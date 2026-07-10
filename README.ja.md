# AI Harness — Multi-Agent Team Workflow

[English](README.md) · [한국어](README.ko.md) · **日本語**

Claude Opus 向けの再利用可能な Claude Code ハーネスです。グリーンフィールドプロジェクトのブートストラップ（リサーチ → スキャフォールド → プロファイル）に加え、5 フェーズのマルチエージェントチームワークフロー（TDD、エスカレーションループ、worktree による並列化）、フルセットのテストスタック、ライフサイクル管理されたドキュメント保管システム、コードのミニマリズム規律、本能ベースの学習を備えています。

## Overview

専門化された AI エージェントが定義済みのフェーズを通じて協働し、機能の実装、バグ修正、コードのリファクタリングを行います。中核となるチームワークフローに加えて、ハーネスは以下を提供します。

- **テストスタック** — ユニット（Vitest）→ 決定論的 E2E（Playwright）→ **エージェント型 E2E**（Phase 4.5: エージェントがゴールを検証し、決定論的テストとして結晶化する）→ **人間による QA**（`/test-scenario-doc`、対話型チェックリスト）。[`agent-browser`](https://agent-browser.dev/) CLI とスキルがインストールされている場合、E2E / QA / スモークのための**推奨されるオンデマンドブラウザドライバ**となり、暗号化された **Auth Vault** によるヘッドレスログイン（パスワードが LLM に渡ることはありません）も利用できます。インストールされていない場合は Playwright のパスにフォールバックします。
- **ドキュメント保管（3 つのバケット）** — `_docs/`（プロジェクト所有、ライフサイクル管理）· `_note/`（人間が所有、エージェントは読み取り専用）· `.claude/wiki/`（エージェントが維持する、知識を蓄積していく **LLM wiki**）。ポータブルな所有権の判別基準によって分類されます。
- **コードのミニマリズム** — `ponytail` の YAGNI 判断ラダー。設計時に適用され、Phase 4 でレビューされます。
- **Renewal Mode Gate** — 些細でないリファクタリング / 修正 / 再設計は、**A（互換維持）** または **B（破壊的リニューアル）** の選択から始まります。Mode B はリスクブロック + 明示的な承認を必要とし、その後は後方互換のスキャフォールディングが再び入り込まないよう完全にコミット（anti-drift）します。
- **本能ベースの学習** — `continuous-learning` が、原子的で信頼度スコア付き、プロジェクトスコープの本能を捕捉し、スキル / コマンド / エージェントへと進化させます。
- **Ultracode オーケストレーション** — 有効化されている場合、ファンアウトフェーズが Workflow ツール経由で実行されます。

### Team Roles

| Role | Agent | Model | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | opus | 常時（Phase 1、Gate、エスカレーション） |
| Architect A (Frontend) | `team-architect-fe` | opus | Phase 1（B と並列） |
| Architect B (Backend) | `team-architect-be` | opus | Phase 1（A と並列） |
| Architect C (Infra/Security) | `team-architect-infra` | opus | Phase 1（オンデマンド）+ Phase 5（常時） |
| UI/UX Master | `team-uiux-master` | opus | Phase 2（条件付き） |
| Designer x N | `team-designer` | sonnet | Phase 3（並列、worktree で分離）; フルスタック / auth·payment·PII / 失敗後リトライ時 → opus |
| Tester x N | `team-tester` | sonnet | Phase 4（並列） |
| Agentic Tester | `team-agentic-tester` | opus | Phase 4.5（条件付き、Tester の PASS 後） |
| Web Architect | `web-architect` | opus | Web アーキテクチャ（単独、または FE を補完） |
| Web Reviewer | `web-reviewer` | sonnet | Web 品質監査（a11y、CWV、SEO、AI スロップ） |

### Workflow Phases

```
Phase 1: Planning
  Leader drafts plan → Arch A + B detail (parallel) → Cross-review → File assignment

Phase 2: UI/UX (conditional)
  UI/UX Master reviews and proposes changes

Leader Approval Gate
  Approve → Phase 3 | Reject → Phase 1

Phase 3: Implementation (TDD)
  Designer x N in parallel worktrees (Red-Green-Refactor)

Phase 4: Verification
  Tester x N (unit + E2E, loop until pass)

Phase 4.5: Agentic Testing (conditional)
  Agent explores goals → verifies → crystallizes deterministic tests
  (then human QA via /test-scenario-doc, before final sign-off)

Phase 5: Final Security Review
  Arch C security & infra audit → SHIP or escalate
```

### Escalation

- 各エージェントが自己判断します。簡単な修正（リトライ、最大 3 回）か、根本的な問題（上位へエスカレーション）か
- グローバルな再計画の上限: 無限ループを防ぐため 3 サイクル
- `/team` と `/team-run` はいずれもエスカレーションイベントをユーザーに報告します

## Commands

| Command | Description |
|---------|-------------|
| `/team-new` | グリーンフィールド — 空のリポジトリ → ディープリサーチ → スキャフォールド → シード済みプロファイルを生成し、`/team-run` に引き継ぎます |
| `/team-init` | 既存プロジェクトを分析 → プロファイルを生成（コードのあるプロジェクトでは最初に実行してください！） |
| `/team` | 対話モード — ユーザーが計画フェーズに参加します |
| `/team-run` | 自律モード — 完全自動実行 |
| `/team-brainstorm` | 計画のみ — Leader + Architects が議論し、実装は行いません |
| `/checkpoint` | セッション、ブランチ、コンパクションをまたいで作業状態を保存 / 復元します |
| `/docs-sweep` | 古くなった `_docs/` を回収し、孤立ドキュメントの不変条件を再検証します |
| `/test-scenario-doc` | オンデマンドの人間 QA チェックリスト HTML（人間による受け入れレイヤー） |
| `/brain-connect` | 任意の個人用 **brain** SSOT（マシン間で同期されるペルソナ + 自動メモリ）をハーネスとペアリング、または既存のものを再配置します |

## Installation (Plugin)

このハーネスは **Claude Code プラグイン**として配布されています。

```bash
# 1. Add the marketplace
/plugin marketplace add JunjaK/ai-harness

# 2. Install the plugin
/plugin install junjak-ai-harness@ai-harness
```

### Required User Configuration

プラグインマニフェストでは環境変数や権限を設定できません。**ユーザー**または**プロジェクト**の `settings.json` に以下を追加してください。

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"
  },
  "permissions": {
    "allow": [
      "Edit",
      "Write",
      "LSP",
      "Bash(git *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(bun *)",
      "Bash(bunx *)",
      "Bash(pnpm *)",
      "Bash(npx *)"
    ]
  }
}
```

> `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` は**必須**です — `/team`、`/team-run`、`/team-brainstorm` はクロスレビューのために `TeamCreate` に依存しています。
>
> `CLAUDE_HARNESS_ULTRACODE=1` は**任意**です — ランタイムの ultracode シグナルが存在しないヘッドレス / 非 Claude-Code 環境において、ultracode オーケストレーション（Workflow ツールによるファンアウト）を強制する明示的なオーバーライドです。CLAUDE.md の「Ultracode Orchestration」を参照してください。

### Dependencies

上記の env フラグに加えて、ハーネスはいくつかの外部ツールを使用します。フル機能を体験するにはこれらをインストールしてください。各ツールについて、未インストール時の挙動を以下に説明します。

| Tool | Used for | Without it |
|------|----------|-----------|
| **impeccable** plugin · [impeccable.style](https://impeccable.style/) | UI/UX デザイン品質 — `team-uiux-master` / `web-architect` / `web-reviewer` エージェントが `Skill("impeccable:impeccable", "<sub-command> [target]")` 経由で呼び出します | これらのエージェントは一時停止し、インストールを求めます |
| **ponytail** plugin · [repo](https://github.com/DietrichGebert/ponytail) | YAGNI ミニマリズム — Phase 4 が差分に対して `/ponytail-review` を実行します | Phase 4 がインストールを求めます（判断ラダーは `coding-standards` §4 にも凝縮されています） |
| **agent-browser** CLI + skill · [agent-browser.dev](https://agent-browser.dev/) | E2E / QA / スモークのための推奨オンデマンドブラウザドライバ + ヘッドレスな Auth-Vault ログイン（パスワードが LLM に渡ることはありません） | Playwright の `e2e-testing` / `agentic-testing` パスにフォールバックします |

```bash
/plugin marketplace add pbakaus/impeccable && /plugin install impeccable@impeccable
/plugin install ponytail@ponytail
npm i -g agent-browser && agent-browser install   # skill ships with the CLI
```

impeccable と ponytail はワークフロー実行前にインストールされていることが想定されています。agent-browser は任意ですが、ブラウザ作業をよりスムーズに進めるために推奨されます。

### First Run

```
/team-init                        # Scan project → generate .claude/project-profile/
/team "Add user authentication"   # Start a workflow
```

`/team-init` はプロジェクト内に `.claude/project-profile/` を生成します — すべてのエージェントがあなたのスタックと規約に適応します。

## Customization

### Adapting to Your Stack

エージェントはデフォルトでフレームワーク非依存です。プロジェクト向けに特化させるには以下を行います。

1. **team-architect-fe.md** — フロントエンドの規約を追加（コンポーネントパターン、状態管理、スタイリング）
2. **team-architect-be.md** — バックエンドの規約を追加（API パターン、ORM、データベース）
3. **team-architect-infra.md** — セキュリティチェックリストを追加（認証パターン、env 管理）
4. **team-designer.md** — テストフレームワークと TDD パターンを追加
5. **team-tester.md** — テストランナーのコマンドと E2E セットアップを追加

### Document Storage (3 buckets)

ドキュメントは**所有者**によって分類されます。ポータブルな判別基準は次のとおりです。*「エージェント CLI を入れ替えても、これは依然として意味を持つか？」* → はい = プロジェクト / 人間（リポジトリルートで `_` プレフィックス）。いいえ = エージェント専用（`.claude/`）。

| Bucket | Owner | Holds |
|--------|-------|-------|
| `_docs/` | project | プラン、スペック、ADR — ライフサイクル管理（`planning → processing → complete`）、完了時にサイドカーをマージ |
| `_note/` | human | 個人 / リサーチ / スクラッチノート — **エージェントは読み取り専用**（明示的な要求があった場合のみ編集）、frontmatter なし |
| `.claude/wiki/` | agent | **LLM wiki** — 蓄積され、相互リンクされた知識（ingest / query / lint）。SSOT へリンクし、複製はしません |

ハンドオフは `_docs/handoff/` に置かれます。`/team-init` は `_note/README.md` と `.claude/wiki/` をブートストラップします。ルールは `docs-lifecycle` および `wiki` スキルに定義されています。`_docs/index.md` はプラン変更のたびに更新されます。

## Supporting Skills

エージェントがワークフローの各フェーズで参照するスキルです。

| Skill | Phase | Purpose |
|-------|-------|---------|
| `greenfield-bootstrap` | `/team-new` | G0 intake → G1 deep-research → G2 stack decision → G3 user gate → G4 scaffold → G5 seeded profile |
| `plan-review` | Phase 1 | 実装前のプランの批判的レビュー + プラン前のヒアリング |
| `brainstorm` | Pre-Phase 1 (solo) | 軽量なソロ設計対話 → `_docs/` への設計（自動コミットなし）。`/team-brainstorm` のソロ版 |
| `coding-standards` | Phase 3 | 汎用コード品質ベースライン（strict TS） |
| `tdd-workflow` | Phase 3 | Red-Green-Refactor の TDD サイクル（Vitest 4.x） |
| `systematic-debugging` | Phase 3-4 | 一般的なデバッグ手法（根本原因 → パターン → 仮説 → 修正）。`debug` がその上に TS/LSP を重ねます |
| `debug` | Phase 3-4 | LSP 駆動のデバッグパターン（TS） |
| `e2e-testing` | Phase 4 | Tester 向けの Playwright E2E パターン |
| `agentic-testing` | Phase 4.5 | アダプターベースのエージェント型 E2E — ゴールを探索 → 検証 → 決定論的テストへ結晶化 |
| `agent-browser-e2e` | On-demand | CLI + スキルがインストールされている場合、E2E/QA/スモークおよび暗号化 Auth Vault によるヘッドレスログイン（パスワードが LLM に渡らない）に `agent-browser` CLI を優先利用。一度きりのゲートで、そうでなければ Playwright にフォールバック。フェーズには組み込まれていません |
| `test-scenario-doc` | Human acceptance | 対話型の人間 QA チェックリスト HTML — `/test-scenario-doc` でオンデマンド |
| `verification-loop` | Phase 4-5 | 6 フェーズの品質ゲート（build、type、lint、test、security、diff） |
| `contract-sync` | Phase 0 / BE→FE handoff | バックエンドの契約変更後に生成済み API クライアントを再生成し、型チェック + 利用箇所との突き合わせを行う |
| `security-review` | Phase 5 | Architect C 向けの OWASP Top 10 チェックリスト |
| `requesting-code-review` | Phase 3-5 / on-demand | タスク間 / マージゲート前にコードレビュー用サブエージェント（コンテキストを整えた状態）をディスパッチ |
| `plan-visualizer` | Phase 1+ | プランの HTML 図（チーム、フェーズ、ファイル、依存関係） |
| `project-analyzer` | Setup | プロジェクト構造の分析 → プロファイル生成 |
| `brain-connect` | Setup (per-machine) | 任意の個人用 **brain** SSOT（マシン間で同期されるペルソナ + 自動メモリ）をハーネスとペアリング — ペルソナ `@import` + メモリジャンクション + オプトインの同期フック。依存なしで、汎用コネクタテンプレートを同梱 |

横断的スキル（任意のフェーズ）: `token-optimization`、`continuous-learning`、`parallelization`、`dispatching-parallel-agents`、`subagent-orchestration`、`checkpoint`、`docs-lifecycle`、`handoff`、`wiki`。

一般的な API 設計パターンについては、Claude Code 組み込みの `api-design` スキルを直接利用してください（ハーネスはこれをラップしていません）。

## Plugin Structure

```
junjak-ai-harness/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Marketplace definition (single-repo)
├── agents/                      # 10 specialized agents
│   ├── team-leader.md
│   ├── team-architect-fe.md
│   ├── team-architect-be.md
│   ├── team-architect-infra.md
│   ├── team-uiux-master.md
│   ├── team-designer.md
│   ├── team-tester.md
│   ├── team-agentic-tester.md
│   ├── web-architect.md
│   └── web-reviewer.md
├── commands/                    # 8 slash commands
│   ├── team-new.md              # /team-new
│   ├── team-init.md             # /team-init
│   ├── team.md                  # /team
│   ├── team-run.md              # /team-run
│   ├── team-brainstorm.md       # /team-brainstorm
│   ├── checkpoint.md            # /checkpoint
│   ├── docs-sweep.md            # /docs-sweep
│   └── test-scenario-doc.md     # /test-scenario-doc
├── hooks/
│   ├── hooks.json               # Plugin hook registration
│   ├── session-stop.sh
│   ├── pre-compact.sh
│   └── post-edit-warn.sh
└── skills/                      # 28 workflow skills
    ├── team-workflow/
    ├── greenfield-bootstrap/
    ├── project-analyzer/
    ├── tdd-workflow/
    ├── verification-loop/
    ├── contract-sync/
    ├── docs-lifecycle/
    ├── handoff/
    ├── wiki/
    ├── agentic-testing/
    ├── test-scenario-doc/
    ├── security-review/
    ├── systematic-debugging/
    ├── dispatching-parallel-agents/
    ├── requesting-code-review/
    ├── brainstorm/
    └── ... (14 more)
```

### CLAUDE.md Note

プラグインはユーザープロジェクトに `CLAUDE.md` を注入できません。このリポジトリルートの `CLAUDE.md` はハーネスの運用原則を記述しています。フルのルールセットが必要なユーザーは、関連するセクションを自身のプロジェクトの `CLAUDE.md` にコピーしてください。

## License

MIT
