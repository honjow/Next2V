import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync('shared/src/main/ets/components/markdown/MarkdownCodeInternals.ets', 'utf8');

for (const alias of [
  "first === 'py' || first === 'python'",
  "first === 'go' || first === 'golang'",
  "first === 'rs' || first === 'rust'",
  "first === 'sql'",
  "first === 'diff' || first === 'patch'",
  "first === 'yaml' || first === 'yml'",
]) {
  assert.ok(source.includes(alias), `missing language alias contract: ${alias}`);
}

for (const fn of [
  'function highlightTsJsLine(code: string): CodeToken[]',
  'function highlightPythonLine(code: string): CodeToken[]',
  'function highlightCssLine(code: string): CodeToken[]',
  'function highlightSqlLine(code: string): CodeToken[]',
  'function highlightDiffLine(code: string): CodeToken[]',
  'function sniffCodeLanguage(code: string): string',
]) {
  assert.ok(source.includes(fn), `missing highlighter function: ${fn}`);
}

const dispatchSource = source;
assert.ok(dispatchSource.includes("const explicit = normalizeCodeLanguage(lang);"), 'missing explicit language normalization');
assert.ok(dispatchSource.includes("explicit === 'generic' ? (sniffCodeLanguage(code) || explicit) : explicit"), 'empty/generic language must use sniff fallback');

for (const branch of [
  "normalized === 'typescript' || normalized === 'javascript'",
  "normalized === 'python'",
  "normalized === 'css'",
  "normalized === 'sql'",
  "normalized === 'diff'",
]) {
  assert.ok(dispatchSource.includes(branch), `missing highlight dispatch branch: ${branch}`);
}

for (const token of [
  '=>|',
  "'def'",
  "'SELECT'",
  "'@media'",
  "source.startsWith('+')",
]) {
  assert.ok(source.includes(token), `missing representative token rule: ${token}`);
}

console.log('markdown code highlight contract ok');
