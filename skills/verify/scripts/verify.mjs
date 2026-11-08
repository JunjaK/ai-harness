#!/usr/bin/env node
// verify skill — run the project's authoritative gates from .claude/project-profile/verify.json and print an evidence
// block (reference/verification-loop.md: Baseline & Net-New, Vacuity guard). Ported from the company harness
// (qesg-harness scripts/lib/verify.mjs, v1.5.0, 2026-10-18); commands come from verify.json instead of a policy file.
//
// Verdicts per step (됨 / 미검증 / 안 됨, as in /debug):
//   kind "exit"    exit 0 → 됨, otherwise 안 됨.
//   kind "errors"  exit 0 → 됨. Otherwise the error count is read: unreadable or above `baseline` → 안 됨;
//                  at or below a non-zero baseline → 미검증 (counts only — error signatures are not compared).
//   kind "test"    0 tests ran → 안 됨; passed with an unreadable count → 미검증; failures above `failBaseline` →
//                  안 됨; at or below a non-zero failBaseline → 미검증 (failing test names are not compared).
// Overall: any 안 됨 → 안 됨, else any 미검증 → 미검증, else 됨. Exit 0 됨 · 1 안 됨 · 3 미검증 · 2 config/usage error.
// Steps a human or agent still fills (contract sync, planted violation, persistence) are listed as "fill in".
//
// Usage: node verify.mjs [--root <dir>] [--only <name,…>] [--changed <base-ref>] [--json]

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, realpathSync, statSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

/** @typedef {'됨' | '미검증' | '안 됨'} State */
/** @typedef {{ name: string, kind: 'exit' | 'errors' | 'test', run: string, cwd?: string, baseline: number, failBaseline: number, changed?: string, timeoutMinutes: number }} StepSpec */
/** @typedef {{ name: string, state: State, command: string, summary: string, tail?: string[] }} Step */
/** @typedef {(command: string, cwd: string, timeoutMs: number) => { status: number | null, output: string, timedOut: boolean }} Runner */

export const PROFILE_FILE = join('.claude', 'project-profile', 'verify.json');
const KINDS = new Set(['exit', 'errors', 'test']);
const STEP_KEYS = new Set(['name', 'kind', 'run', 'cwd', 'baseline', 'failBaseline', 'changed', 'timeoutMinutes']);
const REF = /^[A-Za-z0-9._/@~^-]+$/;

/**
 * Validate verify.json. Unknown keys are errors, so a typo (`baseLine`) cannot silently drop a baseline.
 * @param {unknown} raw
 * @returns {{ ok: true, steps: StepSpec[] } | { ok: false, error: string }}
 */
