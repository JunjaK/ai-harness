#!/usr/bin/env node
// verify skill — plant one violation, run the test, always restore (reference/verification-loop.md: a check is only
// evidence once it has been seen to fail). Ported from the company harness (qesg-harness scripts/lib/verify-plant.mjs,
// v1.7.0, 2026-10-29, including its security-review fixes).
//
// - Replaces --find only when it occurs exactly once in the file (never several places, never the wrong one).
// - The test command exiting non-zero → 됨 (caught the violation); exiting 0 → 안 됨 (missed it); not run → 안 됨.
// - Keeps the original under _workspace/verify/plant/, restores it when done (signals included) and checks sha256.
//   A backup left by an interrupted run blocks a new plant until `--restore`.
//
// Usage: node plant.mjs <file> --find <text> --replace <text> -- <test command…>   (exit 0 caught, 1 missed, 2 error)
//        node plant.mjs --restore

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

/** @param {Buffer | string} data */
const sha = (data) => createHash('sha256').update(data).digest('hex');

/** @param {string} root */
export const plantDir = (root) => join(root, '_workspace', 'verify', 'plant');

/** A dangling symlink still counts as present. @param {string} path */
export function lexists(path) {
  try {
    lstatSync(path);
    return true;
  } catch {
    return false;
  }
}

/** No component between base and dir (exclusive of base) is a symlink. @param {string} base @param {string} dir */
export function noSymlinkBetween(base, dir) {
  const parts = relative(base, dir).split(sep).filter(Boolean);
  let current = base;
  for (const part of parts) {
    if (part === '..') return false;
    current = join(current, part);
    if (!lexists(current)) return true;
    if (lstatSync(current).isSymbolicLink()) return false;
  }
  return true;
}

/** @param {string} text @param {string} part */
function count(text, part) {
  let n = 0;
  for (let i = text.indexOf(part); i !== -1; i = text.indexOf(part, i + 1)) n += 1;
  return n;
}

/** @param {string} text */
const brief = (text) => (text.length > 40 ? `${text.slice(0, 37)}…` : text).replace(/\s+/g, ' ');

/**
 * Why a repo-relative path cannot be planted or restored, or null.
 * Case-insensitive file systems (macOS, Windows): .GIT, _Workspace, ".git." and GIT~1 must not slip through.
 * @param {string} rel
 */
function pathProblem(rel) {
  if (!rel || rel.startsWith('..') || isAbsolute(rel)) return 'only files inside the repo are accepted';
  const parts = rel.split(/[\\/]/).map((p) => p.normalize('NFC').toLowerCase().replace(/[. ]+$/, ''));
  if (parts[0] === '_workspace' || parts.some((p) => p === '.git' || /^git~\d+$/.test(p))) return 'files under _workspace or .git are not accepted';
  return null;
}

/**
 * Physical checks: neither the target nor a folder above it is a symlink, and the real location is inside the repo.
 * @param {string} root
 * @param {string} rel
 */
function physicalProblem(root, rel) {
  const rootReal = realpathSync(root);
  const abs = join(rootReal, rel);
  if (!noSymlinkBetween(rootReal, dirname(abs)) || (lexists(abs) && lstatSync(abs).isSymbolicLink())) return 'files reached through a symlink are not accepted';
  if (existsSync(dirname(abs))) {
    const parent = realpathSync(dirname(abs));
    if (parent !== rootReal && !parent.startsWith(rootReal + sep)) return 'the real location is outside the repo';
  }
  return null;
}

/**
 * Restore every backup left behind.
 * @param {string} root
 * @returns {string[]} restored repo-relative paths
 */
export function restorePlants(root) {
  const dir = plantDir(root);
  if (!existsSync(dir)) return [];
  const restored = [];
  for (const name of readdirSync(dir).filter((n) => n.endsWith('.json'))) {
    const backup = JSON.parse(readFileSync(join(dir, name), 'utf8'));
    // The backup folder is writable by anyone: re-check the path with the planting rules, and the file name must be
    // that path's fingerprint before anything is written back.
    const rel = typeof backup.path === 'string' ? relative(root, resolve(root, backup.path)) : '';
    if (pathProblem(rel) || physicalProblem(root, rel) || name !== `${sha(rel).slice(0, 16)}.json`) {
      throw new Error(`backup ${name} is not accepted (outside the repo, under _workspace/.git, or a name that does not match its path): ${String(backup.path)}`);
    }
    if (!existsSync(join(root, rel))) throw new Error(`backup ${name} points to a missing file: ${rel}`);
    const original = Buffer.from(String(backup.content), 'base64');
    if (sha(original) !== backup.sha256) throw new Error(`backup ${name} is corrupted (sha256 mismatch) — check the file with git: ${rel}`);
    writeFileSync(join(root, rel), original);
    rmSync(join(dir, name));
    restored.push(rel);
  }
  return restored;
}

/** @typedef {(command: string, args: string[], cwd: string) => { status: number | null, output: string }} TestRun */

