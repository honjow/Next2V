#!/usr/bin/env node
// Alternate (per-struct) static contract for the appbar-identity V2 slice.
//
// IndexTitleBarComponents.ets cannot join scripts/v2-migrated-leaves.json yet because it still hosts one
// intentionally-V1 struct: FeedPills (its tab-bar layout machinery over-fires a V2 @Monitor on every
// recenter frame, so it stays V1 @StorageLink/@Watch and feeds the V2 FeedTabState mirror via the bridge;
// migrating it to V2 is a deferred follow-up). BlockedListsTabs was migrated in blocked-lists-v2 and is
// asserted by test_blocked_lists_v2_contract.mjs. The whole-file contract is therefore not applicable here.
//
// This check fails closed on the two zero-coupling appbar identity leaves migrated in this slice:
//   UserProfileAppbarIdentity, TopicDetailAppbarIdentity
// asserting each is @ComponentV2 and that its body carries NO V1 component-state decorator and
// no refresh-by-key-churn token. Run: node scripts/test_appbar_identity_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const file = join(repo, 'entry/src/main/ets/components/IndexTitleBarComponents.ets');
const src = readFileSync(file, 'utf8');

const STRUCTS = ['UserProfileAppbarIdentity', 'TopicDetailAppbarIdentity'];
const FORBIDDEN = [
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

// Returns { decorator, body } for `struct <name> { ... }`, where decorator is the
// @Component / @ComponentV2 token immediately preceding the struct keyword, and body
// is the brace-matched struct block. null if the struct is not present.
function extractStruct(text, name) {
  const decl = new RegExp(`struct\\s+${name}\\s*\\{`).exec(text);
  if (!decl) return null;
  const head = text.slice(0, decl.index);
  const decorator = (head.match(/@Component(?:V2)?\b/g) || []).pop() || null;
  // Brace-match from the struct's opening `{`.
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
for (const name of STRUCTS) {
  const found = extractStruct(src, name);
  if (!found) {
    console.error(`FAIL ${name}: struct not found`);
    failures++;
    continue;
  }
  let structFail = 0;
  if (found.decorator !== '@ComponentV2') {
    console.error(`FAIL ${name}: expected @ComponentV2 decorator, found ${found.decorator || 'none'}`);
    structFail++;
  }
  for (const f of FORBIDDEN) {
    if (f.re.test(found.body)) {
      console.error(`FAIL ${name}: forbidden V1 decorator ${f.name} present in struct body`);
      structFail++;
    }
  }
  for (const c of CHURN) {
    if (c.re.test(found.body)) {
      console.error(`FAIL ${name}: refresh-by-key-churn token ${c.name} present in struct body`);
      structFail++;
    }
  }
  if (!/@Param\b/.test(found.body)) {
    console.error(`FAIL ${name}: expected @Param members after migration`);
    structFail++;
  }
  failures += structFail;
  if (structFail === 0) {
    console.log(`ok   ${name} (@ComponentV2, @Param/@Local, no V1 decorators, no churn)`);
  }
}

if (failures > 0) {
  console.error(`\n${failures} failure(s)`);
  process.exit(1);
}
console.log(`\n${STRUCTS.length} struct(s) checked, 0 failure(s)`);