export function parseConfig(raw) {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, error: 'verify.json must be an object with "steps"' };
  const extra = Object.keys(raw).filter((k) => k !== 'steps' && k !== '$comment');
  if (extra.length > 0) return { ok: false, error: `unknown top-level key(s): ${extra.join(', ')}` };
  const list = /** @type {{ steps?: unknown }} */ (raw).steps;
  if (!Array.isArray(list) || list.length === 0) return { ok: false, error: '"steps" must be a non-empty array' };
  /** @type {StepSpec[]} */
  const steps = [];
  const seen = new Set();
  for (const [i, item] of list.entries()) {
    const where = `steps[${i}]`;
    if (typeof item !== 'object' || item === null || Array.isArray(item)) return { ok: false, error: `${where} must be an object` };
    const s = /** @type {Record<string, unknown>} */ (item);
    const unknown = Object.keys(s).filter((k) => !STEP_KEYS.has(k));
    if (unknown.length > 0) return { ok: false, error: `${where}: unknown key(s) ${unknown.join(', ')}` };
    if (typeof s.name !== 'string' || !s.name.trim() || s.name.length > 60 || s.name.includes(',')) return { ok: false, error: `${where}.name: 1–60 characters, no comma` };
    if (seen.has(s.name)) return { ok: false, error: `${where}.name "${s.name}" is used twice` };
    seen.add(s.name);
    if (typeof s.kind !== 'string' || !KINDS.has(s.kind)) return { ok: false, error: `${where}.kind must be "exit", "errors" or "test"` };
    if (typeof s.run !== 'string' || !s.run.trim()) return { ok: false, error: `${where}.run must be a command` };
    if (s.cwd !== undefined && (typeof s.cwd !== 'string' || !s.cwd || isAbsolute(s.cwd))) return { ok: false, error: `${where}.cwd must be a path relative to the repo root` };
    const count = (/** @type {string} */ key) => s[key] === undefined || (Number.isInteger(s[key]) && /** @type {number} */ (s[key]) >= 0);
    if (!count('baseline')) return { ok: false, error: `${where}.baseline must be a non-negative integer` };
    if (!count('failBaseline')) return { ok: false, error: `${where}.failBaseline must be a non-negative integer` };
    if (s.baseline !== undefined && s.kind !== 'errors') return { ok: false, error: `${where}.baseline applies to kind "errors" only` };
    if ((s.failBaseline !== undefined || s.changed !== undefined) && s.kind !== 'test') return { ok: false, error: `${where}: failBaseline and changed apply to kind "test" only` };
    if (s.changed !== undefined && (typeof s.changed !== 'string' || !s.changed.includes('{base}'))) return { ok: false, error: `${where}.changed must be a command containing {base}` };
    if (s.timeoutMinutes !== undefined && !(typeof s.timeoutMinutes === 'number' && s.timeoutMinutes > 0 && s.timeoutMinutes <= 120)) return { ok: false, error: `${where}.timeoutMinutes must be 0–120` };
    steps.push({
      name: s.name,
      kind: /** @type {StepSpec['kind']} */ (s.kind),
      run: s.run,
      ...(typeof s.cwd === 'string' ? { cwd: s.cwd } : {}),
      baseline: /** @type {number | undefined} */ (s.baseline) ?? 0,
      failBaseline: /** @type {number | undefined} */ (s.failBaseline) ?? 0,
      ...(typeof s.changed === 'string' ? { changed: s.changed } : {}),
      timeoutMinutes: /** @type {number | undefined} */ (s.timeoutMinutes) ?? 30,
    });
  }
  return { ok: true, steps };
}

/** @param {string} output */
const plain = (output) => output.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, '').replace(/\r(?!\n)/g, '\n');

/**
 * Error count from type-check / lint / analyze output, or null.
 * eslint "✖ N problems (E errors, W warnings)", tsc / vue-tsc / mypy / biome "Found N errors",
 * dart / flutter analyze "N issues found", pyright "N errors, W warnings", then a generic "N errors".
 * @param {string} output
 */
export function countErrors(output) {
  const text = plain(output);
  const eslint = /✖ \d+ problems? \((\d+) errors?, \d+ warnings?\)/.exec(text);
  if (eslint) return Number(eslint[1]);
  const patterns = [/Found (\d+) errors?/, /(\d+) issues? found/, /(\d+) errors?, \d+ warnings?/, /\b(\d+) errors?\b/i];
  for (const p of patterns) {
    const m = p.exec(text);
    if (m) return Number(m[1]);
  }
  return null;
}

/**
 * Test totals from runner output, or null: node --test, Vitest, Jest, Flutter/Dart, pytest, cargo, Gradle.
 * @param {string} output
 * @returns {{ total: number, failed: number } | null}
 */
