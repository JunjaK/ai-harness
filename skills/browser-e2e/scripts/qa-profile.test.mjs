// Tests for qa-profile.mjs with a fake ego (no browser). Run: node --test skills/browser-e2e/scripts/qa-profile.test.mjs
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, utimesSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

import { acquireLock, planProfiles, qaProfiles } from './qa-profile.mjs';

/**
 * Fake ego. Like the real one, console.log lines come out on stderr. launch() adds a new profile with a blank window.
 * @param {{ profiles: { id: string, name: string, isDefault?: boolean }[], spaces?: { id: number, name: string, profileId: string }[], renameWorks?: boolean, appear?: boolean }} o
 */
function fakeEgo({ profiles, spaces = [], renameWorks = true, appear = true }) {
  const state = { profiles: profiles.map((p) => ({ ...p })), spaces: spaces.map((s) => ({ ...s })) };
  const scripts = /** @type {string[]} */ ([]);
  const launched = /** @type {string[]} */ ([]);
  let nextSpace = 100;
  const out = (/** @type {unknown} */ v) => ({ status: 0, stdout: '', stderr: `[ego-browser:notice] x\nHARNESS:json:${JSON.stringify(v)}\n` });
  /** @type {import('./qa-profile.mjs').EgoRun} */
  const ego = (script) => {
    scripts.push(script);
    if (script.includes('chrome://settings/manageProfile')) {
      const dir = JSON.parse(/const dir = (".*?");/.exec(script)?.[1] ?? '""');
      const want = JSON.parse(/const want = (".*?");/.exec(script)?.[1] ?? '""');
      const target = state.profiles.find((p) => p.id === dir);
      if (renameWorks && target) target.name = want;
      const closed = state.spaces.filter((s) => s.profileId === dir).length;
      state.spaces = state.spaces.filter((s) => s.profileId !== dir);
      return out({ label: true, renamed: renameWorks, closed });
    }
    if (script.includes('out.push')) {
      const items = JSON.parse(/for \(const item of (\[.*?\])\)/.exec(script)?.[1] ?? '[]');
      const rows = items.map((/** @type {{ profileId: string, name: string }} */ item) => {
        const space = { id: nextSpace++, name: item.name, profileId: item.profileId };
        state.spaces.push(space);
        return { profileId: item.profileId, space: space.id };
      });
      return out(rows);
    }
    return out({ profiles: state.profiles, spaces: state.spaces });
  };
  const launch = (/** @type {string} */ dir) => {
    launched.push(dir);
    if (appear) {
      state.profiles.push({ id: dir, name: 'My ego', isDefault: true });
      state.spaces.push({ id: nextSpace++, name: '', profileId: dir });
    }
    return /** @type {const} */ ({ ok: true });
  };
  return { state, scripts, launched, ego, launch };
}

const REAL = [
  { id: 'Profile 1', name: 'Person 1', isDefault: true },
  { id: 'Profile 3', name: 'Junjak' },
  { id: 'Profile 6', name: 'qesg-qa1' },
];
const noLock = () => /** @type {const} */ ({ ok: true, release: () => {} });
let clock = 0;
const base = { lock: noLock, sleep: () => { clock += 500; }, now: () => clock, dirExists: () => false };

