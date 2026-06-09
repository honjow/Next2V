#!/usr/bin/env node
// Focused static contract for the local node-ignore feature (ignored-nodes slice).
//
// Node-ignore is a DEVICE-GLOBAL, login-independent client-side feed filter (the app's own preference,
// NOT the V2EX account-scoped server ignore list). This check pins the invariants that the broad
// V1-decorator inventory contract can't express:
//
//   1. IgnoredNodesState.ets is an @ObservedV2 mirror with a @Trace names field + connect helper, no V1.
//   2. IgnoredNodesSettings.ets is a plain class (no V1 decorators, no Date.now/random churn) exposing
//      the load / isIgnored / setIgnored / toggle / nameSet surface, persisting a JSON string array.
//   3. ApiService.applyActiveBlockedTopicFilter takes the filterIgnoredNodes flag, reads the holder, and
//      filters by topic.node.name — AND the node-topics call site passes `false` so an ignored node's
//      OWN page is never emptied (mirrors V2EX: ignored nodes stay readable on their own page).
//   4. NodeTopicAppbarState carries a @Trace ignored flag + publishNodeTopicIgnored single-writer helper.
//   5. SettingsBootstrap restores the list on startup AND on backup-reapply.
//   6. All 7 locales define the 4 user-facing strings.
//
// Run: node scripts/test_ignored_nodes_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');

