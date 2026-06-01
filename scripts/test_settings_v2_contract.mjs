#!/usr/bin/env node
// Static contract for the settings-family State Management V1 -> V2 slice (bulk-remaining lane).
//
// Pins the V2 wiring of SettingsPage + NetworkProxySettingsPage and the NetworkProxyState mirror:
//   1. NetworkProxyState declares the 7 @Trace proxy fields; connectNetworkProxy() is exported.
//   2. NetworkProxySettings.apply() (the single AppStorage writer of the NETWORK_PROXY_* keys)
//      dual-writes all 7 mirror fields, keeping AppStorage + mirror in lockstep.
//   3. NetworkProxySettingsPage is @ComponentV2, V1-decorator-free, reads connectNetworkProxy(), and
//      routes its persisted writes through NetworkProxySettings.apply()/save().
//   4. SettingsPage is @ComponentV2, V1-decorator-free, navigates via connectNavStack().stack,
//      reads the reactive settings mirrors, and hydrates its @Local self-toggled prefs in aboutToAppear.
//
// Run: node scripts/test_settings_v2_contract.mjs
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

const MIRROR = 'shared/src/main/ets/state/NetworkProxyState.ets';
const PROXY_SETTINGS = 'shared/src/main/ets/settings/NetworkProxySettings.ets';
const PROXY_PAGE = 'feature/settings/src/main/ets/pages/NetworkProxySettingsPage.ets';
const SETTINGS_PAGE = 'feature/settings/src/main/ets/pages/SettingsPage.ets';
const V1_DECORATORS = ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Consume', '@Provide', '@ObjectLink'];

// 1) mirror shape ------------------------------------------------------------------------------
{
  const code = strip(read(MIRROR));
  must(/@ObservedV2\b/.test(code), `${MIRROR}: @ObservedV2`);
  for (const f of ['mode', 'host', 'port', 'proxyScheme', 'username', 'password', 'exclusionListText']) {
    must(new RegExp(`@Trace\\s+${f}\\b`).test(code), `${MIRROR}: @Trace ${f}`);
  }
  must(/export function connectNetworkProxy\(/.test(code), `${MIRROR}: exports connectNetworkProxy()`);
}

// 2) apply() dual-writes every mirror field ----------------------------------------------------
{
  const code = strip(read(PROXY_SETTINGS));
  must(/connectNetworkProxy\(\)/.test(code), `${PROXY_SETTINGS}: imports/uses connectNetworkProxy()`);
  for (const f of ['mode', 'host', 'port', 'proxyScheme', 'username', 'password', 'exclusionListText']) {
    must(new RegExp(`proxy\\.${f}\\s*=`).test(code), `${PROXY_SETTINGS}.apply: dual-writes proxy.${f}`);
  }
  // V1 AppStorage halves still present (bridge reversible)
  must(/setAppStorageValue<string>\(\s*StorageKeys\.NETWORK_PROXY_MODE/.test(code), `${PROXY_SETTINGS}: still writes NETWORK_PROXY_MODE AppStorage key`);
}

// 3) NetworkProxySettingsPage V2 ---------------------------------------------------------------
{
  const code = strip(read(PROXY_PAGE));
  must(/@ComponentV2\b/.test(code), `${PROXY_PAGE}: is @ComponentV2`);
  for (const d of V1_DECORATORS) must(!new RegExp(`${d}\\b`).test(code), `${PROXY_PAGE}: no surviving ${d}`);
  must(/connectNetworkProxy\(\)/.test(code), `${PROXY_PAGE}: reads connectNetworkProxy() mirror`);
  must(/NetworkProxySettings\.apply\(/.test(code), `${PROXY_PAGE}: routes writes through NetworkProxySettings.apply()`);
}

// 4) SettingsPage V2 ---------------------------------------------------------------------------
{
  const code = strip(read(SETTINGS_PAGE));
  must(/@ComponentV2\b/.test(code), `${SETTINGS_PAGE}: is @ComponentV2`);
  for (const d of V1_DECORATORS) must(!new RegExp(`${d}\\b`).test(code), `${SETTINGS_PAGE}: no surviving ${d}`);
  must(/connectNavStack\(\)\.stack/.test(code), `${SETTINGS_PAGE}: navigation via connectNavStack().stack`);
  for (const c of ['connectApiDomain', 'connectAvatarAppearance', 'connectReplyCardStyle', 'connectTopicDetailReplyButton', 'connectReadingSettings', 'connectNetworkProxy']) {
    must(new RegExp(`${c}\\(`).test(code), `${SETTINGS_PAGE}: reads ${c}() mirror`);
  }
  must(/hydratePreferences\(/.test(code), `${SETTINGS_PAGE}: keeps hydratePreferences() chokepoint`);
  // Durable V2 hydration: the @Local self-toggled prefs are now hydrated from V2 holders, NOT AppStorage.
  must(!/AppStorage\s*\./.test(code), `${SETTINGS_PAGE}: hydration reads V2 holders, no direct AppStorage`);
  for (const c of ['connectAutoDailyCheckin', 'connectMediaSettings', 'connectThemeDisplay', 'connectLanguageState', 'connectReplyDisplay', 'connectMotionReplyAlignment', 'connectHomeTabAutoHide']) {
    must(new RegExp(`${c}\\(`).test(code), `${SETTINGS_PAGE}: hydrates ${c}() mirror`);
  }
}

console.log(`\nsettings-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