export function countTests(output) {
  const text = plain(output);
  const num = (/** @type {RegExp} */ re, /** @type {string} */ s) => {
    const m = re.exec(s);
    return m ? Number(m[1]) : 0;
  };
  const node = /ℹ tests (\d+)/.exec(text);
  if (node) return { total: Number(node[1]), failed: num(/ℹ fail (\d+)/, text) };
  const vitest = /^\s*Tests\s+([^\n(]*)\((\d+)\)/m.exec(text);
  if (vitest) return { total: Number(vitest[2]), failed: num(/(\d+) failed/, vitest[1]) };
  const jest = /^Tests:\s+([^\n]*?)(\d+) total/m.exec(text);
  if (jest) return { total: Number(jest[2]), failed: num(/(\d+) failed/, jest[1]) };
  const dart = [...text.matchAll(/\+(\d+)(?: ~(\d+))?(?: -(\d+))?: (?:All tests passed!|Some tests failed\.)/g)].at(-1);
  if (dart) return { total: Number(dart[1]) + Number(dart[3] ?? 0), failed: Number(dart[3] ?? 0) };
  if (/^No tests ran\.?$/m.test(text)) return { total: 0, failed: 0 };
  const pytest = [...text.matchAll(/^=+ (.*?) in [\d.]+s\b.*=+\s*$/gm)].at(-1);
  if (pytest && /\b(passed|failed|errors?|no tests ran)\b/.test(pytest[1])) {
    const failed = num(/(\d+) failed/, pytest[1]) + num(/(\d+) errors?/, pytest[1]);
    return { total: num(/(\d+) passed/, pytest[1]) + failed, failed };
  }
  const cargo = [...text.matchAll(/test result: \w+\. (\d+) passed; (\d+) failed/g)];
  if (cargo.length > 0) {
    const passed = cargo.reduce((n, m) => n + Number(m[1]), 0);
    const failed = cargo.reduce((n, m) => n + Number(m[2]), 0);
    return { total: passed + failed, failed };
  }
  const gradle = /(\d+) tests completed, (\d+) failed/.exec(text);
  if (gradle) return { total: Number(gradle[1]), failed: Number(gradle[2]) };
  return null;
}

/** @type {Runner} */
export function runShell(command, cwd, timeoutMs) {
  // An outer `node --test` passes NODE_TEST_CONTEXT, which makes an inner one report in its internal format
  const { NODE_TEST_CONTEXT: _ignored, ...env } = process.env;
  const r = spawnSync(command, { cwd, shell: true, encoding: 'utf8', timeout: timeoutMs, maxBuffer: 64 * 1024 * 1024, env });
  const timedOut = /** @type {NodeJS.ErrnoException | undefined} */ (r.error)?.code === 'ETIMEDOUT';
  return { status: r.error ? null : r.status, output: `${r.stdout ?? ''}\n${r.stderr ?? ''}${r.error ? `\n${r.error.message}` : ''}`, timedOut };
}

/** Last non-empty lines, attached as failure evidence. @param {string} output */
const tailOf = (output) => plain(output).split('\n').filter((l) => l.trim()).slice(-12);

/**
 * Judge one finished step.
 * @param {StepSpec} spec
 * @param {string} command
 * @param {{ status: number | null, output: string, timedOut: boolean }} r
 * @returns {Step}
 */
export function judge(spec, command, r) {
  const base = { name: spec.name, command };
  if (r.status === null) return { ...base, state: '안 됨', summary: r.timedOut ? `timed out after ${spec.timeoutMinutes} min` : 'the command did not start', tail: tailOf(r.output) };
  if (spec.kind === 'exit') {
    return r.status === 0 ? { ...base, state: '됨', summary: 'exit 0' } : { ...base, state: '안 됨', summary: `exit ${r.status}`, tail: tailOf(r.output) };
  }
  if (spec.kind === 'errors') {
    if (r.status === 0) return { ...base, state: '됨', summary: `exit 0 (baseline ${spec.baseline})` };
    const n = countErrors(r.output);
    if (n === null) return { ...base, state: '안 됨', summary: `exit ${r.status}, error count unreadable`, tail: tailOf(r.output) };
    // A non-zero exit with 0 errors counted failed for another reason (crash, config error)
    if (n === 0) return { ...base, state: '안 됨', summary: `exit ${r.status}, but 0 errors counted`, tail: tailOf(r.output) };
    if (n > spec.baseline) return { ...base, state: '안 됨', summary: `${n} errors > baseline ${spec.baseline}`, tail: tailOf(r.output) };
    return { ...base, state: '미검증', summary: `${n} errors ≤ baseline ${spec.baseline} — counts only, error signatures not compared` };
  }
  const t = countTests(r.output);
  if (t === null) {
    return r.status === 0
      ? { ...base, state: '미검증', summary: 'exit 0, but the test count was not found in the output' }
      : { ...base, state: '안 됨', summary: `exit ${r.status}, test count unreadable`, tail: tailOf(r.output) };
  }
  if (t.total === 0) return { ...base, state: '안 됨', summary: '0 tests ran — an empty run is not a pass', tail: tailOf(r.output) };
  if (t.failed === 0) {
    return r.status === 0
      ? { ...base, state: '됨', summary: `${t.total} tests, 0 failed` }
      : { ...base, state: '안 됨', summary: `exit ${r.status} with 0 failures reported (${t.total} tests)`, tail: tailOf(r.output) };
  }
  if (t.failed > spec.failBaseline) return { ...base, state: '안 됨', summary: `${t.failed} failed > baseline ${spec.failBaseline} (${t.total} tests)`, tail: tailOf(r.output) };
  return { ...base, state: '미검증', summary: `${t.failed} failed ≤ baseline ${spec.failBaseline} (${t.total} tests) — counts only, failing test names not compared` };
}

/**
 * The working directory of a step, inside the repo.
 * @param {string} root real path
 * @param {StepSpec} spec
 */
function stepCwd(root, spec) {
  if (!spec.cwd) return { ok: true, cwd: root };
  const abs = resolve(root, spec.cwd);
  if (!existsSync(abs) || !statSync(abs).isDirectory()) return { ok: false, error: `${spec.name}: cwd ${spec.cwd} does not exist` };
  const real = realpathSync(abs);
  if (real !== root && !real.startsWith(root + sep)) return { ok: false, error: `${spec.name}: cwd ${spec.cwd} is outside the repo` };
  return { ok: true, cwd: real };
}

/**
 * Run the selected steps and build the evidence block.
 * @param {{ root: string, steps: StepSpec[], only?: string[], changedBase?: string, run?: Runner, head?: string }} o
 * @returns {{ ok: true, result: State, steps: Step[], block: string } | { ok: false, error: string }}
 */
export function runVerify({ root, steps, only, changedBase, run = runShell, head = '' }) {
  const unknown = (only ?? []).filter((n) => !steps.some((s) => s.name === n));
  if (unknown.length > 0) return { ok: false, error: `--only: no step named ${unknown.join(', ')} (have: ${steps.map((s) => s.name).join(', ')})` };
  const selected = only && only.length > 0 ? steps.filter((s) => only.includes(s.name)) : steps;
  /** @type {Step[]} */
  const results = [];
  for (const spec of selected) {
    const where = stepCwd(root, spec);
    if (!where.ok) return { ok: false, error: /** @type {string} */ (where.error) };
    const scoped = changedBase !== undefined && spec.changed !== undefined;
    const command = scoped ? /** @type {string} */ (spec.changed).replaceAll('{base}', /** @type {string} */ (changedBase)) : spec.run;
    const step = judge(spec, command, run(command, /** @type {string} */ (where.cwd), spec.timeoutMinutes * 60_000));
    if (changedBase !== undefined && spec.kind === 'test') step.summary += scoped ? ` · changed vs ${changedBase}` : ' · full run (no "changed" command)';
    results.push(step);
  }
  const states = results.map((s) => s.state);
  /** @type {State} */
  const result = states.includes('안 됨') ? '안 됨' : states.includes('미검증') ? '미검증' : '됨';
  const lines = [
    '## Verification evidence',
    `- Result: ${result} (automatic steps — finish the fill-in lines below before the final verdict)`,
    `- Tree: ${head || 'unknown commit'}${only && only.length > 0 ? ` · only ${only.join(', ')}` : ''}`,
    ...results.map((s) => `- ${s.name}: ${s.state} — \`${s.command}\` → ${s.summary}${s.tail ? `\n  \`\`\`\n${s.tail.map((l) => `  ${l}`).join('\n')}\n  \`\`\`` : ''}`),
    '- Contract: fill in — backend contract changed and the client is generated → contract-sync result / not applicable',
    '- Planted violation: fill in — a new check or gate → `plant.mjs` result line / not applicable',
    '- Persistence: fill in — saved data → DB value and the value after reload / not applicable',
  ];
  return { ok: true, result, steps: results, block: `${lines.join('\n')}\n` };
}

/** @param {string[]} args @param {string} cwd */
function git(args, cwd) {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim() : null;
}

/**
 * verify.json of this tree, else of the primary worktree (a linked worktree may not have the profile).
 * @param {string} root
 */
export function findConfig(root) {
  const here = join(root, PROFILE_FILE);
  if (existsSync(here)) return here;
  const common = git(['rev-parse', '--path-format=absolute', '--git-common-dir'], root);
  if (common) {
    const primary = join(dirname(common), PROFILE_FILE);
    if (existsSync(primary)) return primary;
  }
  return null;
}

/** @param {string[]} argv */
function main(argv) {
  const value = (/** @type {string} */ flag) => {
    const i = argv.indexOf(flag);
    return i === -1 ? undefined : argv[i + 1];
  };
  const start = value('--root') ?? process.cwd();
  const top = git(['rev-parse', '--show-toplevel'], start) ?? start;
  if (!existsSync(top)) {
    console.error(`✘ no such folder: ${top}`);
    return 2;
  }
  const root = realpathSync(top);
  const changedBase = value('--changed');
  if (changedBase !== undefined && (!REF.test(changedBase) || changedBase.startsWith('-') || git(['rev-parse', '--verify', '--quiet', `${changedBase}^{commit}`], root) === null)) {
    console.error(`✘ --changed: not a commit in this repo: ${changedBase}`);
    return 2;
  }
  const file = findConfig(root);
  if (!file) {
    console.error(`✘ no ${PROFILE_FILE} — run /team-init --update so the project profile records the authoritative gates`);
    return 2;
  }
  let raw;
  try {
    raw = JSON.parse(readFileSync(file, 'utf8'));
  } catch (error) {
    console.error(`✘ ${file}: ${error instanceof Error ? error.message : String(error)}`);
    return 2;
  }
  const config = parseConfig(raw);
  if (!config.ok) {
    console.error(`✘ ${file}: ${config.error}`);
    return 2;
  }
  const only = value('--only')?.split(',').map((s) => s.trim()).filter(Boolean);
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], root);
  const sha = git(['rev-parse', '--short', 'HEAD'], root) ?? '';
  const head = [sha, branch && branch !== 'HEAD' ? branch : ''].filter(Boolean).join(' · ');
  const out = runVerify({ root, steps: config.steps, only, changedBase, head });
  if (!out.ok) {
    console.error(`✘ ${out.error}`);
    return 2;
  }
  const label = (branch && branch !== 'HEAD' ? branch : sha || 'detached').replace(/[^A-Za-z0-9._-]+/g, '-');
  const report = join(root, '_workspace', 'verify', `${label}.md`);
  mkdirSync(dirname(report), { recursive: true });
  writeFileSync(report, out.block);
  const where = relative(root, file) === PROFILE_FILE ? PROFILE_FILE : file;
  if (argv.includes('--json')) console.log(JSON.stringify({ result: out.result, steps: out.steps, config: where, report: relative(root, report) }));
  else console.log(`${out.block}\n(config: ${where} · written to ${relative(root, report)})`);
  return out.result === '됨' ? 0 : out.result === '안 됨' ? 1 : 3;
}

if (process.argv[1] && realpathSync.native(process.argv[1]) === realpathSync.native(fileURLToPath(import.meta.url))) {
  process.exitCode = main(process.argv.slice(2));
}
