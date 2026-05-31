#!/usr/bin/env node
// Static contract pinning the V2 FeedPills recenter shape in IndexTitleBarComponents.ets.
//
// FeedPills was the LAST State-Management V1 adapter. It is now @ComponentV2: it reads the V2 FeedTabState
// mirror and recenters its pill bar from @Monitor('feedState.feedTab'). A V2 @Monitor fires ~32x for ONE
// discrete feedTab change (vs a V1 @Watch's 1x — adapter-zero lane, device-proven), and the deferred-center
// retry would storm scrollToIndex (~244x) if each fire re-armed it. The fix is the REQUEST-TIME
// `centeredTarget` coalescing guard: the first monitor fire for a new target arms it and drives one
// centerTab; the rest short-circuit; the centerTab/updateTabLayout machinery stays byte-identical to V1.
//
// This check fails closed if (a) FeedPills regresses to a V1 @Component / @StorageLink / @Watch / @State
// form, (b) it loses the @Monitor recenter signal, the `centeredTarget` coalescing guard, the FeedTabBridge
// tap routing, or the connectFeedTab() mirror read, or (c) any non-V2 @Component struct appears in the file.
// (The whole-file zero-V1 guard also lives in test_v2_leaf_migration_contract.mjs, which now lists this
// file; this contract pins the FeedPills-specific coalescing invariants that the leaf contract cannot.)
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

// Migration complete: EVERY struct in the file must be @ComponentV2 — zero V1 @Component.
const v1Structs = structs.filter((s) => !s.v2).map((s) => s.name);
must(v1Structs.length === 0, `${FILE}: no V1 @Component struct remains (found V1: [${v1Structs.join(', ')}])`);

// FeedPills must be @ComponentV2.
const feedPillsStruct = structs.find((s) => s.name === 'FeedPills');
must(feedPillsStruct && feedPillsStruct.v2, `${FILE}: FeedPills is @ComponentV2`);

// Extract the FeedPills struct body (brace-matched) for the V2-shape assertions.
const feedPills = (() => {
  const decl = /@ComponentV2\b\s*struct\s+FeedPills\s*\{/.exec(code);
  if (!decl) return '';
  const open = decl.index + decl[0].length - 1;
  let depth = 0;
  for (let i = open; i < code.length; i++) {
    if (code[i] === '{') depth++;
    else if (code[i] === '}' && --depth === 0) return code.slice(open, i + 1);
  }
  return '';
})();
must(feedPills.length > 0, `${FILE}: FeedPills struct body located`);

// No V1 component-state decorator survives inside FeedPills.
for (const [re, name] of [
  [/@StorageLink\b/, '@StorageLink'], [/@StorageProp\b/, '@StorageProp'], [/@Watch\b/, '@Watch'],
  [/@State\b/, '@State'], [/@Prop\b/, '@Prop'], [/@Link\b/, '@Link'],
  [/@Provide\b/, '@Provide'], [/@Consume\b/, '@Consume'], [/@ObjectLink\b/, '@ObjectLink'],
]) {
  must(!re.test(feedPills), `${FILE}: FeedPills carries no ${name}`);
}

// V2 recenter signal: @Monitor on the V2 mirror's feedTab field.
must(/@Monitor\(\s*['"]feedState\.feedTab['"]\s*\)/.test(feedPills),
  `${FILE}: FeedPills recenters from @Monitor('feedState.feedTab')`);

// Request-time coalescing guard against the ~32x monitor burst / off-screen scrollToIndex storm.
must(/\bcenteredTarget\b/.test(feedPills) && /index\s*===\s*this\.centeredTarget/.test(feedPills),
  `${FILE}: FeedPills has the request-time centeredTarget coalescing guard`);

// Reads the V2 FeedTabState mirror (not AppStorage) and still routes tab taps through the bridge.
must(/connectFeedTab\(\)/.test(feedPills), `${FILE}: FeedPills reads the connectFeedTab() V2 mirror`);
must(/FeedTabBridge\.publishSelectedKey/.test(feedPills),
  `${FILE}: FeedPills tab taps route through FeedTabBridge (AppStorage + V2 FeedTabState mirror)`);

// FeedPills reads the per-frame visual index from its OWN @ObservedV2 holder (FeedVisualIndexState), isolated
// from the @Monitor-ed FeedTabState so its high-frequency churn cannot perturb the feedTab observers.
must(/connectFeedVisualIndex\(\)/.test(feedPills) && /visualIndexState\.value/.test(feedPills),
  `${FILE}: FeedPills reads the per-frame index from the isolated FeedVisualIndexState holder`);

// No refresh-by-key-churn token snuck in to mask state bugs.
for (const [re, name] of [[/Date\.now\s*\(/, 'Date.now()'], [/Math\.random\s*\(/, 'Math.random()']]) {
  must(!re.test(feedPills), `${FILE}: FeedPills has no ${name} key-churn token`);
}

// The host pill ComponentContent MUST be cached (created once), not re-`new`-ed each Index.build(): a per-build
// ComponentContent re-mounts the @ComponentV2 FeedPills and ties Index.build to the per-frame visual index,
// device-proven to re-mount ~400x/s and storm the recenter scrollToIndex. Pin the cache in Index.ets.
{
  const INDEX = 'entry/src/main/ets/pages/Index.ets';
  const indexCode = strip(readFileSync(join(repo, INDEX), 'utf8'));
  must(/\bpillBarContent\b/.test(indexCode),
    `${INDEX}: caches the home pill-bar ComponentContent in a pillBarContent field`);
  must(/if\s*\(\s*!\s*this\.pillBarContent\s*\)/.test(indexCode),
    `${INDEX}: creates the pill ComponentContent once (guarded by !this.pillBarContent), never per-build`);
  // No bare per-build `new ComponentContent(... PillCCBuilder ...)` outside the cache assignment.
  const pillNews = [...indexCode.matchAll(/new\s+ComponentContent[\s\S]{0,160}?PillCCBuilder/g)].length;
  const cachedPillNews = [...indexCode.matchAll(/this\.pillBarContent\s*=\s*new\s+ComponentContent[\s\S]{0,160}?PillCCBuilder/g)].length;
  must(pillNews > 0 && pillNews === cachedPillNews,
    `${INDEX}: every PillCCBuilder ComponentContent creation assigns the cached pillBarContent (found ${pillNews}, cached ${cachedPillNews})`);
}

// The sibling migrated structs must stay V2 (defense-in-depth vs the appbar-identity contract).
for (const name of ['BlockedListsTabs', 'DiscoverSearchComponent', 'UserProfileAppbarIdentity', 'TopicDetailAppbarIdentity']) {
  const s = structs.find((x) => x.name === name);
  must(s && s.v2, `${FILE}: ${name} is @ComponentV2`);
}

// The coalescing-guard rationale comment must remain so a future maintainer does not remove the guard and
// reintroduce the over-fire/storm.
must(/centeredTarget/.test(raw) && (/coalesc/i.test(raw) || /over-fire/i.test(raw) || /burst/i.test(raw)),
  `${FILE}: FeedPills coalescing-guard rationale comment is preserved`);

console.log(`\nindex-titlebar-feedpills V2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
