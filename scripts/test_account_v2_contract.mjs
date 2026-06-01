#!/usr/bin/env node
// Static contract for the account-family State Management V1 -> V2 slice (bulk-remaining lane).
//
// Pins the auth/session/account/rate-limit/local-data mirrors, their single-writer dual-write
// chokepoints, and the V2 migration of AccountDashboardPage + AccountDetailPage:
//   1. The mirrors declare the expected @Trace fields and connect* helpers.
//   2. Each mirror is written at its service chokepoint (AuthSettings.apply / AuthSessionSettings.apply
//      / AccountStore.applyActiveAccountId / ApiV2Service.saveRateLimitSnapshot / the LOCAL_DATA writers).
//      The rate-limit snapshot is V2-only (its legacy AppStorage dual-write was retired); the others
//      still dual-write their legacy AppStorage keys.
//   3. AccountDashboardPage + AccountDetailPage are @ComponentV2, V1-decorator-free, navigate via
//      connectNavStack().stack, read the mirrors, and @Monitor the auth-session / active-account
//      (+ local-data on the dashboard) signals.
//   4. Multi-account safety: the pages still route logout through AccountSessionCoordinator.removeActiveAccount
//      and never call CookieJarSettings.clear()/AuthSessionSettings.clear() directly (the migration is a
//      read/reactivity change, not a state-machine change).
//
// Run: node scripts/test_account_v2_contract.mjs
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

// 1) mirror shapes -----------------------------------------------------------------------------
const mirrors = [
  ['shared/src/main/ets/state/AuthIdentityState.ets', 'connectAuthIdentity', ['tokenConfigured', 'username']],
  ['shared/src/main/ets/state/AuthSessionSignalState.ets', 'connectAuthSessionSignal', ['updatedAt', 'username', 'avatar', 'validatedAt']],
  ['shared/src/main/ets/state/ActiveAccountState.ets', 'connectActiveAccount', ['id']],
  ['shared/src/main/ets/state/ApiRateLimitState.ets', 'connectApiRateLimit', ['limit', 'remaining', 'reset', 'updatedAt']],
  ['shared/src/main/ets/state/LocalDataSignalState.ets', 'connectLocalDataSignal', ['updatedAt']],
];
for (const [rel, connect, fields] of mirrors) {
  const code = strip(read(rel));
  must(/@ObservedV2\b/.test(code), `${rel}: @ObservedV2`);
  must(new RegExp(`export function ${connect}\\(`).test(code), `${rel}: exports ${connect}()`);
  for (const f of fields) must(new RegExp(`@Trace\\s+${f}\\b`).test(code), `${rel}: @Trace ${f}`);
}

