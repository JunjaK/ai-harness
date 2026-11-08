// Tests for plant.mjs. Run: node --test skills/verify/scripts/plant.test.mjs
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import { plantDir, plantViolation, restorePlants } from './plant.mjs';

const CLI = join(dirname(fileURLToPath(import.meta.url)), 'plant.mjs');
const SOURCE = 'export const limit = (n) => Math.min(n, 10);\nexport const name = "limit";\n';
const sha = (/** @type {string} */ p) => createHash('sha256').update(readFileSync(p)).digest('hex');

function repo() {
  const root = mkdtempSync(join(tmpdir(), 'harness-plant-'));
  writeFileSync(join(root, 'lib.mjs'), SOURCE);
  // The real check: limit(50) must be 10
  writeFileSync(join(root, 'check.mjs'), "import { limit } from './lib.mjs';\nif (limit(50) !== 10) { console.error('limit broken'); process.exit(1); }\n");
  return root;
}

describe('plant', () => {
  it('caught → 됨, missed → 안 됨, not run → not caught; the file always returns to its sha256 and no backup is left', () => {
    const root = repo();
    try {
      const before = sha(join(root, 'lib.mjs'));
      const caught = plantViolation({ root, file: 'lib.mjs', find: 'Math.min(n, 10)', replace: 'n', command: [process.execPath, 'check.mjs'] });
      assert.equal(caught.ok && caught.caught, true);
      assert.match(caught.ok ? caught.line : '', /^됨 .*lib\.mjs.*exit 1/);
      assert.equal(sha(join(root, 'lib.mjs')), before);
      // A change the check never looks at passes the test → 안 됨
      const missed = plantViolation({ root, file: 'lib.mjs', find: '"limit"', replace: '"other"', command: [process.execPath, 'check.mjs'] });
      assert.equal(missed.ok && missed.caught, false);
      assert.match(missed.ok ? missed.line : '', /^안 됨 .*missed/);
      assert.equal(sha(join(root, 'lib.mjs')), before);
      assert.deepEqual(readdirSync(plantDir(root)), []);
      // A test command that never ran is not a catch
      const broken = plantViolation({ root, file: 'lib.mjs', find: 'Math.min(n, 10)', replace: 'n', command: ['no-such-command-harness'] });
      assert.equal(broken.ok && broken.caught, false);
      assert.equal(sha(join(root, 'lib.mjs')), before);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it('refuses 0 or 2+ matches, no-op replacements, paths outside the repo, _workspace/.git (any case), symlinks and ignored files', () => {
    const root = repo();
    try {
      const before = sha(join(root, 'lib.mjs'));
      const cases = [
        { file: 'lib.mjs', find: 'not here', replace: 'x' },
        { file: 'lib.mjs', find: 'limit', replace: 'x' },
        { file: 'lib.mjs', find: 'n', replace: 'n' },
        { file: '../outside.mjs', find: 'a', replace: 'b' },
        { file: '_workspace/x.mjs', find: 'a', replace: 'b' },
      ];
      for (const c of cases) {
        let ran = false;
        const r = plantViolation({ root, ...c, command: ['x'], run: () => { ran = true; return { status: 1, output: '' }; } });
        assert.equal(r.ok, false, JSON.stringify(c));
        assert.equal(ran, false, JSON.stringify(c));
      }
      if (process.platform !== 'win32') {
        const outside = mkdtempSync(join(tmpdir(), 'harness-plant-out-'));
        writeFileSync(join(outside, 'victim.mjs'), 'const a = 1;\n');
        symlinkSync(outside, join(root, 'linkdir'));
        symlinkSync(join(outside, 'victim.mjs'), join(root, 'leaf.mjs'));
        for (const file of ['linkdir/victim.mjs', 'leaf.mjs']) {
          const r = plantViolation({ root, file, find: 'a = 1', replace: 'a = 2', command: ['x'], run: () => ({ status: 1, output: '' }) });
          assert.match(r.ok ? '' : r.error, /symlink/, file);
        }
        assert.equal(readFileSync(join(outside, 'victim.mjs'), 'utf8'), 'const a = 1;\n');
        rmSync(outside, { recursive: true, force: true });
      }
      for (const file of ['.GIT/config', '_Workspace/x.mjs', 'sub/.git./x', 'sub/GIT~1/x']) {
        mkdirSync(dirname(join(root, file)), { recursive: true });
        writeFileSync(join(root, file), 'a\n');
        const r = plantViolation({ root, file, find: 'a', replace: 'b', command: ['x'], run: () => ({ status: 1, output: '' }) });
        assert.match(r.ok ? '' : r.error, /_workspace or \.git/, file);
        assert.equal(readFileSync(join(root, file), 'utf8'), 'a\n', file);
      }
      const ignored = plantViolation({ root, file: 'lib.mjs', find: 'Math.min(n, 10)', replace: 'n', command: ['x'], isIgnored: () => true });
      assert.equal(ignored.ok, false);
      assert.equal(sha(join(root, 'lib.mjs')), before);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it('restores after an exception; a leftover backup blocks a new plant until --restore; forged backups are refused', () => {
    const root = repo();
    try {
      const before = sha(join(root, 'lib.mjs'));
      assert.throws(() => plantViolation({ root, file: 'lib.mjs', find: 'Math.min(n, 10)', replace: 'n', command: ['x'], run: () => { throw new Error('interrupted'); } }), /interrupted/);
      assert.equal(sha(join(root, 'lib.mjs')), before);
      // A killed process: backup left behind, file still changed
      mkdirSync(plantDir(root), { recursive: true });
      const original = readFileSync(join(root, 'lib.mjs'));
      const left = `${createHash('sha256').update('lib.mjs').digest('hex').slice(0, 16)}.json`;
      writeFileSync(join(plantDir(root), left), JSON.stringify({ path: 'lib.mjs', sha256: before, content: original.toString('base64') }));
      writeFileSync(join(root, 'lib.mjs'), 'broken');
      const blocked = plantViolation({ root, file: 'lib.mjs', find: 'broken', replace: 'x', command: ['x'] });
      assert.match(blocked.ok ? '' : blocked.error, /--restore/);
      assert.deepEqual(restorePlants(root), ['lib.mjs']);
      assert.equal(sha(join(root, 'lib.mjs')), before);
      // Forged backups (a name that is not the path's fingerprint, a path outside the repo or into .git) are refused
      for (const [file, path] of [['x.json', 'lib.mjs'], [`${createHash('sha256').update('../evil').digest('hex').slice(0, 16)}.json`, '../evil'], [`${createHash('sha256').update('.git/hooks/pre-commit').digest('hex').slice(0, 16)}.json`, '.git/hooks/pre-commit']]) {
        const content = Buffer.from('payload');
        writeFileSync(join(plantDir(root), file), JSON.stringify({ path, sha256: createHash('sha256').update(content).digest('hex'), content: content.toString('base64') }));
        assert.throws(() => restorePlants(root), /not accepted/, path);
        rmSync(join(plantDir(root), file));
      }
      assert.equal(existsSync(join(root, '..', 'evil')), false);
      assert.equal(sha(join(root, 'lib.mjs')), before);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it('CLI: one result line; exit 0 caught, 1 missed, 2 usage error or ignored file; absolute paths in another spelling work', () => {
    const root = repo();
    try {
      execFileSync('git', ['init', '-q', '-b', 'main'], { cwd: root });
      writeFileSync(join(root, '.gitignore'), 'secret.mjs\n');
      writeFileSync(join(root, 'secret.mjs'), SOURCE);
      const cli = (/** @type {string[]} */ a) => spawnSync(process.execPath, [CLI, ...a], { cwd: root, encoding: 'utf8' });
      let r = cli(['lib.mjs', '--find', 'Math.min(n, 10)', '--replace', 'n', '--', process.execPath, 'check.mjs']);
      assert.equal(r.status, 0, r.stderr);
      assert.match(r.stdout, /^됨 /);
      r = cli(['lib.mjs', '--find', '"limit"', '--replace', '"x"', '--', process.execPath, 'check.mjs']);
      assert.equal(r.status, 1);
      assert.match(r.stdout, /^안 됨 /);
      assert.equal(cli(['lib.mjs', '--find', 'x']).status, 2);
      // macOS /var ↔ /private/var: tmpdir() is not the real path, git's toplevel is
      r = cli([join(root, 'lib.mjs'), '--find', 'Math.min(n, 10)', '--replace', 'n', '--', process.execPath, 'check.mjs']);
      assert.equal(r.status, 0, r.stderr);
      r = cli(['secret.mjs', '--find', 'Math.min(n, 10)', '--replace', 'n', '--', process.execPath, 'check.mjs']);
      assert.equal(r.status, 2);
      assert.match(r.stderr, /ignored by git/);
      assert.equal(cli(['--restore']).status, 0);
      assert.equal(readFileSync(join(root, 'lib.mjs'), 'utf8'), SOURCE);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});