/** @type {TestRun} */
const defaultTestRun = (command, args, cwd) => {
  const r = spawnSync(command, args, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  return { status: r.error ? null : r.status, output: `${r.stdout ?? ''}${r.stderr ?? ''}${r.error ? r.error.message : ''}` };
};

/**
 * @param {{ root: string, file: string, find: string, replace: string, command: string[], run?: TestRun, isIgnored?: (path: string) => boolean }} o
 * @returns {{ ok: true, caught: boolean, line: string, tail: string } | { ok: false, error: string }}
 */
export function plantViolation({ root, file, find, replace, command, run = defaultTestRun, isIgnored = () => false }) {
  if (command.length === 0) return { ok: false, error: 'give the test command after `--`' };
  if (!find) return { ok: false, error: '--find (the text to replace) is required' };
  if (find === replace) return { ok: false, error: '--find and --replace are the same, so nothing would change' };
  const path = resolve(root, file);
  const rel = relative(root, path);
  const bad = pathProblem(rel) ?? physicalProblem(root, rel);
  if (bad) return { ok: false, error: `${bad}: ${file}` };
  // The backup folder must not go through a symlink either
  if (!noSymlinkBetween(realpathSync(root), join(realpathSync(root), '_workspace', 'verify', 'plant'))) return { ok: false, error: '_workspace/verify/plant goes through a symlink' };
  if (!existsSync(path) || !statSync(path).isFile()) return { ok: false, error: `no such file: ${rel}` };
  if (isIgnored(rel)) return { ok: false, error: `files ignored by git are not accepted: ${rel}` };
  const dir = plantDir(root);
  if (existsSync(dir) && readdirSync(dir).some((n) => n.endsWith('.json'))) return { ok: false, error: 'a backup from an earlier plant is still there — restore it first with `plant.mjs --restore`' };
  const original = readFileSync(path);
  const text = original.toString('utf8');
  const hits = count(text, find);
  if (hits !== 1) return { ok: false, error: `--find occurs ${hits} times in the file — give text that occurs exactly once (file unchanged)` };
  mkdirSync(dir, { recursive: true });
  const backupFile = join(dir, `${sha(rel).slice(0, 16)}.json`);
  writeFileSync(backupFile, JSON.stringify({ path: rel, sha256: sha(original), content: original.toString('base64') }));
  /** @type {{ status: number | null, output: string }} */
  let result = { status: null, output: '' };
  const restore = () => {
    if (existsSync(backupFile)) restorePlants(root);
  };
  const onSignal = (/** @type {NodeJS.Signals} */ signal) => {
    restore();
    process.exit(signal === 'SIGINT' ? 130 : 143);
  };
  process.once('SIGINT', onSignal);
  process.once('SIGTERM', onSignal);
  try {
    writeFileSync(path, text.replace(find, () => replace));
    result = run(command[0], command.slice(1), root);
  } finally {
    restore();
    process.removeListener('SIGINT', onSignal);
    process.removeListener('SIGTERM', onSignal);
  }
  if (sha(readFileSync(path)) !== sha(original)) return { ok: false, error: `after restoring, ${rel} does not match its original sha256 — check it with git diff` };
  const caught = result.status !== 0 && result.status !== null;
  const what = `${rel} "${brief(find)}" → "${brief(replace)}" · ${command.join(' ')} exit ${result.status ?? 'not run'}`;
  const line = caught ? `됨  the test caught the planted violation: ${what}` : result.status === null ? `안 됨  the test command did not run: ${what}` : `안 됨  the test missed the planted violation: ${what}`;
  return { ok: true, caught, line, tail: result.output.split(/\r?\n/).filter((l) => l.trim()).slice(-10).join('\n') };
}

/** Repo root of the working directory (real path), or null. */
function gitRoot() {
  const r = spawnSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' });
  return r.status === 0 ? realpathSync(r.stdout.trim()) : null;
}

/** @param {string[]} argv */
function main(argv) {
  const root = gitRoot();
  if (!root) {
    console.error('✘ run inside a git repository');
    return 2;
  }
  if (argv[0] === '--restore') {
    try {
      const restored = restorePlants(root);
      console.log(restored.length === 0 ? 'nothing to restore' : `restored: ${restored.join(', ')}`);
      return 0;
    } catch (error) {
      console.error(`✘ ${error instanceof Error ? error.message : String(error)}`);
      return 2;
    }
  }
  const dash = argv.indexOf('--');
  const head = dash === -1 ? argv : argv.slice(0, dash);
  const command = dash === -1 ? [] : argv.slice(dash + 1);
  const value = (/** @type {string} */ flag) => {
    const i = head.indexOf(flag);
    return i === -1 ? undefined : head[i + 1];
  };
  const file = head[0];
  const find = value('--find');
  const replace = value('--replace');
  if (!file || file.startsWith('--') || find === undefined || replace === undefined || command.length === 0) {
    console.error('usage: plant.mjs <file> --find <text> --replace <text> -- <test command…>  |  plant.mjs --restore');
    return 2;
  }
  // Absolute paths may name the repo through another spelling (/var ↔ /private/var): resolve the parent folder first
  const abs = isAbsolute(file) ? file : resolve(process.cwd(), file);
  const parent = existsSync(dirname(abs)) ? realpathSync(dirname(abs)) : dirname(abs);
  const rel = relative(root, join(parent, basename(abs)));
  const isIgnored = (/** @type {string} */ p) => spawnSync('git', ['check-ignore', '-q', '--', p], { cwd: root }).status === 0;
  const result = plantViolation({ root, file: rel, find, replace, command, isIgnored });
  if (!result.ok) {
    console.error(`✘ ${result.error}`);
    return 2;
  }
  console.log(result.line);
  if (result.tail) console.log(result.tail);
  return result.caught ? 0 : 1;
}

if (process.argv[1] && realpathSync.native(process.argv[1]) === realpathSync.native(fileURLToPath(import.meta.url))) {
  process.exitCode = main(process.argv.slice(2));
}
