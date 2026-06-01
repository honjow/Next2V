#!/usr/bin/env node
// Static contract for the feed-tab V1->V2 storage bridge (feed-tab-v2 + homenodesettings-v2 slices).
//
// FEED_TAB / FEED_TAB_KEYS are written through FeedTabBridge, which dual-writes both stores so all
// consumers stay consistent:
//   - @ComponentV2 consumers (HomePage, HomeNodeSettingsPage, FeedPills) read the FeedTabState mirror.
//   - FeedTabSettings reads them imperatively (AppStorage.get) — a service class, not a component.
// The ONLY safe write path therefore dual-writes BOTH stores. This contract fails closed if a future edit
// reintroduces a single-store write (raw AppStorage.set) on the writer page, or breaks the FeedTabBridge
// dual-write, which would silently desync the AppStorage key and the V2 mirror (stale feed pills /
// stale settings list).
// feedTabVisualIndex is now a PURE-V2 @Trace field on its OWN holder (FeedVisualIndexState), isolated from
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

// 1. FeedTabBridge dual-writes both stores for each shared key.
const bridge = code('shared/src/main/ets/state/FeedTabState.ets');
const bridgeChecks = [
  { name: 'publishKeys -> AppStorage FEED_TAB_KEYS', re: /setAppStorageValue<string>\(\s*StorageKeys\.FEED_TAB_KEYS/ },
  { name: 'publishKeys -> V2 mirror feedTabKeys', re: /connectFeedTab\(\)\.feedTabKeys\s*=/ },
  { name: 'publishSelectedKey -> AppStorage FEED_TAB', re: /setAppStorageValue<string>\(\s*StorageKeys\.FEED_TAB\b/ },
  { name: 'publishSelectedKey -> V2 mirror feedTab', re: /connectFeedTab\(\)\.feedTab\s*=/ },
  { name: 'publishVisualIndex -> V2 FeedVisualIndexState holder (pure-V2, isolated from FeedTabState)', re: /connectFeedVisualIndex\(\)\.value\s*=/ },
];
for (const c of bridgeChecks) {
  if (c.re.test(bridge)) ok(`FeedTabState: ${c.name}`);
  else fail(`FeedTabState: missing ${c.name}`);
}

// 2. The persistence layer applies feed-tab keys through the bridge, not a raw AppStorage write.
const settings = code('shared/src/main/ets/settings/FeedTabSettings.ets');
if (/FeedTabBridge\.publishKeys\(/.test(settings)) ok('FeedTabSettings: apply routes through FeedTabBridge.publishKeys');
else fail('FeedTabSettings: apply no longer routes through FeedTabBridge.publishKeys');

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
