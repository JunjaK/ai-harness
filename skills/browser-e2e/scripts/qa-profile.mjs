#!/usr/bin/env node
// browser-e2e gate 2 — pick (or create) dedicated ego lite QA profiles, then optionally open a task space in each.
// Ported from the company harness (qesg-harness scripts/lib/ego-profile.mjs, 2026-11-03), prefix changed so the
// two harnesses never share a profile on one machine.
//
// - QA profile: a profile whose name starts with `harness-qa`. Every other profile may hold a real account,
//   so it is never selected or opened.
// - Free: listTaskSpaces() has no space on that profile. A space from a person or another session means the
//   profile is in use (two tasks on one profile share cookies, so the account switches under one of them).
// - Create: ego-browser has no "create profile" command (0.6.2.7–0.6.2.9). Launching the ego executable with
//   `--profile-directory=Profile N` makes the running ego open a window for a new profile; renaming it in
//   chrome://settings/manageProfile shows the new name in profiles(). The blank window opened with it is closed.
//   Confirmed on macOS (2026-11-03, company harness); Windows creation is unconfirmed.
// - Several sessions may call this at once, so selecting, creating and opening spaces run under one lock.
// - Scripts go to `ego-browser nodejs` on stdin; console.log may land on stderr, so only MARK lines are read.
//
// Usage: node qa-profile.mjs [--count N] [--space-name <name>] [--json]   (exit 0 = ready, 1 = not ready)

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, realpathSync, rmSync, statSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** @typedef {(script: string) => { status: number | null, stdout: string, stderr: string }} EgoRun */
/** @typedef {{ id: string, name: string, isDefault?: boolean }} Profile */
/** @typedef {{ id: number, name: string, profileId: string }} Space */
/** @typedef {{ profiles: Profile[], spaces: Space[] }} EgoState */

export const QA_PREFIX = 'harness-qa';
const MAX_QA_PROFILES = 10;
const SPACE_NAME = /^[A-Za-z0-9][\w.-]{0,59}$/;
const MARK = 'HARNESS:json:';

/** @type {EgoRun} */
export function defaultEgo(script) {
  const r = spawnSync('ego-browser', ['nodejs'], { encoding: 'utf8', timeout: 90_000, input: script, windowsHide: true });
  const cause = r.error ? String(/** @type {NodeJS.ErrnoException} */ (r.error).code ?? r.error.message) : '';
  return { status: r.error ? null : r.status, stdout: r.stdout ?? '', stderr: r.stderr || cause };
}

/**
 * Run a script and parse its last MARK line.
 * @param {EgoRun} ego
 * @param {string} script
 * @returns {{ ok: true, value: any } | { ok: false, error: string }}
 */
function egoJson(ego, script) {
  const r = ego(script);
  const text = `${r.stdout}\n${r.stderr}`;
  const line = text.split(/\r?\n/).filter((l) => l.startsWith(MARK)).at(-1);
  if (r.status === 0 && line) {
    try {
      return { ok: true, value: JSON.parse(line.slice(MARK.length)) };
    } catch {
      // fall through to the error below
    }
  }
  const first = text.split(/\r?\n/).find((l) => l.trim() && !l.startsWith(MARK))?.trim().slice(0, 200) ?? '';
  if (r.status === null && /ENOENT/.test(r.stderr)) return { ok: false, error: 'ego-browser is not installed — follow the install steps in the browser-e2e skill' };
  return { ok: false, error: `ego-browser failed (exit ${r.status})${first ? `: ${first}` : ''}` };
}

const STATE_SCRIPT = `const ps = await profiles();
const ss = await listTaskSpaces();
console.log(${JSON.stringify(MARK)} + JSON.stringify({ profiles: ps.map((p) => ({ id: p.id, name: p.name, isDefault: p.isDefault })), spaces: ss.map((s) => ({ id: s.id, name: s.name, profileId: s.profileId })) }));
`;

/**
 * @param {EgoRun} ego
 * @returns {{ ok: true, value: EgoState } | { ok: false, error: string }}
 */
export function readState(ego) {
  const r = egoJson(ego, STATE_SCRIPT);
  if (!r.ok) return r;
  const v = r.value;
  if (!Array.isArray(v?.profiles) || !Array.isArray(v?.spaces)) return { ok: false, error: 'could not read the ego profile list' };
  return { ok: true, value: v };
}

