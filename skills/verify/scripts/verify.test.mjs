// Tests for verify.mjs. Run: node --test skills/verify/scripts/verify.test.mjs
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import { countErrors, countTests, judge, parseConfig, runVerify } from './verify.mjs';

const CLI = join(dirname(fileURLToPath(import.meta.url)), 'verify.mjs');
const ok = (/** @type {number | null} */ status, output = '') => ({ status, output, timedOut: false });
const spec = (/** @type {Partial<import('./verify.mjs').StepSpec>} */ s) => ({ name: 'x', kind: 'test', run: 'r', baseline: 0, failBaseline: 0, timeoutMinutes: 30, ...s });

describe('parseConfig', () => {
  it('accepts the documented shape and fills defaults', () => {
    const r = parseConfig({ steps: [{ name: 'types', kind: 'errors', run: 'tsc -p app' }, { name: 'unit', kind: 'test', run: 'vitest run', changed: 'vitest run --changed {base}', failBaseline: 2, cwd: 'app' }, { name: 'fmt', kind: 'exit', run: 'prettier -c .' }] });
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.deepEqual(r.ok && r.steps.map((s) => [s.name, s.baseline, s.failBaseline, s.timeoutMinutes]), [['types', 0, 0, 30], ['unit', 0, 2, 30], ['fmt', 0, 0, 30]]);
  });
  it('rejects typos, wrong kinds, misplaced baselines and unsafe paths', () => {
    const bad = [
      null, [], {}, { steps: [] }, { steps: [{}] }, { step: [] },
      { steps: [{ name: 'a', kind: 'errors', run: 'x', baseLine: 3 }] },
      { steps: [{ name: 'a', kind: 'typecheck', run: 'x' }] },
      { steps: [{ name: 'a', kind: 'test', run: 'x', baseline: 1 }] },
      { steps: [{ name: 'a', kind: 'errors', run: 'x', failBaseline: 1 }] },
      { steps: [{ name: 'a', kind: 'test', run: 'x', changed: 'vitest --changed' }] },
      { steps: [{ name: 'a', kind: 'exit', run: 'x' }, { name: 'a', kind: 'exit', run: 'y' }] },
      { steps: [{ name: 'a,b', kind: 'exit', run: 'x' }] },
      { steps: [{ name: 'a', kind: 'exit', run: 'x', cwd: '/etc' }] },
      { steps: [{ name: 'a', kind: 'errors', run: 'x', baseline: -1 }] },
      { steps: [{ name: 'a', kind: 'exit', run: '  ' }] },
    ];
    for (const raw of bad) assert.equal(parseConfig(raw).ok, false, JSON.stringify(raw));
  });
});

describe('countErrors', () => {
  it('reads the common checkers', () => {
    assert.equal(countErrors('src/a.ts(3,1): error TS2322\nFound 3 errors in 2 files.'), 3);
    assert.equal(countErrors('\x1b[31m✖ 5 problems (2 errors, 3 warnings)\x1b[39m'), 2);
    assert.equal(countErrors('Analyzing app...\n12 issues found. (ran in 3.1s)'), 12);
    assert.equal(countErrors('4 errors, 1 warning, 0 informations'), 4);
    assert.equal(countErrors('Found 1 error.'), 1);
    assert.equal(countErrors('exited with code 1'), null);
  });
});

describe('countTests', () => {
  it('reads node --test, Vitest, Jest, Flutter, pytest, cargo and Gradle summaries', () => {
    assert.deepEqual(countTests('ℹ tests 7\nℹ pass 6\nℹ fail 1'), { total: 7, failed: 1 });
    assert.deepEqual(countTests(' Test Files  1 failed | 3 passed (4)\n      Tests  2 failed | 19 passed (21)'), { total: 21, failed: 2 });
    assert.deepEqual(countTests('      Tests  21 passed (21)'), { total: 21, failed: 0 });
    assert.deepEqual(countTests('Tests:       1 failed, 20 passed, 21 total'), { total: 21, failed: 1 });
    assert.deepEqual(countTests('00:01 +3: loading\r00:23 +303 ~1 -22: Some tests failed.'), { total: 325, failed: 22 });
    assert.deepEqual(countTests('00:05 +21: All tests passed!'), { total: 21, failed: 0 });
    assert.deepEqual(countTests('No tests ran.'), { total: 0, failed: 0 });
    assert.deepEqual(countTests('===== 3 failed, 18 passed, 1 error in 0.42s ====='), { total: 22, failed: 4 });
    assert.deepEqual(countTests('============ no tests ran in 0.01s ============'), { total: 0, failed: 0 });
    assert.deepEqual(countTests('test result: ok. 4 passed; 0 failed; 0 ignored\ntest result: FAILED. 2 passed; 1 failed;'), { total: 7, failed: 1 });
    assert.deepEqual(countTests('12 tests completed, 2 failed'), { total: 12, failed: 2 });
    assert.equal(countTests('ok  \texample.com/pkg\t0.01s'), null);
  });
});

