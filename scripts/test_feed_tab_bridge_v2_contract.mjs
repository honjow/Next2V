#!/usr/bin/env node
// Static contract for the feed-tab V1->V2 storage bridge (feed-tab-v2 + homenodesettings-v2 slices).
//
// FEED_TAB / FEED_TAB_KEYS are now PURE-V2: every consumer reads the FeedTabState mirror.
//   - @ComponentV2 consumers (HomePage, HomeNodeSettingsPage, FeedPills) read the FeedTabState mirror.
//   - FeedTabSettings (a service class) reads feedTab/feedTabKeys imperatively off connectFeedTab().
// FeedTabBridge therefore writes ONLY the V2 mirror; the legacy FEED_TAB / FEED_TAB_KEYS AppStorage half
// was retired once no reader read it. This contract fails closed if a future edit reintroduces the legacy
// AppStorage dual-write (setAppStorageValue on either key) or breaks the FeedTabBridge mirror write, which
// would silently desync consumers (stale feed pills / stale settings list).
// feedTabVisualIndex is a PURE-V2 @Trace field on its OWN holder (FeedVisualIndexState), isolated from
// the @Monitor-ed FeedTabState so its per-frame churn cannot perturb the feedTab observers. FeedPills is its
// only reader, HomePage its only writer; publishVisualIndex writes only that holder, asserted below.
//
// Run: node scripts/test_feed_tab_bridge_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');

let failures = 0;
const fail = (msg) => { console.error(`FAIL ${msg}`); failures++; };
const ok = (msg) => console.log(`ok   ${msg}`);

function read(rel) {
  return readFileSync(join(repo, rel), 'utf8');
}
// strip comments so prose mentioning a forbidden token does not trip the check
function code(rel) {
  return read(rel).replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
}

// 1. FeedTabBridge writes the V2 mirror for each shared key and NO LONGER dual-writes AppStorage.
const bridge = code('shared/src/main/ets/state/FeedTabState.ets');
const bridgeChecks = [
  { name: 'publishKeys -> V2 mirror feedTabKeys', re: /connectFeedTab\(\)\.feedTabKeys\s*=/ },
  { name: 'publishSelectedKey -> V2 mirror feedTab', re: /connectFeedTab\(\)\.feedTab\s*=/ },
  { name: 'publishVisualIndex -> V2 FeedVisualIndexState holder (pure-V2, isolated from FeedTabState)', re: /connectFeedVisualIndex\(\)\.value\s*=/ },
];
for (const c of bridgeChecks) {
  if (c.re.test(bridge)) ok(`FeedTabState: ${c.name}`);
  else fail(`FeedTabState: missing ${c.name}`);
}
// The legacy AppStorage half must stay retired: no setAppStorageValue / AppStorage write of either key.
if (/setAppStorageValue<string>\(\s*StorageKeys\.FEED_TAB/.test(bridge) || /AppStorage\.set(OrCreate)?<[^>]*>\(\s*StorageKeys\.FEED_TAB/.test(bridge)) {
  fail('FeedTabState: reintroduced the legacy FEED_TAB / FEED_TAB_KEYS AppStorage dual-write (must be V2-only)');
} else ok('FeedTabState: no legacy FEED_TAB / FEED_TAB_KEYS AppStorage dual-write (V2-only)');

// 2. The persistence layer applies feed-tab keys through the bridge and reads selection/keys off the V2 mirror.
const settings = code('shared/src/main/ets/settings/FeedTabSettings.ets');
if (/FeedTabBridge\.publishKeys\(/.test(settings)) ok('FeedTabSettings: apply routes through FeedTabBridge.publishKeys');
else fail('FeedTabSettings: apply no longer routes through FeedTabBridge.publishKeys');
if (/connectFeedTab\(\)\.feedTab\b/.test(settings) && /connectFeedTab\(\)\.feedTabKeys\b/.test(settings)) {
  ok('FeedTabSettings: save/saveSelectedKey read the FeedTabState V2 mirror (not AppStorage.get)');
} else fail('FeedTabSettings: save/saveSelectedKey no longer read the FeedTabState V2 mirror');
if (/AppStorage\.get<[^>]*>\(\s*StorageKeys\.FEED_TAB/.test(settings)) {
  fail('FeedTabSettings: still reads FEED_TAB / FEED_TAB_KEYS via AppStorage.get (must read the V2 mirror)');
} else ok('FeedTabSettings: no AppStorage.get of FEED_TAB / FEED_TAB_KEYS');

// 3. HomeNodeSettingsPage (the settings writer) routes its write through the bridge and never writes the
//    AppStorage key directly. @StorageLink absence is already enforced by the V2 leaf contract.
const page = code('feature/settings/src/main/ets/pages/HomeNodeSettingsPage.ets');
if (/FeedTabBridge\.publishKeys\(/.test(page)) ok('HomeNodeSettingsPage: saveFeedTabs routes through FeedTabBridge.publishKeys');
else fail('HomeNodeSettingsPage: write no longer routes through FeedTabBridge.publishKeys');
if (/AppStorage\.set(OrCreate)?\b/.test(page)) fail('HomeNodeSettingsPage: introduced a raw AppStorage write (must use FeedTabBridge)');
else ok('HomeNodeSettingsPage: no raw AppStorage write');
if (/connectFeedTab\(\)/.test(page)) ok('HomeNodeSettingsPage: reads the FeedTabState V2 mirror');
else fail('HomeNodeSettingsPage: no longer reads the FeedTabState V2 mirror');

console.log(`\nfeed-tab-bridge-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