/** @param {string} name */
const qaNumber = (name) => {
  const m = new RegExp(`^${QA_PREFIX}(\\d+)$`).exec(name);
  return m ? Number(m[1]) : null;
};

/**
 * Free QA profiles (by number) and the name/folder a new one would get.
 * @param {EgoState} state
 * @param {(dir: string) => boolean} [dirExists] a profile folder already on disk (left by a deleted profile) is skipped
 */
export function planProfiles(state, dirExists = () => false) {
  const busy = new Set(state.spaces.map((s) => s.profileId));
  const qa = state.profiles.filter((p) => typeof p.name === 'string' && p.name.startsWith(QA_PREFIX));
  const order = (/** @type {Profile} */ p) => qaNumber(p.name) ?? Number.MAX_SAFE_INTEGER;
  const free = qa.filter((p) => !busy.has(p.id)).sort((a, b) => order(a) - order(b) || a.name.localeCompare(b.name));
  const taken = new Set(state.profiles.map((p) => p.id));
  const numbers = state.profiles.map((p) => /^Profile (\d+)$/.exec(p.id)).filter((m) => m !== null).map((m) => Number(m[1]));
  let dir = Math.max(0, ...numbers) + 1;
  while (taken.has(`Profile ${dir}`) || dirExists(`Profile ${dir}`)) dir += 1;
  const next = Math.max(0, ...qa.map((p) => qaNumber(p.name) ?? 0)) + 1;
  return { free, qaCount: qa.length, nextDir: dir, nextNumber: next };
}

/**
 * Where the ego executable is installed, per OS.
 * @param {NodeJS.Platform} platform
 * @param {Record<string, string | undefined>} env
 */
export function egoBinary(platform = process.platform, env = process.env) {
  if (platform === 'darwin') return ['/Applications/ego lite.app/Contents/MacOS/ego lite', join(homedir(), 'Applications', 'ego lite.app', 'Contents', 'MacOS', 'ego lite')];
  if (platform === 'win32') {
    return [env.ProgramFiles, env['ProgramFiles(x86)'], env.LOCALAPPDATA]
      .filter((d) => typeof d === 'string' && d !== '')
      .map((d) => join(/** @type {string} */ (d), 'Citro Labs', 'ego lite', 'Application', 'ego.exe'));
  }
  return [];
}

/**
 * Does the profile folder exist in ego's user-data dir? Only checked on macOS (the Windows location is unconfirmed).
 * @param {string} dir
 */
export function defaultDirExists(dir) {
  if (process.platform !== 'darwin') return false;
  return existsSync(join(homedir(), 'Library', 'Application Support', 'Citro Labs', 'ego lite', dir));
}

/**
 * Ask the running ego to open a window for a new profile (a stopped ego starts with that profile).
 * @param {string} dir
 * @returns {{ ok: true } | { ok: false, error: string }}
 */
export function defaultLaunch(dir) {
  const candidates = egoBinary();
  if (candidates.length === 0) return { ok: false, error: 'ego lite can create profiles only on macOS and Windows' };
  const binary = candidates.find((c) => existsSync(c));
  if (!binary) return { ok: false, error: `ego lite executable not found (${candidates.join(', ')}) — create the QA profile in the app (browser-e2e skill)` };
  const child = spawn(binary, [`--profile-directory=${dir}`], { detached: true, stdio: 'ignore', windowsHide: false });
  child.on('error', () => {});
  child.unref();
  return { ok: true };
}

/**
 * Rename the new profile and close the blank window opened with it. Touches nothing outside that new profile.
 * @param {string} dir
 * @param {string} name
 * @param {string} spaceName
 */