describe('judge', () => {
  it('exit kind', () => {
    assert.equal(judge(spec({ kind: 'exit' }), 'c', ok(0)).state, '됨');
    assert.equal(judge(spec({ kind: 'exit' }), 'c', ok(2, 'boom')).state, '안 됨');
    assert.match(judge(spec({ kind: 'exit' }), 'c', { status: null, output: '', timedOut: true }).summary, /timed out/);
  });
  it('errors kind: exit 0 passes; counts above or unreadable fail; at or under a non-zero baseline is unverified', () => {
    assert.equal(judge(spec({ kind: 'errors' }), 'c', ok(0)).state, '됨');
    assert.equal(judge(spec({ kind: 'errors' }), 'c', ok(2, 'Found 1 error.')).state, '안 됨');
    assert.equal(judge(spec({ kind: 'errors' }), 'c', ok(2, 'crashed')).state, '안 됨');
    assert.equal(judge(spec({ kind: 'errors', baseline: 5 }), 'c', ok(2, 'Found 6 errors.')).state, '안 됨');
    assert.equal(judge(spec({ kind: 'errors', baseline: 5 }), 'c', ok(2, 'Found 0 errors.')).state, '안 됨');
    const under = judge(spec({ kind: 'errors', baseline: 5 }), 'c', ok(2, 'Found 5 errors.'));
    assert.equal(under.state, '미검증');
    assert.match(under.summary, /signatures not compared/);
  });
  it('test kind: empty runs and new failures fail; unreadable passes and baseline-level failures are unverified', () => {
    assert.equal(judge(spec({}), 'c', ok(0, 'ℹ tests 5\nℹ fail 0')).state, '됨');
    assert.equal(judge(spec({}), 'c', ok(0, 'ℹ tests 0\nℹ fail 0')).state, '안 됨');
    assert.equal(judge(spec({}), 'c', ok(0, 'all good')).state, '미검증');
    assert.equal(judge(spec({}), 'c', ok(1, 'all bad')).state, '안 됨');
    assert.equal(judge(spec({}), 'c', ok(1, 'ℹ tests 5\nℹ fail 0')).state, '안 됨');
    assert.equal(judge(spec({}), 'c', ok(1, 'ℹ tests 5\nℹ fail 1')).state, '안 됨');
    assert.equal(judge(spec({ failBaseline: 22 }), 'c', ok(1, '00:23 +303 -23: Some tests failed.')).state, '안 됨');
    const atBaseline = judge(spec({ failBaseline: 22 }), 'c', ok(1, '00:23 +303 -22: Some tests failed.'));
    assert.equal(atBaseline.state, '미검증');
    assert.match(atBaseline.summary, /names not compared/);
  });
});

describe('runVerify', () => {
  const root = realpathSync(tmpdir());
  const steps = [spec({ name: 'types', kind: 'errors', run: 'tc' }), spec({ name: 'unit', run: 'ut', changed: 'ut --changed {base}' }), spec({ name: 'e2e', run: 'e2e' })];
  /** @type {string[]} */
  const ran = [];
  const runner = (/** @type {string} */ command) => {
    ran.push(command);
    return command === 'tc' ? ok(0) : ok(0, 'ℹ tests 3\nℹ fail 0');
  };
  it('runs every step, combines verdicts, and scopes only steps with a "changed" command', () => {
    ran.length = 0;
    const r = runVerify({ root, steps, run: runner, changedBase: 'main', head: 'abc1234 · feat' });
    assert.equal(r.ok, true);
    if (!r.ok) return;
    assert.deepEqual(ran, ['tc', 'ut --changed main', 'e2e']);
    assert.equal(r.result, '됨');
    assert.match(r.block, /unit: 됨 — `ut --changed main` → 3 tests, 0 failed · changed vs main/);
    assert.match(r.block, /e2e: 됨 .*full run \(no "changed" command\)/);
    assert.match(r.block, /Persistence: fill in/);
  });
  it('안 됨 wins over 미검증, 미검증 over 됨; --only selects and rejects unknown names', () => {
    const mixed = runVerify({ root, steps, run: (c) => (c === 'tc' ? ok(0) : c === 'ut' ? ok(0, 'no counts') : ok(1, 'ℹ tests 2\nℹ fail 1')) });
    assert.equal(mixed.ok && mixed.result, '안 됨');
    const unverified = runVerify({ root, steps, only: ['types', 'unit'], run: (c) => (c === 'tc' ? ok(0) : ok(0, 'no counts')) });
    assert.equal(unverified.ok && unverified.result, '미검증');
    assert.equal(unverified.ok && unverified.steps.length, 2);
    const unknown = runVerify({ root, steps, only: ['lint'], run: runner });
    assert.match(unknown.ok ? '' : unknown.error, /no step named lint/);
  });
  it('refuses a cwd outside the repo', () => {
    const repo = mkdtempSync(join(tmpdir(), 'harness-verify-cwd-'));
    try {
      const r = runVerify({ root: realpathSync(repo), steps: [spec({ name: 'a', kind: 'exit', run: 'x', cwd: '..' })], run: () => ok(0) });
      assert.match(r.ok ? '' : r.error, /outside the repo/);
    } finally {
      rmSync(repo, { recursive: true, force: true });
    }
  });
});

