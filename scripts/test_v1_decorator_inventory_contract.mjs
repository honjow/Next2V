#!/usr/bin/env node
// Final State Management V1-decorator inventory gate (bulk-remaining lane).
//
// Comment-stripped scan of every .ets under entry/ feature/ shared/ (excluding build output) for LIVE V1
// component-state decorators (@Component bare / @State / @Prop / @Link / @Watch / @StorageLink /
// @StorageProp / @Provide / @Consume / @ObjectLink / @Observed bare / @LocalStorage*). After the full
// migration the ONLY files allowed to still carry any are the explicitly-documented intentional V1
// adapters. Any other file with a live V1 decorator — or an allowlisted adapter that has unexpectedly
// disappeared — fails the gate. This proves "V1 decorators are zero except documented unavoidable adapters".
//
// Run: node scripts/test_v1_decorator_inventory_contract.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');

// Documented intentional V1 adapters that may still carry V1 decorators, each with a still-valid reason.
// (Pinned in detail by their own contracts: blocked-lists-v2 / index-titlebar-feedpills-adapter / the
// SegmentButton adapter contract.)
const ALLOWED = {
  'entry/src/main/ets/components/BlockedListsTabsSegment.ets':
    'HDS SegmentButton two-way selectedIndexes is a V1 @Link-only API a @ComponentV2 cannot bind.',
  'entry/src/main/ets/components/IndexTitleBarComponents.ets':
    'FeedPills: its recenter machinery device-verifiably over-fires a V2 @Monitor (~37x/change).',
  'feature/user/src/main/ets/components/UserProfileActivityTabs.ets':
    'HDS SegmentButton two-way selectedIndexes is a V1 @Link-only API a @ComponentV2 cannot bind.',
};

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

console.log(`\nV1 decorator inventory: ${found.size} file(s) with live V1 decorators, all documented adapters; ${failures} failure(s)`);
if (failures > 0) process.exit(1);
