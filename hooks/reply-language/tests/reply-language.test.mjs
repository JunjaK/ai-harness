// Tests for hooks/reply-language.mjs. Run: node --test hooks/reply-language/tests/reply-language.test.mjs
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';

import { decide, judgeReply } from '../../reply-language.mjs';

const HOOK = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'reply-language.mjs');

const ENGLISH = `I've finished the change. The hook now checks the final reply before stopping.

- Added a judge function that counts sentences.
- Tests cover English, Korean, and code-heavy replies.

Let me know if you want me to open the PR.`;
// Real reply shape: Korean sentences + developer terms, paths, commands
const KOREAN_WITH_TERMS = `PR #368을 만들었습니다. 머지는 하지 않았습니다.

- \`.codex/hooks.json\`: Codex는 deny로 막습니다
- worktree에서 연 Codex는 repo hook을 실행하지 않습니다(원인 미확인)
- CI(전 스택 plan) 51건 중 47건이 아직 진행 중입니다

| 항목 | 상태 |
|---|---|
| Stop hook | 됨 |
| Windows | 미검증 |

Run workflow를 누르면 apply가 진행되고, terraform plan 결과는 job summary에 붙습니다.`;
const CODE_HEAVY = `수정했습니다.

\`\`\`js
// This function returns the plan for the current repository and logs it.
export function plan() { return readPlan(); }
// It also handles the fallback when the repository is not a git checkout.
\`\`\``;

describe('judgeReply', () => {
  it('sends an English reply back', () => assert.equal(judgeReply(ENGLISH).block, true));
  it('passes Korean sentences with developer terms, paths and a table', () => assert.equal(judgeReply(KOREAN_WITH_TERMS).block, false));
  it('ignores English inside code blocks', () => assert.equal(judgeReply(CODE_HEAVY).block, false));
  it('passes short and empty replies', () => {
    for (const text of ['Done.', 'All tests pass.', 'OK', '', null, undefined, 'I have opened the PR for review.']) assert.equal(judgeReply(text).block, false, String(text));
  });
  it('ignores command-only lines (inline code)', () => {
    const commands = '다음 순서로 실행합니다.\n- `git push origin feat/68-optout --force-with-lease`\n- `terraform -chdir=terraform/platform/staging plan -input=false`';
    assert.equal(judgeReply(commands).block, false);
  });
  it('passes a Korean reply quoting one or two English lines when Korean sentences outnumber them', () => {
    const quoted = '확인했습니다.\n오류 문구는 다음과 같습니다.\nCommand blocked by PreToolUse hook because the target is production.\nThe plan stack does not match the approved target.\n원인은 경로 판정입니다.\n고쳐서 다시 돌렸습니다.';
    assert.deepEqual(judgeReply(quoted), { english: 2, korean: 4, block: false });
    assert.equal(judgeReply('확인했습니다.\nCommand blocked by PreToolUse hook because the target is production.\nThe plan stack does not match the approved target.').block, true);
  });
});

describe('decide', () => {
  const on = { CLAUDE_PLUGIN_OPTION_KOREAN_REPLY: 'true' };
  it('is off unless the option is exactly "true"', () => {
    for (const env of [{}, { CLAUDE_PLUGIN_OPTION_KOREAN_REPLY: 'false' }, { CLAUDE_PLUGIN_OPTION_KOREAN_REPLY: '' }]) {
      assert.equal(decide({ last_assistant_message: ENGLISH }, env), '', JSON.stringify(env));
    }
  });
  it('blocks an English reply once, passes the second Stop and Korean replies', () => {
    assert.equal(JSON.parse(decide({ last_assistant_message: ENGLISH }, on)).decision, 'block');
    assert.equal(decide({ last_assistant_message: ENGLISH, stop_hook_active: true }, on), '');
    assert.equal(decide({ last_assistant_message: KOREAN_WITH_TERMS }, on), '');
  });
  it('runs as a hook process (stdin JSON → stdout decision)', () => {
    const run = (/** @type {object} */ input, /** @type {string} */ value) =>
      spawnSync(process.execPath, [HOOK], { input: JSON.stringify(input), encoding: 'utf8', env: { ...process.env, CLAUDE_PLUGIN_OPTION_KOREAN_REPLY: value } });
    const blocked = run({ last_assistant_message: ENGLISH }, 'true');
    assert.equal(blocked.status, 0);
    assert.equal(JSON.parse(blocked.stdout).decision, 'block');
    const off = run({ last_assistant_message: ENGLISH }, 'false');
    assert.equal(off.status, 0);
    assert.equal(off.stdout, '');
    const bad = spawnSync(process.execPath, [HOOK], { input: 'not json', encoding: 'utf8', env: { ...process.env, CLAUDE_PLUGIN_OPTION_KOREAN_REPLY: 'true' } });
    assert.equal(bad.status, 0);
    assert.equal(bad.stdout, '');
  });
});
