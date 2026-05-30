#!/usr/bin/env node
// Static contract for the State Management V1 -> V2 leaf migration (full-state-v2 lane).
//
// For every file listed in scripts/v2-migrated-leaves.json this asserts:
//   1. the file declares at least one @ComponentV2 struct,
//   2. NO V1 component-state decorator survives (@State/@Prop/@Link/@Watch/
//      @StorageLink/@StorageProp/@Provide/@Consume/@ObjectLink) — these are illegal
//      inside @ComponentV2 and their absence proves the struct(s) were fully migrated,
//   3. NO bare V1 @Component struct survives in the file (every struct is @ComponentV2),
//   4. NO refresh-by-key-churn token (Date.now()/Math.random()) was introduced.
//
// It does NOT replace the build gate; it is a fast regression guard that fails closed.
// Run: node scripts/test_v2_leaf_migration_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const list = JSON.parse(readFileSync(join(here, 'v2-migrated-leaves.json'), 'utf8')).files;

// Decorators that may NOT appear in a migrated (pure-V2) leaf file.
const FORBIDDEN = [
  { re: /@Component\b(?!V2)/, name: '@Component (bare V1 struct)' },
  { re: /@State\b/, name: '@State' },
  { re: /@Prop\b/, name: '@Prop' },
  { re: /@Link\b/, name: '@Link' },
  { re: /@Watch\b/, name: '@Watch' },
  { re: /@StorageLink\b/, name: '@StorageLink' },
  { re: /@StorageProp\b/, name: '@StorageProp' },
  { re: /@Provide\b/, name: '@Provide' },
  { re: /@Consume\b/, name: '@Consume' },
  { re: /@ObjectLink\b/, name: '@ObjectLink' },
  { re: /@Observed\b(?!V2)/, name: '@Observed (V1)' },
];
const CHURN = [
  { re: /Date\.now\s*\(/, name: 'Date.now()' },
  { re: /Math\.random\s*\(/, name: 'Math.random()' },
];

let failures = 0;
let checked = 0;
for (const rel of list) {
  let src;
  try {
    src = readFileSync(join(repo, rel), 'utf8');
  } catch (e) {
    console.error(`FAIL ${rel}: cannot read (${e.code})`);
    failures++;
    continue;
  }
  checked++;
  // strip line comments and block comments so decorator-like words in prose don't trip the check
  const code = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  const problems = [];
  if (!/@ComponentV2\b/.test(code)) problems.push('missing @ComponentV2');
  for (const f of FORBIDDEN) if (f.re.test(code)) problems.push(`forbidden V1 decorator ${f.name}`);
  for (const c of CHURN) if (c.re.test(code)) problems.push(`key-churn token ${c.name}`);
  if (problems.length) {
    failures++;
    console.error(`FAIL ${rel}:\n    - ${problems.join('\n    - ')}`);
  } else {
    console.log(`ok   ${rel}`);
  }
}

console.log(`\n${checked} file(s) checked, ${failures} failure(s)`);
if (failures > 0) process.exit(1);
if (checked === 0) console.log('(no migrated files registered yet)');
