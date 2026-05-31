#!/usr/bin/env node
// Static contract for the NotificationPage State Management V1 -> V2 slice (bulk-remaining lane).
//
//   1. NotificationActionState mirror exists (command + connectNotificationAction).
//   2. Index dual-writes connectNotificationAction().command at its single writer sendNotificationAction.
//   3. NotificationPage is @ComponentV2, V1-decorator-free, navigates via connectNavStack().stack, reads
//      the auth/session/local-data/notification-action mirrors, drives onAuthChanged via a multi-path
//      @Monitor, and keeps NOTIFICATION_UNREAD_COUNT as an imperative AppStorage read/write (never in
//      build) so Index's tab badge stays in sync.
//
// Run: node scripts/test_notification_page_v2_contract.mjs
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

const MIRROR = 'shared/src/main/ets/state/NotificationActionState.ets';
const INDEX = 'entry/src/main/ets/pages/Index.ets';
const PAGE = 'entry/src/main/ets/pages/NotificationPage.ets';

{
  const c = strip(read(MIRROR));
  must(/@ObservedV2\b/.test(c), `${MIRROR}: @ObservedV2`);
  must(/@Trace\s+command\b/.test(c), `${MIRROR}: @Trace command`);
  must(/export function connectNotificationAction\(/.test(c), `${MIRROR}: exports connectNotificationAction()`);
}
{
  const c = strip(read(INDEX));
  must(/connectNotificationAction\(\)\.command\s*=/.test(c), `${INDEX}.sendNotificationAction: dual-writes the mirror`);
  must(/StorageKeys\.NOTIFICATION_ACTION/.test(c), `${INDEX}: still writes the V1 NOTIFICATION_ACTION key`);
}
{
  const c = strip(read(PAGE));
  must(/@ComponentV2\b/.test(c), `${PAGE}: is @ComponentV2`);
  for (const d of ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Consume', '@Provide', '@ObjectLink']) {
    must(!new RegExp(`${d}\\b`).test(c), `${PAGE}: no surviving ${d}`);
  }
  must(/connectNavStack\(\)\.stack/.test(c), `${PAGE}: navigation via connectNavStack().stack`);
  must(/connectAuthIdentity\(\)/.test(c) && /connectAuthCookie\(\)/.test(c) && /connectAuthSessionSignal\(\)/.test(c) && /connectLocalDataSignal\(\)/.test(c) && /connectNotificationAction\(\)/.test(c),
    `${PAGE}: reads the auth/session/local-data/notification-action mirrors`);
  must(/@Monitor\([^)]*authIdentity\.tokenConfigured[^)]*\)/.test(c), `${PAGE}: multi-path @Monitor for onAuthChanged`);
  must(/@Monitor\(\s*['"]notificationAction\.command['"]\s*\)/.test(c), `${PAGE}: @Monitor('notificationAction.command')`);
  must(/@Monitor\(\s*['"]localData\.updatedAt['"]\s*\)/.test(c), `${PAGE}: @Monitor('localData.updatedAt')`);
  // NOTIFICATION_UNREAD_COUNT stays imperative (badge sync), not a reactive decorator
  must(/setAppStorageValue<number>\(\s*StorageKeys\.NOTIFICATION_UNREAD_COUNT/.test(c), `${PAGE}: clears NOTIFICATION_UNREAD_COUNT imperatively`);
  must(/AppStorage\.get<number>\(\s*StorageKeys\.NOTIFICATION_UNREAD_COUNT/.test(c), `${PAGE}: reads NOTIFICATION_UNREAD_COUNT imperatively`);
}

console.log(`\nnotification-page-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