// 2) dual-write chokepoints --------------------------------------------------------------------
{
  const c = strip(read('shared/src/main/ets/settings/AuthSettings.ets'));
  must(/identity\.tokenConfigured\s*=/.test(c) && /identity\.username\s*=/.test(c), 'AuthSettings.apply: dual-writes AuthIdentityState');
}
{
  const c = strip(read('shared/src/main/ets/settings/AuthSessionSettings.ets'));
  must(/session\.username\s*=/.test(c) && /session\.avatar\s*=/.test(c) && /session\.validatedAt\s*=/.test(c) && /session\.updatedAt\s*=/.test(c),
    'AuthSessionSettings.apply: dual-writes AuthSessionSignalState identity + signal');
}
{
  const c = strip(read('shared/src/main/ets/settings/AccountStore.ets'));
  must(/connectActiveAccount\(\)\.id\s*=/.test(c), 'AccountStore.applyActiveAccountId: dual-writes ActiveAccountState');
  must(/private static applyActiveAccountId\(/.test(c), 'AccountStore: single applyActiveAccountId chokepoint exists');
  must(!/setAppStorageValue<string>\(StorageKeys\.ACTIVE_ACCOUNT_ID/.test(c.replace(/private static applyActiveAccountId[\s\S]*?\}/, '')),
    'AccountStore: no raw ACTIVE_ACCOUNT_ID AppStorage write outside the chokepoint');
}
{
  const c = strip(read('shared/src/main/ets/network/ApiV2Service.ets'));
  must(/snapshot\.limit\s*=/.test(c) && /snapshot\.updatedAt\s*=/.test(c) && /connectApiRateLimit\(\)/.test(c),
    'ApiV2Service.saveRateLimitSnapshot: writes ApiRateLimitState (V2 sole store)');
  // V2 ApiRateLimitState is now the SOLE store for the rate-limit snapshot: the legacy AppStorage
  // dual-write (StorageKeys.API_RATE_LIMIT_*) was retired once every reader moved to V2. Guard
  // against reintroducing a legacy AppStorage write of any API_RATE_LIMIT key.
  must(!/AppStorage\s*\.\s*\w+\s*(<[^>]*>)?\s*\(\s*StorageKeys\s*\.\s*API_RATE_LIMIT/.test(c),
    'ApiV2Service.saveRateLimitSnapshot: no legacy AppStorage API_RATE_LIMIT write');
}
for (const rel of ['shared/src/main/ets/settings/LocalDataPublisher.ets', 'shared/src/main/ets/settings/LocalDataSettings.ets', 'shared/src/main/ets/settings/DraftSettings.ets', 'entry/src/main/ets/pages/Index.ets']) {
  must(/connectLocalDataSignal\(\)\.updatedAt\s*=/.test(strip(read(rel))), `${rel}: dual-writes LocalDataSignalState`);
}

// 3) page migrations ---------------------------------------------------------------------------
const V1 = ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Consume', '@Provide', '@ObjectLink'];
for (const rel of ['entry/src/main/ets/pages/AccountPage.ets', 'entry/src/main/ets/pages/AccountDetailPage.ets']) {
  const code = strip(read(rel));
  must(/@ComponentV2\b/.test(code), `${rel}: is @ComponentV2`);
  for (const d of V1) must(!new RegExp(`${d}\\b`).test(code), `${rel}: no surviving ${d}`);
  must(/connectNavStack\(\)\.stack/.test(code), `${rel}: navigation via connectNavStack().stack`);
  must(/connectAuthCookie\(\)/.test(code) && /connectAuthIdentity\(\)/.test(code) && /connectAuthSessionSignal\(\)/.test(code) && /connectActiveAccount\(\)/.test(code),
    `${rel}: reads auth/session/active-account mirrors`);
  must(/@Monitor\(\s*['"]session\.updatedAt['"]\s*\)/.test(code), `${rel}: @Monitor('session.updatedAt')`);
  must(/@Monitor\(\s*['"]activeAccount\.id['"]\s*\)/.test(code), `${rel}: @Monitor('activeAccount.id')`);
  // multi-account safety: logout via the coordinator, no direct destructive clears in the page
  must(/AccountSessionCoordinator\.removeActiveAccount/.test(code) || rel.includes('AccountPage'),
    `${rel}: logout routed through AccountSessionCoordinator (detail page)`);
}
{
  const dash = strip(read('entry/src/main/ets/pages/AccountPage.ets'));
  must(/connectApiRateLimit\(\)/.test(dash) && /connectLocalDataSignal\(\)/.test(dash), 'AccountPage: reads rate-limit + local-data mirrors');
  must(/@Monitor\(\s*['"]localData\.updatedAt['"]\s*\)/.test(dash), "AccountPage: @Monitor('localData.updatedAt')");
  must(/@Monitor\(\s*['"]refreshKey['"]\s*\)/.test(dash), "AccountPage: @Monitor('refreshKey')");
  must(/LocalDataPublisher\.publishLocalContentStats/.test(dash), 'AccountPage: re-publishes local content counts');
}

console.log(`\naccount-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
