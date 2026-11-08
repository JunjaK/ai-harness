// Stop hook (opt-in, userConfig `korean_reply`): when the final reply is written in English sentences,
// send it back once so Claude rewrites the same content in Korean.
// Ported from the company harness (qesg-harness hooks/reply-language.mjs, v1.6.11, 2026-10-27), where an
// instruction alone kept producing English replies.
//
// - Off unless CLAUDE_PLUGIN_OPTION_KOREAN_REPLY is "true" (Claude Code exports userConfig values to hooks).
// - Counts sentence language only. Developer terms inside a Korean sentence (PR, worktree, apply) do not count.
//   Code blocks, inline code, URLs and paths are removed first. Short replies (≤ 1 English sentence) pass.
// - The second Stop of the same turn (stop_hook_active) always passes, so an explicit request for English
//   can still end the turn.
// - Only the final reply is checked; progress text between tool calls is not part of last_assistant_message.
// Docs: https://code.claude.com/docs/en/hooks (Stop: last_assistant_message, stop_hook_active, decision "block")

import { realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/** Minimum words for a line to count as an English sentence (skips "Done." / "All tests pass.") */
const MIN_WORDS = 4;
/** Minimum English sentences before the reply is sent back */
const MIN_SENTENCES = 2;

/**
 * @param {unknown} text  Stop input last_assistant_message
 * @returns {{ english: number, korean: number, block: boolean }}
 */
export function judgeReply(text) {
  if (typeof text !== 'string') return { english: 0, korean: 0, block: false };
  const prose = text
    .replace(/(```|~~~)[\s\S]*?\1/g, '\n')
    .replace(/`[^`\n]*`/g, ' ')
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/(?:[\w.~-]*[\\/])+[\w.-]+/g, ' ');
  let english = 0;
  let korean = 0;
  for (const sentence of prose.split(/\n+|(?<=[.!?])\s+/)) {
    if (/[가-힣]/.test(sentence)) korean += 1;
    else if ((sentence.match(/[A-Za-z][A-Za-z'’-]*/g) ?? []).length >= MIN_WORDS) english += 1;
  }
  return { english, korean, block: english >= MIN_SENTENCES && english > korean };
}

export const REWRITE_REASON =
  '[harness] The reply you just wrote is in English sentences, but replies to this user are in Korean. Rewrite the same content as Korean sentences and end the turn. Keep developer terms, code identifiers, paths and commands in English. If the user explicitly asked for this reply in English, do not rewrite — end the turn as it is.';

/**
 * @param {Record<string, unknown>} input  Stop hook input
 * @param {Record<string, string | undefined>} env
 * @returns {string} hook stdout ('' = let the turn end)
 */
export function decide(input, env) {
  if (env.CLAUDE_PLUGIN_OPTION_KOREAN_REPLY !== 'true') return '';
  if (input?.stop_hook_active === true || input?.stop_hook_active === 'true') return '';
  if (!judgeReply(input?.last_assistant_message).block) return '';
  return JSON.stringify({ decision: 'block', reason: REWRITE_REASON });
}

async function main() {
  let input = {};
  try {
    let data = '';
    process.stdin.setEncoding('utf8');
    for await (const chunk of process.stdin) data += chunk;
    input = JSON.parse(data || '{}');
  } catch {
    return;
  }
  const out = decide(input, process.env);
  if (out) process.stdout.write(out);
}

if (process.argv[1] && realpathSync.native(process.argv[1]) === realpathSync.native(fileURLToPath(import.meta.url))) {
  await main();
}