describe('CLI', () => {
  /** @param {object} config */
  function repo(config) {
    const root = mkdtempSync(join(tmpdir(), 'harness-verify-'));
    execFileSync('git', ['init', '-q', '-b', 'feat/x'], { cwd: root });
    writeFileSync(join(root, 'ok.test.mjs'), "import { test } from 'node:test';\ntest('a', () => {});\ntest('b', () => {});\n");
    writeFileSync(join(root, 'bad.test.mjs'), "import { test } from 'node:test';\ntest('c', () => { throw new Error('no'); });\n");
    mkdirSync(join(root, '.claude', 'project-profile'), { recursive: true });
    writeFileSync(join(root, '.claude', 'project-profile', 'verify.json'), JSON.stringify(config));
    execFileSync('git', ['-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'add', '.'], { cwd: root });
    execFileSync('git', ['-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-qm', 'init'], { cwd: root });
    return root;
  }
  const cli = (/** @type {string} */ cwd, /** @type {string[]} */ args = []) => spawnSync(process.execPath, [CLI, ...args], { cwd, encoding: 'utf8' });
  const node = `"${process.execPath}"`;

  it('exit 0 for 됨, 1 for 안 됨, 3 for 미검증, and writes _workspace/verify/<branch>.md', () => {
    const root = repo({ steps: [{ name: 'unit', kind: 'test', run: `${node} --test ok.test.mjs` }, { name: 'bad', kind: 'test', run: `${node} --test bad.test.mjs`, failBaseline: 1 }, { name: 'worse', kind: 'test', run: `${node} --test bad.test.mjs` }] });
    try {
      let r = cli(root, ['--only', 'unit']);
      assert.equal(r.status, 0, r.stderr);
      assert.match(r.stdout, /unit: 됨 .*2 tests, 0 failed/);
      assert.ok(existsSync(join(root, '_workspace', 'verify', 'feat-x.md')));
      r = cli(root, ['--only', 'unit,bad']);
      assert.equal(r.status, 3, r.stdout);
      assert.match(r.stdout, /bad: 미검증 .*1 failed ≤ baseline 1/);
      r = cli(root);
      assert.equal(r.status, 1, r.stdout);
      assert.match(r.stdout, /worse: 안 됨 .*1 failed > baseline 0/);
      assert.match(readFileSync(join(root, '_workspace', 'verify', 'feat-x.md'), 'utf8'), /Result: 안 됨/);
      r = cli(root, ['--json', '--only', 'unit']);
      assert.equal(JSON.parse(r.stdout).result, '됨');
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it('exit 2 for a missing or invalid verify.json, an unknown step, or a ref that is not a commit', () => {
    const root = repo({ steps: [{ name: 'unit', kind: 'test', run: 'true' }] });
    try {
      assert.equal(cli(root, ['--only', 'nope']).status, 2);
      assert.equal(cli(root, ['--changed', 'no-such-branch']).status, 2);
      assert.equal(cli(root, ['--changed', '--upload-pack=x']).status, 2);
      writeFileSync(join(root, '.claude', 'project-profile', 'verify.json'), '{"steps": [{"name": "u", "kind": "test", "run": "x", "baseLine": 1}]}');
      const invalid = cli(root);
      assert.equal(invalid.status, 2);
      assert.match(invalid.stderr, /unknown key\(s\) baseLine/);
      rmSync(join(root, '.claude', 'project-profile', 'verify.json'));
      const missing = cli(root);
      assert.equal(missing.status, 2);
      assert.match(missing.stderr, /team-init --update/);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});
