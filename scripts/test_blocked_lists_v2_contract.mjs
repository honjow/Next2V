#!/usr/bin/env node
// Focused static contract for the blocked-lists State Management V1 -> V2 slice (blocked-lists-v2).
//
// BlockedListsPage.ets is a whole-file leaf and is covered by test_v2_leaf_migration_contract.mjs.
// This check covers the parts of the slice that the whole-file contract can NOT:
//
//   1. BlockedListsTabs (in IndexTitleBarComponents.ets) is @ComponentV2 with NO V1 component-state
//      decorator and no refresh-by-key-churn token. The whole-file contract can't assert this struct
//      because the same file still hosts the intentionally-V1 FeedPills struct (see feed-tab-v2 cut).
//   2. BlockedListsTabsSegment.ets is a clean @ComponentV2 segmented control hosting the V2-native
//      TabSegmentButtonV2 (the tab-style successor of the V1 SegmentButton, taking a one-way
//      @Param selectedIndex with no @Link). We assert it carries no V1 decorator, hosts
//      TabSegmentButtonV2, keeps the controlled one-way selectedIndex (NOT V1 $selectedIndexes two-way),
//      and preserves the two label inputs + the click route.
//   3. The BlockedListState.ets mirror declares @ObservedV2 classes with @Trace fields + connect helpers.
//
// Run: node scripts/test_blocked_lists_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');

const V1_STATE_DECORATORS = [
  { re: /@State\b/, name: '@State' },
  { re: /@Prop\b/, name: '@Prop' },
  { re: /@Link\b/, name: '@Link' },
  { re: /@Watch\b/, name: '@Watch' },
  { re: /@StorageLink\b/, name: '@StorageLink' },
  { re: /@StorageProp\b/, name: '@StorageProp' },
  { re: /@Provide\b/, name: '@Provide' },
  { re: /@Consume\b/, name: '@Consume' },
  { re: /@ObjectLink\b/, name: '@ObjectLink' },
];
const CHURN = [
  { re: /Date\.now\s*\(/, name: 'Date.now()' },
  { re: /Math\.random\s*\(/, name: 'Math.random()' },
];

function read(rel) {
  return readFileSync(join(repo, rel), 'utf8');
}

// strip comments so decorator-like words in prose don't trip checks
function stripComments(text) {
  return text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
}

// Returns { decorator, body } for `struct <name> { ... }` (brace-matched), or null.
function extractStruct(text, name) {
  const decl = new RegExp(`struct\\s+${name}\\s*\\{`).exec(text);
  if (!decl) return null;
  const head = text.slice(0, decl.index);
  const decorator = (head.match(/@Component(?:V2)?\b/g) || []).pop() || null;
  const open = decl.index + decl[0].length - 1;
  let depth = 0;
  let end = -1;
  for (let i = open; i < text.length; i++) {
    if (text[i] === '{') depth++;
    else if (text[i] === '}' && --depth === 0) { end = i; break; }
  }
  if (end < 0) return null;
  return { decorator, body: text.slice(open, end + 1) };
}

let failures = 0;
const fail = (msg) => { console.error(`FAIL ${msg}`); failures++; };
const ok = (msg) => console.log(`ok   ${msg}`);

// 1. BlockedListsTabs is a clean @ComponentV2 struct.
{
  const src = stripComments(read('entry/src/main/ets/components/IndexTitleBarComponents.ets'));
  const found = extractStruct(src, 'BlockedListsTabs');
  if (!found) {
    fail('BlockedListsTabs: struct not found');
  } else {
    if (found.decorator !== '@ComponentV2') fail(`BlockedListsTabs: expected @ComponentV2, found ${found.decorator || 'none'}`);
    for (const d of V1_STATE_DECORATORS) if (d.re.test(found.body)) fail(`BlockedListsTabs: forbidden V1 decorator ${d.name}`);
    for (const c of CHURN) if (c.re.test(found.body)) fail(`BlockedListsTabs: key-churn token ${c.name}`);
    if (!/@Local\b/.test(found.body)) fail('BlockedListsTabs: expected @Local members after migration');
    if (failures === 0) ok('BlockedListsTabs (@ComponentV2, @Local, no V1 decorators, no churn)');
  }
}

// 2. BlockedListsTabsSegment is a clean @ComponentV2 hosting V2-native TabSegmentButtonV2.
{
  const before = failures;
  const src = stripComments(read('entry/src/main/ets/components/BlockedListsTabsSegment.ets'));
  const found = extractStruct(src, 'BlockedListsTabsSegment');
  if (!found) {
    fail('BlockedListsTabsSegment: struct not found');
  } else {
    if (found.decorator !== '@ComponentV2') {
      fail(`BlockedListsTabsSegment: expected @ComponentV2, found ${found.decorator || 'none'}`);
    }
    for (const d of V1_STATE_DECORATORS) if (d.re.test(found.body)) fail(`BlockedListsTabsSegment: forbidden V1 decorator ${d.name}`);
    if (!/TabSegmentButtonV2\s*\(/.test(src)) fail('BlockedListsTabsSegment: expected to host TabSegmentButtonV2(...)');
    if (/\bSegmentButton\s*\(/.test(src)) fail('BlockedListsTabsSegment: must not host the V1 SegmentButton(...)');
    // Controlled one-way selectedIndex (NOT the V1 two-way $selectedIndexes @Link binding).
    if (!/selectedIndex\s*:/.test(src)) fail('BlockedListsTabsSegment: expected one-way selectedIndex binding');
    if (/\$selectedIndexes\b/.test(src)) fail('BlockedListsTabsSegment: must not use V1 two-way $selectedIndexes');
    // Two label inputs + click route preserved.
    if (!/@Param\s+firstLabel\b/.test(found.body) || !/@Param\s+secondLabel\b/.test(found.body)) {
      fail('BlockedListsTabsSegment: expected @Param firstLabel + secondLabel inputs');
    }
    if (!/onItemClicked\s*:/.test(src) || !/onTabClicked\b/.test(src)) fail('BlockedListsTabsSegment: expected onItemClicked -> onTabClicked route');
    if (failures === before) ok('BlockedListsTabsSegment (@ComponentV2 hosting TabSegmentButtonV2, controlled selectedIndex, labels + click preserved)');
  }
}

// 3. BlockedListState mirror shape.
{
  const before = failures;
  const src = stripComments(read('shared/src/main/ets/state/BlockedListState.ets'));
  for (const cls of ['BlockedListSelectedTabState', 'BlockedListStorageState']) {
    if (!new RegExp(`@ObservedV2[\\s\\S]*?class\\s+${cls}\\b`).test(src)) fail(`BlockedListState: ${cls} must be @ObservedV2`);
  }
  if (!/@Trace\s+selectedTab\b/.test(src)) fail('BlockedListState: BlockedListSelectedTabState.selectedTab must be @Trace');
  for (const field of ['ignoredTopicIdsJson', 'blockedMemberIdsJson', 'updatedAt']) {
    if (!new RegExp(`@Trace\\s+${field}\\b`).test(src)) fail(`BlockedListState: BlockedListStorageState.${field} must be @Trace`);
  }
  for (const fn of ['connectBlockedListSelectedTab', 'connectBlockedListStorage']) {
    if (!new RegExp(`export function ${fn}\\b`).test(src)) fail(`BlockedListState: missing ${fn} helper`);
  }
  if (failures === before) ok('BlockedListState (@ObservedV2 mirrors with @Trace fields + connect helpers)');
}

if (failures > 0) {
  console.error(`\n${failures} failure(s)`);
  process.exit(1);
}
console.log('\nblocked-lists-v2 contract: 0 failure(s)');