export function renameScript(dir, name, spaceName) {
  return `const dir = ${JSON.stringify(dir)};
const want = ${JSON.stringify(name)};
const task = await taskSpace(${JSON.stringify(spaceName)}, { profileId: dir });
const page = task.page("p1");
await page.goto("chrome://settings/manageProfile", { timeout: 20000 });
// The name field (cr-input#nameInput) has a locale-dependent aria-label, so read it from the page
let label = null;
for (let i = 0; i < 40 && !label; i += 1) {
  label = await page.evaluate(() => {
    const walk = (root) => {
      for (const el of root.querySelectorAll("*")) {
        if (el.tagName === "CR-INPUT" && el.id === "nameInput") return el.shadowRoot?.querySelector("input")?.getAttribute("aria-label") ?? null;
        if (el.shadowRoot) { const found = walk(el.shadowRoot); if (found) return found; }
      }
      return null;
    };
    return walk(document);
  });
  if (!label) await page.waitForTimeout(250);
}
let renamed = false;
if (label) {
  const input = "input[aria-label=" + JSON.stringify(label) + "]";
  await page.fill(input, want);
  await page.press(input, "Enter");
  for (let i = 0; i < 40 && !renamed; i += 1) {
    renamed = (await profiles()).some((p) => p.id === dir && p.name === want);
    if (!renamed) await page.waitForTimeout(250);
  }
}
// The blank window opened at launch: close only new tabs in the new profile's other spaces
let closed = 0;
for (const s of (await listTaskSpaces()).filter((x) => x.profileId === dir && x.id !== task.spaceId)) {
  const other = await claimTaskSpace(s.id);
  for (const t of await other.tabs()) {
    if (t.url === "chrome://newtab/" || t.url === "about:blank") {
      const p = t.label ? other.page(t.label) : await other.adopt(t.page);
      await p.close();
      closed += 1;
    }
  }
  await other.finish({ keep: [] });
}
await task.finish({ keep: [] });
console.log(${JSON.stringify(MARK)} + JSON.stringify({ label: !!label, renamed, closed }));
`;
}

/**
 * Open one task space per chosen profile.
 * @param {{ profileId: string, name: string }[]} items
 */
export function spaceScript(items) {
  return `const out = [];
for (const item of ${JSON.stringify(items)}) {
  const task = await taskSpace(item.name, { profileId: item.profileId });
  out.push({ profileId: item.profileId, space: task.spaceId });
}
console.log(${JSON.stringify(MARK)} + JSON.stringify(out));
`;
}

/**
 * Lock (mkdir is atomic). A lock older than 3 minutes is treated as left by a finished run.
 * @param {{ path?: string, wait?: number, sleep?: (ms: number) => void, now?: () => number }} [o]
 * @returns {{ ok: true, release: () => void } | { ok: false, error: string }}
 */
export function acquireLock({ path = join(tmpdir(), 'harness-ego-qa-profile.lock'), wait = 120_000, sleep = defaultSleep, now = Date.now } = {}) {
  const deadline = now() + wait;
  for (;;) {
    try {
      mkdirSync(path);
      return { ok: true, release: () => rmSync(path, { recursive: true, force: true }) };
    } catch (error) {
      if (/** @type {NodeJS.ErrnoException} */ (error).code !== 'EEXIST') return { ok: false, error: `could not create the lock (${path})` };
      try {
        if (now() - statSync(path).mtimeMs > 180_000) {
          rmSync(path, { recursive: true, force: true });
          continue;
        }
      } catch {
        continue;
      }
      if (now() > deadline) return { ok: false, error: `another session is choosing a QA profile (lock ${path}) — run again shortly` };
      sleep(500);
    }
  }
}

/** @param {number} ms */
function defaultSleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

/**
 * Pick `count` QA profiles, creating any that are missing. With spaceName, open a task space in each.
 * @param {{ count?: number, spaceName?: string, ego?: EgoRun, launch?: (dir: string) => { ok: true } | { ok: false, error: string },
 *   dirExists?: (dir: string) => boolean, sleep?: (ms: number) => void, now?: () => number,
 *   lock?: () => ({ ok: true, release: () => void } | { ok: false, error: string }) }} o
 * @returns {{ ok: true, profiles: { id: string, name: string, created: boolean, space?: number }[] } | { ok: false, error: string }}
 */
