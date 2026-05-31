#!/usr/bin/env node
// Static contract for the TopicDetailPage State Management V1 -> V2 split lane.
//
// The whole-file purity of TopicDetailPage.ets is already asserted by
// test_v2_leaf_migration_contract.mjs (it is registered in v2-migrated-leaves.json). THIS check
// pins the lane-specific wiring that the leaf contract cannot see, and fails closed if a future
// edit silently regresses any of it:
//
//   1. TopicDetailPage consumes the V2 backbone correctly: connectNavStack().stack (no @Consume),
//      the three reactive mirrors (auth-cookie / motion-edge / reply-button), and @Monitor for the
//      motion-edge + reply-button preferences.
//   2. The TOPIC_DETAIL_ACTION command bus stays Index-free: it is owned by the V1 @Component
//      adapter TopicDetailActionListener (intentionally V1 @StorageLink+@Watch), hosted by the page.
//   3. The three mirror dual-write chokepoints exist at their single writers.
//   4. Index.ets is NOT crossed: it neither imports the topic-detail mirrors nor stops writing the
//      V1 TOPIC_DETAIL_ACTION key — i.e. the page migrated without touching Index.
//
// Run: node scripts/test_topicdetail_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const read = (rel) => readFileSync(join(repo, rel), 'utf8');
// strip comments so prose mentioning a decorator/token never trips a check
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

let failures = 0;
const ok = (m) => console.log(`ok   ${m}`);
const fail = (m) => { console.error(`FAIL ${m}`); failures++; };
const must = (cond, m) => (cond ? ok(m) : fail(m));

const PAGE = 'feature/detail/src/main/ets/pages/TopicDetailPage.ets';
const LISTENER = 'feature/detail/src/main/ets/components/TopicDetailActionListener.ets';
const INDEX = 'entry/src/main/ets/pages/Index.ets';

// 1) TopicDetailPage V2 backbone wiring -------------------------------------------------------
{
  const raw = read(PAGE);
  const code = strip(raw);
  must(/@ComponentV2\b/.test(code), `${PAGE}: is @ComponentV2`);
  must(/connectNavStack\(\)\.stack/.test(code), `${PAGE}: navigation via connectNavStack().stack`);
  must(/connectAuthCookie\(\)/.test(code), `${PAGE}: reads connectAuthCookie() mirror`);
  must(/connectMotionHandEdge\(\)/.test(code), `${PAGE}: reads connectMotionHandEdge() mirror`);
  must(/connectTopicDetailReplyButton\(\)/.test(code), `${PAGE}: reads connectTopicDetailReplyButton() mirror`);
  must(/@Monitor\(\s*['"]motion\.edge['"]\s*\)/.test(code), `${PAGE}: @Monitor('motion.edge')`);
  must(/@Monitor\(\s*['"]replyButton\.autoHide['"]\s*\)/.test(code), `${PAGE}: @Monitor('replyButton.autoHide')`);
  // command bus is delegated to the V1 adapter, not observed in the page
  must(/TopicDetailActionListener\s*\(/.test(code), `${PAGE}: hosts TopicDetailActionListener adapter`);
  // appbar identity behavior preserved (same coordinator + route-id key publishing)
  must(/TopicDetailAppbarCoordinator/.test(code), `${PAGE}: still uses TopicDetailAppbarCoordinator`);
  must(/StorageKeys\.TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID/.test(code), `${PAGE}: publishes appbar route-id key`);
  // no V1 component-state decorators survive (defense-in-depth vs leaf contract)
  for (const d of ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Consume', '@Provide', '@ObjectLink', '@CustomDialog']) {
    must(!new RegExp(`${d}\\b`).test(code), `${PAGE}: no surviving ${d}`);
  }
}

// 2) TopicDetailActionListener is the intentional V1 command-bus adapter -----------------------
{
  const code = strip(read(LISTENER));
  must(/@Component\b(?!V2)/.test(code), `${LISTENER}: intentionally V1 @Component adapter`);
  must(/@StorageLink\(\s*StorageKeys\.TOPIC_DETAIL_ACTION\s*\)/.test(code), `${LISTENER}: owns @StorageLink(TOPIC_DETAIL_ACTION)`);
  must(/@Watch\(/.test(code), `${LISTENER}: reacts via @Watch`);
  must(/onCommand\b/.test(code), `${LISTENER}: reports up via onCommand callback`);
}

// 3) Mirror dual-write chokepoints ------------------------------------------------------------
must(/connectAuthCookie\(\)\.configured\s*=/.test(strip(read('shared/src/main/ets/settings/CookieJarSettings.ets'))),
  'CookieJarSettings.refreshConfiguredState: dual-writes connectAuthCookie().configured');
must(/connectMotionHandEdge\(\)\.edge\s*=/.test(strip(read('shared/src/main/ets/services/MotionHandStateService.ets'))),
  'MotionHandStateService.setEdge: dual-writes connectMotionHandEdge().edge');
must(/connectTopicDetailReplyButton\(\)\.autoHide\s*=/.test(strip(read('shared/src/main/ets/settings/TopicDetailReplyActionSettings.ets'))),
  'TopicDetailReplyActionSettings.apply: dual-writes connectTopicDetailReplyButton().autoHide');

// 4) Index.ets boundary preserved (page migrated without touching Index) -----------------------
{
  const code = strip(read(INDEX));
  must(!/connectAuthCookie|connectMotionHandEdge|connectTopicDetailReplyButton/.test(code),
    `${INDEX}: does not import the topic-detail mirrors (Index-free migration)`);
  must(/AppStorage\.setOrCreate<string>\(\s*StorageKeys\.TOPIC_DETAIL_ACTION/.test(code),
    `${INDEX}: still the V1-only writer of TOPIC_DETAIL_ACTION (command bus unchanged)`);
}

console.log(`\ntopicdetail-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
