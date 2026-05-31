#!/usr/bin/env node
// Static contract for the Index backbone State Management V1 -> V2 migration (bulk-remaining lane).
//
// Index is @Entry and the app root; this pins the keystone migration and fails closed on regressions:
//   1. Index is @Entry @ComponentV2 with NO surviving V1 component-state decorator and NO @Provide('ns')
//      (every former @Consume('ns') consumer migrated to connectNavStack().stack).
//   2. Index reads the V2 mirrors it formerly read via @StorageLink: the three appbar mirrors
//      (topicDetail/nodeTopic/userProfile), notification-unread, home-tab, auth-session, two-factor,
//      account-webview, pending-url; and reacts via @Monitor (pending-url / home-tab / two-factor /
//      auth-session) instead of @Watch.
//   3. The refresh-key churn (= Date.now()) is gone — replaced by monotonic ++ counters.
//   4. The producer pages route their appbar writes through the write-through publish helpers (no raw
//      AppStorage.setOrCreate of the appbar OUTPUT keys remains in the producers).
//   5. The appbar mirror classes expose the expected @Trace fields + connect helpers.
//
// Run: node scripts/test_index_backbone_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const read = (rel) => readFileSync(join(repo, rel), 'utf8');
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

let failures = 0;
const ok = (m) => console.log(`ok   ${m}`);
const fail = (m) => { console.error(`FAIL ${m}`); failures++; };
const must = (cond, m) => (cond ? ok(m) : fail(m));

const INDEX = 'entry/src/main/ets/pages/Index.ets';

// 1) Index is @Entry @ComponentV2, V1-decorator-free, no @Provide('ns') -------------------------
{
  const code = strip(read(INDEX));
  must(/@Entry\b/.test(code) && /@ComponentV2\b/.test(code), `${INDEX}: @Entry @ComponentV2`);
  for (const d of ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Provide', '@Consume', '@ObjectLink']) {
    must(!new RegExp(`${d}\\b`).test(code), `${INDEX}: no surviving ${d}`);
  }
  must(/connectNavStack\(\)\.stack/.test(code), `${INDEX}: ns via connectNavStack().stack`);

  // 2) mirror reads
  for (const c of ['connectTopicDetailAppbar', 'connectNodeTopicAppbar', 'connectUserProfileAppbar',
    'connectNotificationUnread', 'connectHomeTabAutoHide', 'connectAuthSessionSignal', 'connectTwoFactor',
    'connectAccountWebViewUrl', 'connectPendingV2exUrl']) {
    must(new RegExp(`${c}\\(`).test(code), `${INDEX}: reads ${c}() mirror`);
  }
  // @Monitor reactions
  for (const m of ['pendingUrl.command', 'homeTab.autoHide', 'twoFactor.visible', 'authSession.updatedAt']) {
    must(new RegExp(`@Monitor\\(\\s*['"]${m.replace('.', '\\.')}['"]\\s*\\)`).test(code), `${INDEX}: @Monitor('${m}')`);
  }
  // bindSheet two-way @Local kept in sync with the mirror
  must(/@Local\s+twoFactorVisible\b/.test(code), `${INDEX}: @Local twoFactorVisible for bindSheet`);

  // 3) no refresh-key churn (Date.now() refresh tokens removed -> ++ counters)
  must(!/RefreshKey\s*=\s*Date\.now\(\)/.test(code), `${INDEX}: refresh-key churn (= Date.now()) removed`);
  must(/notificationRefreshKey\+\+/.test(code) && /accountRefreshKey\+\+/.test(code), `${INDEX}: refresh keys are monotonic ++ counters`);
}

// 4) producer pages route appbar writes through the write-through helpers (no raw setOrCreate left) ---
const producers = {
  'feature/detail/src/main/ets/pages/TopicDetailPage.ets': /TOPIC_DETAIL_(SAVED_LATER|SITE_FAVORITED|THANKED|APPBAR_)/,
  'feature/node/src/main/ets/pages/NodeTopicPage.ets': /NODE_TOPIC_(SAVED|SITE_FAVORITED|TITLE|SUBTITLE)/,
  'feature/user/src/main/ets/pages/UserProfilePage.ets': /USER_PROFILE_(ACTIONS_|FOLLOW_LABEL|BLOCK_LABEL|FOLLOWING|BLOCKED|APPBAR_)/,
};
for (const [rel, keyRe] of Object.entries(producers)) {
  const code = strip(read(rel));
  must(/publish(TopicDetail|NodeTopic|UserProfile)/.test(code), `${rel}: uses appbar write-through publish helpers`);
  const rawWrites = (code.match(/AppStorage\.setOrCreate<[^>]+>\(\s*StorageKeys\.\w+/g) || [])
    .filter((w) => keyRe.test(w));
  must(rawWrites.length === 0, `${rel}: no raw AppStorage.setOrCreate of appbar OUTPUT keys (found ${rawWrites.length})`);
}

// 5) appbar mirror shapes ----------------------------------------------------------------------
const mirrors = [
  ['shared/src/main/ets/state/TopicDetailAppbarState.ets', 'connectTopicDetailAppbar', ['savedLater', 'siteFavorited', 'thanked', 'title', 'routeTopicId']],
  ['shared/src/main/ets/state/NodeTopicAppbarState.ets', 'connectNodeTopicAppbar', ['saved', 'siteFavorited', 'title', 'subtitle']],
  ['shared/src/main/ets/state/UserProfileAppbarState.ets', 'connectUserProfileAppbar', ['actionsAvailable', 'followLabel', 'following', 'titleUsername']],
];
for (const [rel, connect, fields] of mirrors) {
  const code = strip(read(rel));
  must(/@ObservedV2\b/.test(code), `${rel}: @ObservedV2`);
  must(new RegExp(`export function ${connect}\\(`).test(code), `${rel}: exports ${connect}()`);
  for (const f of fields) must(new RegExp(`@Trace\\s+${f}\\b`).test(code), `${rel}: @Trace ${f}`);
}

console.log(`\nindex-backbone-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