export function qaProfiles({ count = 1, spaceName, ego = defaultEgo, launch = defaultLaunch, dirExists = defaultDirExists, sleep = defaultSleep, now = Date.now, lock = () => acquireLock({ sleep, now }) }) {
  if (!Number.isInteger(count) || count < 1 || count > 5) return { ok: false, error: '--count must be 1–5' };
  if (spaceName !== undefined && !SPACE_NAME.test(spaceName)) return { ok: false, error: '--space-name: up to 60 chars, starting with a letter or digit (letters, digits, _ . -)' };
  const held = lock();
  if (!held.ok) return held;
  try {
    let state = readState(ego);
    if (!state.ok) return state;
    if (spaceName !== undefined) {
      const names = count === 1 ? [spaceName] : Array.from({ length: count }, (_, i) => `${spaceName}-${i + 1}`);
      const clash = names.find((n) => state.ok && state.value.spaces.some((s) => s.name === n));
      if (clash) return { ok: false, error: `task space ${clash} already exists — resume it by its number, or pass another name` };
    }
    /** @type {{ id: string, name: string, created: boolean, space?: number }[]} */
    const chosen = planProfiles(state.value, dirExists).free.slice(0, count).map((p) => ({ id: p.id, name: p.name, created: false }));
    while (chosen.length < count) {
      const plan = planProfiles(state.value, dirExists);
      if (plan.qaCount >= MAX_QA_PROFILES) return { ok: false, error: `there are already ${plan.qaCount} QA profiles and all have task spaces — finish idle spaces, then run again` };
      const dir = `Profile ${plan.nextDir}`;
      const name = `${QA_PREFIX}${plan.nextNumber}`;
      const launched = launch(dir);
      if (!launched.ok) return launched;
      // Wait (up to 20 s) for the new profile to appear in the list
      const until = now() + 20_000;
      let seen = false;
      while (!seen) {
        state = readState(ego);
        if (!state.ok) return state;
        seen = state.value.profiles.some((p) => p.id === dir);
        if (!seen) {
          if (now() > until) return { ok: false, error: `the new profile (${dir}) did not appear in ego — check that ego lite is running` };
          sleep(500);
        }
      }
      const renamed = egoJson(ego, renameScript(dir, name, `${QA_PREFIX}-profile-${plan.nextNumber}-${now().toString(36)}`));
      if (!renamed.ok) return { ok: false, error: `could not rename the new profile (${dir}): ${renamed.error} — rename it to ${name} in the app` };
      if (!renamed.value?.renamed) return { ok: false, error: `the new profile (${dir}) was not renamed to ${name} — rename it in the app` };
      state = readState(ego);
      if (!state.ok) return state;
      const after = state.value.profiles.find((p) => p.id === dir);
      if (after?.name !== name) return { ok: false, error: `could not confirm the new profile name (${dir} is now ${after?.name ?? 'missing'})` };
      if (state.value.spaces.some((s) => s.profileId === dir)) return { ok: false, error: `a window is still open on the new profile (${dir}) — close it and run again` };
      chosen.push({ id: dir, name, created: true });
    }
    if (spaceName !== undefined) {
      const items = chosen.map((p, i) => ({ profileId: p.id, name: count === 1 ? spaceName : `${spaceName}-${i + 1}` }));
      const made = egoJson(ego, spaceScript(items));
      if (!made.ok) return { ok: false, error: `could not open the task space: ${made.error}` };
      for (const row of Array.isArray(made.value) ? made.value : []) {
        const target = chosen.find((p) => p.id === row?.profileId);
        if (target && Number.isInteger(row.space)) target.space = row.space;
      }
      if (chosen.some((p) => p.space === undefined)) return { ok: false, error: 'did not receive the task space number' };
    }
    return { ok: true, profiles: chosen };
  } finally {
    held.release();
  }
}

/** @param {string[]} argv */
function main(argv) {
  const value = (/** @type {string} */ flag) => {
    const i = argv.indexOf(flag);
    return i === -1 ? undefined : argv[i + 1];
  };
  const raw = value('--count') ?? '1';
  const count = /^\d+$/.test(raw) ? Number(raw) : NaN;
  const result = qaProfiles({ count, spaceName: value('--space-name') });
  if (argv.includes('--json')) {
    console.log(JSON.stringify(result));
    return result.ok ? 0 : 1;
  }
  if (!result.ok) {
    console.error(`✘ ${result.error}`);
    return 1;
  }
  for (const p of result.profiles) console.log(`✓ ${p.name} (${p.id})${p.created ? ' created' : ''}${p.space === undefined ? '' : ` · task space ${p.space}`}`);
  return 0;
}

if (process.argv[1] && realpathSync.native(process.argv[1]) === realpathSync.native(fileURLToPath(import.meta.url))) {
  process.exitCode = main(process.argv.slice(2));
}
