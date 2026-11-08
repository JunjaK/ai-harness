// Tests for mcp/jev.mjs. Run: node --test mcp/tests/jev-launcher.test.mjs
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, before, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import { CANDIDATES, isPython3, notFoundMessage, pickPython, resolveCandidates } from '../jev.mjs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const LAUNCHER = join(REPO, 'mcp', 'jev.mjs');

/** @type {string} */
let dir;
/** @type {Record<string, { command: string, args: string[] }>} */
const fake = {};

before(() => {
  dir = mkdtempSync(join(tmpdir(), 'harness-jev-launcher-'));
  // Candidates faked with node scripts; called as `<candidate> -c <code>`, so arguments are ignored
  const scripts = {
    // Like the WindowsApps alias stub: prints a hint and exits 9009
    stub: "process.stdout.write('Python '); process.exit(9009);",
    python2: "process.stdout.write('2\\n');",
    python3: "process.stdout.write('3\\n');",
  };
  for (const [name, body] of Object.entries(scripts)) {
    const file = join(dir, `${name}.mjs`);
    writeFileSync(file, body);
    fake[name] = { command: process.execPath, args: [file] };
  }
});
after(() => rmSync(dir, { recursive: true, force: true }));

describe('picking Python 3', () => {
  it('skips the stub and Python 2, picks Python 3', () => {
    assert.equal(isPython3(fake.stub), false);
    assert.equal(isPython3(fake.python2), false);
    assert.equal(isPython3(fake.python3), true);
    assert.equal(pickPython([fake.stub, fake.python2, fake.python3]), fake.python3);
  });

  it('treats a missing command as a failure and moves on', () => {
    const missing = { command: 'harness-no-such-python', args: [] };
    assert.equal(isPython3(missing), false);
    assert.equal(pickPython([missing, fake.python3]), fake.python3);
    assert.equal(pickPython([missing, fake.stub]), undefined);
  });

  it('tries python3 → python → py -3 and, when none works, names what it tried and how to fix it', () => {
    assert.deepEqual(CANDIDATES.map(({ command, args }) => [command, ...args].join(' ')), ['python3', 'python', 'py -3']);
    const message = notFoundMessage();
    for (const part of ['python3, python, py -3', 'App execution aliases', 'mise use -g python@3']) assert.ok(message.includes(part), part);
  });
});

describe('Windows candidates', () => {
  it('skips WindowsApps stubs in PATH and keeps real paths in PATH order', () => {
    const apps = join(dir, 'AppData', 'Local', 'Microsoft', 'WindowsApps');
    const shims = join(dir, 'mise', 'shims');
    const other = join(dir, 'Python313');
    for (const [folder, names] of [[apps, ['python.exe', 'python3.exe']], [shims, ['python.exe', 'python3.exe']], [other, ['python.exe']]]) {
      mkdirSync(folder, { recursive: true });
      for (const name of names) writeFileSync(join(folder, name), '');
    }
    // WindowsApps first, a differently cased Path key, a duplicate folder and an empty entry
    const env = { Path: [apps, shims, '', shims, join(dir, 'empty'), other].join(';') };
    assert.deepEqual(resolveCandidates(env, 'win32').map(({ command, args }) => [command, ...args].join(' ')), [
      join(shims, 'python.exe'),
      join(shims, 'python3.exe'),
      join(other, 'python.exe'),
      'py -3',
    ]);
    assert.deepEqual(resolveCandidates({ Path: apps }, 'win32'), [{ command: 'py', args: ['-3'] }]);
    assert.equal(resolveCandidates(env, 'darwin'), CANDIDATES);
  });
});

describe('manifest', () => {
  it('plugin.json starts the launcher with node', () => {
    const jev = JSON.parse(readFileSync(join(REPO, '.claude-plugin', 'plugin.json'), 'utf8')).mcpServers.jev;
    assert.deepEqual([jev.command, jev.args], ['node', ['${CLAUDE_PLUGIN_ROOT}/mcp/jev.mjs']]);
  });
});

/**
 * Start the launcher, send JSON-RPC requests, collect the replies.
 * @param {object[]} requests
 * @returns {Promise<any[]>}
 */
function rpc(requests) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [LAUNCHER], { stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '';
    let err = '';
    child.stdout.on('data', (chunk) => { out += chunk; });
    child.stderr.on('data', (chunk) => { err += chunk; });
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code !== 0) return reject(new Error(`exit ${code}: ${err}`));
      resolve(out.trim().split('\n').filter(Boolean).map((line) => JSON.parse(line)));
    });
    child.stdin.end(requests.map((request) => JSON.stringify(request)).join('\n') + '\n');
  });
}

describe('launcher', () => {
  const python = pickPython();

  it('starts the server with the chosen Python and passes stdio through', { skip: !python && 'no Python 3' }, async () => {
    const [init, list] = await rpc([
      { jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18' } },
      { jsonrpc: '2.0', id: 2, method: 'tools/list' },
    ]);
    assert.equal(init.result.serverInfo.name, 'jev');
    assert.equal(init.result.protocolVersion, '2025-06-18');
    assert.ok(list.result.tools.some((tool) => tool.name === 'stop_gate'));
  });
});
