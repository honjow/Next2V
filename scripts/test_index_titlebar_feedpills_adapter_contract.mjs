#!/usr/bin/env node
// Static contract pinning the IndexTitleBarComponents V1/V2 boundary (bulk-remaining lane).
//
// Every struct in IndexTitleBarComponents.ets is @ComponentV2 EXCEPT FeedPills, which stays an
// intentional V1 @Component adapter: its tab-bar recenter machinery (centerTab -> scrollToIndex ->
// onAreaChange -> updateTabLayout -> re-render) device-verifiably re-fires a V2 @Monitor ~37x per single
// feedTab change vs ~1x for a V1 @Watch, so hosting the recenter under V2 over-fires. Migrating it needs a
// non-@Monitor recenter trigger (a separately-scoped UI follow-up); doing so here would change the
// tab-centering interaction, which the UI-preservation rule forbids for technical convenience. FeedPills
// still participates in the V2 feed-tab migration: its tab taps route through FeedTabBridge (AppStorage +
// the FeedTabState mirror the @ComponentV2 HomePage reads).
//
// This check fails closed if (a) FeedPills silently flips away from its documented V1 form, (b) it stops
// routing through FeedTabBridge, or (c) a NEW non-FeedPills V1 @Component struct is introduced in the file.
//
// Run: node scripts/test_index_titlebar_feedpills_adapter_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const FILE = 'entry/src/main/ets/components/IndexTitleBarComponents.ets';
const raw = readFileSync(join(repo, FILE), 'utf8');
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
const code = strip(raw);

let failures = 0;
const ok = (m) => console.log(`ok   ${m}`);
const fail = (m) => { console.error(`FAIL ${m}`); failures++; };
const must = (cond, m) => (cond ? ok(m) : fail(m));

// Enumerate `(@Component|@ComponentV2) struct <Name>` and classify.
const structs = [...code.matchAll(/@(ComponentV2|Component)\b\s*struct\s+(\w+)/g)].map((m) => ({ v2: m[1] === 'ComponentV2', name: m[2] }));
must(structs.length > 0, `${FILE}: found struct declarations`);

const v1Structs = structs.filter((s) => !s.v2).map((s) => s.name);
must(v1Structs.length === 1 && v1Structs[0] === 'FeedPills',
  `${FILE}: FeedPills is the ONLY V1 @Component struct (found V1: [${v1Structs.join(', ')}])`);

// FeedPills keeps its documented V1 reactive shape (the over-firing it avoids).
const feedPills = (() => {
  const decl = /@Component\b\s*struct\s+FeedPills\s*\{/.exec(code);
  if (!decl) return '';
  const open = decl.index + decl[0].length - 1;
  let depth = 0;
  for (let i = open; i < code.length; i++) {
    if (code[i] === '{') depth++;
    else if (code[i] === '}' && --depth === 0) return code.slice(open, i + 1);
  }
  return '';
})();
must(/@StorageLink\(\s*StorageKeys\.FEED_TAB\s*\)/.test(feedPills) && /@Watch\(\s*['"]onFeedTabChanged['"]\s*\)/.test(feedPills),
  `${FILE}: FeedPills keeps @StorageLink(FEED_TAB)+@Watch (its well-behaved V1 recenter trigger)`);
must(/FeedTabBridge\.publishSelectedKey/.test(feedPills),
  `${FILE}: FeedPills tab taps route through FeedTabBridge (AppStorage + V2 FeedTabState mirror)`);

// The migrated structs must stay V2 (defense-in-depth vs the appbar-identity contract).
for (const name of ['BlockedListsTabs', 'DiscoverSearchComponent', 'UserProfileAppbarIdentity', 'TopicDetailAppbarIdentity']) {
  const s = structs.find((x) => x.name === name);
  must(s && s.v2, `${FILE}: ${name} is @ComponentV2`);
}

// The rationale comment must remain so a future maintainer does not "simplify" FeedPills to V2 blindly.
must(/non-@Monitor recenter trigger/.test(raw) || /over-fires/.test(raw) || /37x/.test(raw),
  `${FILE}: FeedPills intentional-V1 rationale comment is preserved`);

console.log(`\nindex-titlebar-feedpills-adapter contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
