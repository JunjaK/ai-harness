// Launcher for the Jev MCP server (jev_server.py). plugin.json starts this file with node instead of a fixed `python3`.
// Ported from the company harness (qesg-harness mcp/jev.mjs, v1.7.1, 2026-10-30):
// - Windows usually has no `python3`, and `python`/`python3` may resolve to the App Execution Alias stubs in
//   WindowsApps (empty Store installers), so the server never started there. macOS may have only `python3`.
// - Candidates run in order; the first one that answers "3" to a version probe starts the server.
//   On Windows, PATH is scanned directly and the WindowsApps folder is skipped.
// - Candidate names live only in this file, never in an environment variable, so a project's env cannot choose
//   the program that runs.

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, realpathSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SERVER = join(dirname(fileURLToPath(import.meta.url)), 'jev_server.py');

/** @type {{ command: string, args: string[] }[]} */
export const CANDIDATES = [
  { command: 'python3', args: [] },
  { command: 'python', args: [] },
  { command: 'py', args: ['-3'] },
];

const WINDOWS_APPS = /[\\/]Microsoft[\\/]WindowsApps[\\/]?$/i;

/**
 * Candidates to try. On Windows: full paths of python.exe / python3.exe in PATH order (WindowsApps excluded), then `py -3`.
 * @param {NodeJS.ProcessEnv} env
 * @param {string} platform
 */
export function resolveCandidates(env = process.env, platform = process.platform) {
  if (platform !== 'win32') return CANDIDATES;
  const pathKey = Object.keys(env).find((key) => key.toUpperCase() === 'PATH');
  const dirs = (pathKey ? env[pathKey] ?? '' : '').split(';').filter((dir) => dir && !WINDOWS_APPS.test(dir));
  const found = [];
  const seen = new Set();
  for (const dir of dirs) {
    for (const name of ['python.exe', 'python3.exe']) {
      const file = join(dir, name);
      if (seen.has(file.toLowerCase()) || !existsSync(file)) continue;
      seen.add(file.toLowerCase());
      found.push({ command: file, args: [] });
    }
  }
  return [...found, { command: 'py', args: ['-3'] }];
}

/**
 * Is the candidate Python 3? A stub exits 9009 and never prints 3.
 * @param {{ command: string, args: string[] }} candidate
 */
export function isPython3({ command, args }) {
  const probe = spawnSync(command, [...args, '-c', 'import sys; print(sys.version_info[0])'], {
    encoding: 'utf8',
    timeout: 10000,
    windowsHide: true,
  });
  return probe.status === 0 && probe.stdout.trim() === '3';
}

/**
 * @param {{ command: string, args: string[] }[]} candidates
 * @param {(candidate: { command: string, args: string[] }) => boolean} probe
 */
export function pickPython(candidates = resolveCandidates(), probe = isPython3) {
  return candidates.find((candidate) => probe(candidate));
}

export function notFoundMessage(candidates = CANDIDATES) {
  const tried = candidates.map(({ command, args }) => [command, ...args].join(' ')).join(', ');
  return [
    `[jev] Python 3 not found, so the Jev server is not started (tried: ${tried}; on Windows the WindowsApps folder is skipped).`,
    'Install Python 3 (for example `mise use -g python@3`). On Windows, turn off python.exe / python3.exe under',
    'Settings → Apps → Advanced app settings → App execution aliases. Then reopen the terminal and Claude Code and reconnect jev in /mcp.',
  ].join('\n');
}

function main() {
  const python = pickPython();
  if (!python) {
    process.stderr.write(`${notFoundMessage()}\n`);
    process.exit(1);
  }
  // Hand stdio straight through so MCP messages never pass through this process
  const child = spawn(python.command, [...python.args, '-I', SERVER, ...process.argv.slice(2)], {
    stdio: 'inherit',
    windowsHide: true,
  });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => child.kill(signal));
  child.on('error', (error) => {
    process.stderr.write(`[jev] failed to run ${python.command}: ${error.message}\n`);
    process.exit(1);
  });
  child.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
}

if (process.argv[1] && realpathSync.native(process.argv[1]) === realpathSync.native(fileURLToPath(import.meta.url))) main();