const V1_STATE_DECORATORS = [
  /@State\b/, /@Prop\b/, /@Link\b/, /@Watch\b/, /@StorageLink\b/, /@StorageProp\b/,
  /@Provide\b/, /@Consume\b/, /@ObjectLink\b/, /@LocalStorageLink\b/, /@LocalStorageProp\b/,
];
const CHURN = [/Date\.now\s*\(/, /Math\.random\s*\(/];

const read = (rel) => readFileSync(join(repo, rel), 'utf8');
const stripComments = (t) => t.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

let failures = 0;
const fail = (msg) => { console.error(`FAIL ${msg}`); failures++; };
const ok = (msg) => console.log(`ok   ${msg}`);

// 1. IgnoredNodesState mirror shape.
{
  const before = failures;
  const src = stripComments(read('shared/src/main/ets/state/IgnoredNodesState.ets'));
  if (!/@ObservedV2[\s\S]*?class\s+IgnoredNodesState\b/.test(src)) fail('IgnoredNodesState must be @ObservedV2');
  if (!/@Trace\s+names\b/.test(src)) fail('IgnoredNodesState.names must be @Trace');
  if (!/export function connectIgnoredNodes\b/.test(src)) fail('missing connectIgnoredNodes helper');
  for (const d of V1_STATE_DECORATORS) if (d.test(src)) fail(`IgnoredNodesState: forbidden V1 decorator ${d}`);
  if (failures === before) ok('IgnoredNodesState (@ObservedV2 + @Trace names + connect helper, no V1)');
}

// 2. IgnoredNodesSettings surface + cleanliness.
{
  const before = failures;
  const raw = read('shared/src/main/ets/settings/IgnoredNodesSettings.ets');
  const src = stripComments(raw);
  for (const d of V1_STATE_DECORATORS) if (d.test(src)) fail(`IgnoredNodesSettings: forbidden V1 decorator ${d}`);
  for (const c of CHURN) if (c.test(src)) fail(`IgnoredNodesSettings: key-churn token ${c}`);
  for (const fn of ['load', 'isIgnored', 'setIgnored', 'toggle', 'nameSet', 'current']) {
    if (!new RegExp(`static\\s+(?:async\\s+)?${fn}\\b`).test(src)) fail(`IgnoredNodesSettings: missing ${fn}()`);
  }
  if (!/readJsonArray<string>/.test(src)) fail('IgnoredNodesSettings: expected readJsonArray<string> load');
  if (!/writeJsonValue\b/.test(src)) fail('IgnoredNodesSettings: expected writeJsonValue persist');
  if (failures === before) ok('IgnoredNodesSettings (clean class, full surface, JSON string-array persistence)');
}

// 3. Feed filter integration.
{
  const before = failures;
  const src = stripComments(read('shared/src/main/ets/network/ApiService.ets'));
  if (!/connectIgnoredNodes\s*\(\)/.test(src)) fail('ApiService: applyActiveBlockedTopicFilter must read connectIgnoredNodes()');
  if (!/applyActiveBlockedTopicFilter\s*\([\s\S]*?filterIgnoredNodes\s*:\s*boolean\s*=\s*true/.test(src)) {
    fail('ApiService: applyActiveBlockedTopicFilter must take filterIgnoredNodes: boolean = true');
  }
  if (!/topic\.node\.name/.test(src)) fail('ApiService: node filter must match topic.node.name');
  // The node-topics path must opt OUT of node filtering (its own page is never emptied).
  if (!/normalizeNodeTopics\([\s\S]*?\),\s*\n\s*(?:\/\/[^\n]*\n\s*)*false,/.test(src)) {
    fail('ApiService: node-topics call site must pass filterIgnoredNodes=false (node page not self-filtered)');
  }
  if (failures === before) ok('ApiService (filterIgnoredNodes flag, node.name filter, node page opts out)');
}

// 4. Appbar reporting channel.
{
  const before = failures;
  const src = stripComments(read('shared/src/main/ets/state/NodeTopicAppbarState.ets'));
  if (!/@Trace\s+ignored\b/.test(src)) fail('NodeTopicAppbarState: ignored must be @Trace');
  if (!/export function publishNodeTopicIgnored\b/.test(src)) fail('missing publishNodeTopicIgnored single-writer helper');
  if (failures === before) ok('NodeTopicAppbarState (@Trace ignored + publishNodeTopicIgnored)');
}

// 5. Bootstrap wiring (startup + backup reapply).
{
  const before = failures;
  const src = stripComments(read('shared/src/main/ets/settings/SettingsBootstrap.ets'));
  const calls = src.match(/restoreIgnoredNodes\s*\(/g) || [];
  if (calls.length < 3) fail(`SettingsBootstrap: expected restoreIgnoredNodes in loadAll + reapplyFromStore + its definition (found ${calls.length})`);
  if (!/IgnoredNodesSettings\.load\b/.test(src)) fail('SettingsBootstrap: restoreIgnoredNodes must call IgnoredNodesSettings.load');
  if (failures === before) ok('SettingsBootstrap (restoreIgnoredNodes wired into loadAll + reapplyFromStore)');
}

// 6. i18n coverage across all locales.
{
  const before = failures;
  const locales = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR'];
  const keys = ['topic_action_ignore_node', 'topic_action_unignore_node', 'node_ignored_toast', 'node_unignored_toast'];
  for (const loc of locales) {
    const src = read(`entry/src/main/resources/${loc}/element/string.json`);
    for (const k of keys) {
      if (!new RegExp(`"name":\\s*"${k}"`).test(src)) fail(`i18n: ${loc} missing key ${k}`);
    }
  }
  if (failures === before) ok('i18n (4 ignore-node strings present in all 7 locales)');
}

// 7. Server-sync layer — the real web↔app sync (local list is only an optimistic cache).
{
  const before = failures;
  const parser = stripComments(read('shared/src/main/ets/parser/V2exCollectionActionParser.ets'));
  if (!/extractNodeIgnoreToggle\b/.test(parser)) fail('parser: missing extractNodeIgnoreToggle');
  // Source escapes slashes for the ETS regex (unignore\/node), so allow an optional backslash.
  if (!/unignore[\\/]+node/.test(parser)) fail('parser: must handle the unignore/node (ignored) state');
  if (!/currentlyOn:\s*true/.test(parser) || !/currentlyOn:\s*false/.test(parser)) {
    fail('parser: must distinguish ignored (true) vs not-ignored (false)');
  }
  const api = stripComments(read('shared/src/main/ets/network/ApiService.ets'));
  for (const fn of ['getNodeIgnoreToggleActionWithCookie', 'executeNodeIgnoreToggleWithCookie', 'toggleNodeIgnoreWithCookie']) {
    if (!new RegExp(`\\b${fn}\\b`).test(api)) fail(`ApiService: missing ${fn}`);
  }
  const page = stripComments(read('feature/node/src/main/ets/pages/NodeTopicPage.ets'));
  if (!/toggleNodeIgnoreWithCookie\b/.test(page)) fail('NodeTopicPage: toggle must call toggleNodeIgnoreWithCookie (server write)');
  if (!/getNodeIgnoreToggleActionWithCookie\b/.test(page)) fail('NodeTopicPage: load must read server state via getNodeIgnoreToggleActionWithCookie');
  if (!/IgnoredNodesSettings\.setIgnored\b/.test(page)) fail('NodeTopicPage: must mirror the server result into the optimistic cache via setIgnored');
  if (failures === before) ok('server sync (parser + ApiService trio + NodeTopicPage server-first toggle mirroring cache)');
}

if (failures > 0) {
  console.error(`\n${failures} failure(s)`);
  process.exit(1);
}
console.log('\nignored-nodes-v2 contract: 0 failure(s)');
