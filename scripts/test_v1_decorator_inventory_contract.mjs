#!/usr/bin/env node
// Final State Management V1-decorator inventory gate (bulk-remaining lane).
//
// Comment-stripped scan of every .ets under entry/ feature/ shared/ (excluding build output) for LIVE V1
// component-state decorators (@Component bare / @State / @Prop / @Link / @Watch / @StorageLink /
// @StorageProp / @Provide / @Consume / @ObjectLink / @Observed bare / @LocalStorage*). The State Management
// V2 migration is COMPLETE: the ALLOWED adapter allowlist is now EMPTY, so ANY file carrying a live V1
// decorator fails the gate. This proves "V1 decorators are zero" with no documented-adapter exceptions.
//
// History: the last intentional adapter was FeedPills (IndexTitleBarComponents.ets). The adapter-zero lane
// device-proved a naive V2 @Monitor recenter over-fires (~32x/change vs V1 @Watch 1x, storming scrollToIndex
// to ~244 calls); the state-v2-feedpills-final lane retired it by migrating FeedPills to @ComponentV2 with a
// request-time `centeredTarget` coalescing guard that collapses the burst to one effective recenter.
//
// Run: node scripts/test_v1_decorator_inventory_contract.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');

// Documented intentional V1 adapters that may still carry V1 decorators. The migration is COMPLETE, so this
// allowlist is intentionally EMPTY: every .ets under entry/feature/shared must be free of live V1
// component-state decorators. Re-adding an entry here would re-open a V1 exception and must be justified by
// a fresh device-proven blocker — do not add one to "simplify" a migration.
const ALLOWED = {};

const FORBIDDEN = [
  /@Component\b(?!V2)/, /@State\b/, /@Prop\b/, /@Link\b/, /@Watch\b/, /@StorageLink\b/, /@StorageProp\b/,
  /@Provide\b/, /@Consume\b/, /@ObjectLink\b/, /@Observed\b(?!V2)/, /@LocalStorageLink\b/, /@LocalStorageProp\b/,
];
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

function* walk(dir) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    const st = statSync(p);
    if (st.isDirectory()) {
      if (['node_modules', 'build', '.preview', 'oh_modules'].includes(e)) continue;
      yield* walk(p);
    } else if (e.endsWith('.ets')) {
      yield p;
    }
  }
}

let failures = 0;
const found = new Set();
for (const root of ['entry', 'feature', 'shared']) {
  for (const abs of walk(join(repo, root))) {
    const code = strip(readFileSync(abs, 'utf8'));
    if (FORBIDDEN.some((re) => re.test(code))) {
      found.add(relative(repo, abs).split('\\').join('/'));
    }
  }
}

// Every file with a live V1 decorator must be an allowlisted documented adapter.
for (const rel of [...found].sort()) {
  if (ALLOWED[rel]) {
    console.log(`ok   intentional V1 adapter: ${rel}\n       reason: ${ALLOWED[rel]}`);
  } else {
    console.error(`FAIL un-migrated V1 decorators in: ${rel}`);
    failures++;
  }
}
// Every allowlisted adapter must still exist + still carry V1 (else the allowlist is stale).
for (const rel of Object.keys(ALLOWED)) {
  if (!found.has(rel)) {
    console.error(`FAIL allowlisted adapter no longer carries V1 decorators (remove it from ALLOWED): ${rel}`);
    failures++;
  }
}

console.log(`\nV1 decorator inventory: ${found.size} file(s) with live V1 decorators (allowlist is empty — target 0); ${failures} failure(s)`);
if (failures > 0) process.exit(1);
if (found.size === 0) console.log('V1 decorators are ZERO across entry/feature/shared — migration complete.');