describe('qa-profile', () => {
  it('picks only free harness-qa profiles in number order; real accounts and the company harness profiles are never chosen', () => {
    const f = fakeEgo({
      profiles: [...REAL, { id: 'Profile 16', name: 'harness-qa1' }, { id: 'Profile 19', name: 'harness-qa10' }, { id: 'Profile 17', name: 'harness-qa2' }],
      spaces: [{ id: 3, name: 'other-session', profileId: 'Profile 16' }],
    });
    const r = qaProfiles({ ...base, count: 2, ego: f.ego, launch: f.launch });
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.deepEqual(r.ok && r.profiles.map((p) => p.name), ['harness-qa2', 'harness-qa10']);
    assert.deepEqual(f.launched, []);
    assert.ok(!f.scripts.some((s) => /Profile [136]\b/.test(s)), 'scripts never name a non-harness profile');
  });

  it('creates a missing profile with the next number and closes the blank window opened with it', () => {
    const f = fakeEgo({ profiles: [...REAL, { id: 'Profile 16', name: 'harness-qa1' }, { id: 'Profile 18', name: 'harness-staff-dev' }], spaces: [{ id: 4, name: 'busy', profileId: 'Profile 16' }] });
    const r = qaProfiles({ ...base, count: 1, ego: f.ego, launch: f.launch });
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.deepEqual(r.ok && r.profiles, [{ id: 'Profile 19', name: 'harness-qa2', created: true }]);
    assert.deepEqual(f.launched, ['Profile 19']);
    assert.equal(f.state.profiles.find((p) => p.id === 'Profile 19')?.name, 'harness-qa2');
    assert.ok(!f.state.spaces.some((s) => s.profileId === 'Profile 19'), 'no window left on the new profile');
    const rename = f.scripts.find((s) => s.includes('manageProfile')) ?? '';
    assert.match(rename, /taskSpace\("harness-qa-profile-2-[a-z0-9]+", \{ profileId: dir \}\)/);
    assert.match(rename, /x\.profileId === dir/, 'closing blank windows is limited to the new profile');
  });

  it('starts at harness-qa1 when none exist and skips profile folders left on disk', () => {
    const f = fakeEgo({ profiles: [...REAL] });
    const r = qaProfiles({ ...base, count: 2, ego: f.ego, launch: f.launch, dirExists: (d) => d === 'Profile 7' });
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.deepEqual(r.ok && r.profiles.map((p) => [p.id, p.name]), [['Profile 8', 'harness-qa1'], ['Profile 9', 'harness-qa2']]);
  });

  it('--space-name opens a space per profile and returns its number; a name clash changes nothing', () => {
    const f = fakeEgo({ profiles: [...REAL, { id: 'Profile 16', name: 'harness-qa1' }, { id: 'Profile 17', name: 'harness-qa2' }] });
    const r = qaProfiles({ ...base, count: 2, spaceName: 'qa-login', ego: f.ego, launch: f.launch });
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.deepEqual(r.ok && r.profiles.map((p) => [p.name, typeof p.space]), [['harness-qa1', 'number'], ['harness-qa2', 'number']]);
    assert.deepEqual(f.state.spaces.map((s) => [s.name, s.profileId]), [['qa-login-1', 'Profile 16'], ['qa-login-2', 'Profile 17']]);
    const again = qaProfiles({ ...base, count: 2, spaceName: 'qa-login', ego: f.ego, launch: f.launch });
    assert.match(again.ok ? '' : again.error, /qa-login-1 already exists/);
    assert.deepEqual(f.launched, []);
    assert.equal(qaProfiles({ ...base, spaceName: 'bad name;', ego: f.ego }).ok, false);
  });

  it('reports why it could not get ready and never counts that as ready', () => {
    const noRename = fakeEgo({ profiles: [...REAL], renameWorks: false });
    const r1 = qaProfiles({ ...base, ego: noRename.ego, launch: noRename.launch });
    assert.match(r1.ok ? '' : r1.error, /was not renamed to harness-qa1/);
    const never = fakeEgo({ profiles: [...REAL], appear: false });
    const r2 = qaProfiles({ ...base, ego: never.ego, launch: never.launch });
    assert.match(r2.ok ? '' : r2.error, /did not appear/);
    const r3 = qaProfiles({ ...base, ego: fakeEgo({ profiles: [...REAL] }).ego, launch: () => ({ ok: false, error: 'no executable' }) });
    assert.deepEqual(r3, { ok: false, error: 'no executable' });
    const full = fakeEgo({
      profiles: Array.from({ length: 10 }, (_, i) => ({ id: `Profile ${i + 10}`, name: `harness-qa${i + 1}` })),
      spaces: Array.from({ length: 10 }, (_, i) => ({ id: i, name: `s${i}`, profileId: `Profile ${i + 10}` })),
    });
    const r4 = qaProfiles({ ...base, ego: full.ego, launch: full.launch });
    assert.match(r4.ok ? '' : r4.error, /already 10 QA profiles/);
    assert.deepEqual(full.launched, []);
    for (const count of [0, 6, 1.5, NaN]) assert.equal(qaProfiles({ ...base, count, ego: full.ego }).ok, false, String(count));
    const broken = qaProfiles({ ...base, ego: () => ({ status: 1, stdout: '', stderr: 'Error: EGO_UNAVAILABLE' }) });
    assert.match(broken.ok ? '' : broken.error, /exit 1.*EGO_UNAVAILABLE/);
    const missing = qaProfiles({ ...base, ego: () => ({ status: null, stdout: '', stderr: 'ENOENT' }) });
    assert.match(missing.ok ? '' : missing.error, /not installed/);
  });

  it('planProfiles: an unnumbered harness-qa name sorts last; the next number follows the numbered ones', () => {
    const plan = planProfiles({ profiles: [{ id: 'Profile 2', name: 'harness-qa-old' }, { id: 'Profile 12', name: 'harness-qa3' }, { id: 'Default', name: 'person' }], spaces: [] });
    assert.deepEqual(plan.free.map((p) => p.name), ['harness-qa3', 'harness-qa-old']);
    assert.equal(plan.nextNumber, 4);
    assert.equal(plan.nextDir, 13);
  });

  it('lock: a held lock fails after waiting; a stale one is cleared', () => {
    const dir = mkdtempSync(join(tmpdir(), 'harness-lock-'));
    const path = join(dir, 'lock');
    try {
      const first = acquireLock({ path, wait: 0 });
      assert.equal(first.ok, true);
      const second = acquireLock({ path, wait: 0, sleep: () => {} });
      assert.match(second.ok ? '' : second.error, /another session/);
      if (first.ok) first.release();
      mkdirSync(path);
      const old = (Date.now() - 600_000) / 1000;
      utimesSync(path, old, old);
      const third = acquireLock({ path, wait: 0 });
      assert.equal(third.ok, true);
      if (third.ok) third.release();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
