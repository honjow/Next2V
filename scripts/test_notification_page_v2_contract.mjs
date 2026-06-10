#!/usr/bin/env node
// Static contract for the NotificationPage State Management V1 -> V2 slice (bulk-remaining lane).
//
//   1. The NotificationActionState command bus is fully retired (its only producer was the title-bar
//      refresh button, removed in favour of pull-to-refresh) — neither the holder, nor an Index
//      writer, nor a page reader may come back.
//   2. NotificationPage is @ComponentV2, V1-decorator-free, navigates via connectNavStack().stack,
//      reads the auth/session/local-data mirrors, drives onAuthChanged via a multi-path @Monitor,
//      clears the tab badge through publishNotificationUnreadCount, and derives row-level unread
//      from the NotificationSeenSettings per-account last-seen baseline.
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

const INDEX = 'entry/src/main/ets/pages/Index.ets';
const PAGE = 'entry/src/main/ets/pages/NotificationPage.ets';
const SHARED_BARREL = 'shared/src/main/ets/Index.ets';

{
  const c = strip(read(INDEX));
  must(!/connectNotificationAction\(\)/.test(c), `${INDEX}: notificationAction command bus retired (title-bar refresh removed)`);
  must(!/notificationTitleMenu/.test(c), `${INDEX}: no notification title-bar menu`);
  must(!/AppStorage\.(set|setOrCreate)<[^>]*>\(\s*StorageKeys\.NOTIFICATION_ACTION/.test(c), `${INDEX}: no legacy AppStorage NOTIFICATION_ACTION dual-write (V2-only)`);
}
{
  const c = strip(read(SHARED_BARREL));
  must(!/NotificationActionState/.test(c), `${SHARED_BARREL}: NotificationActionState holder is retired (not exported)`);
}
{
  const c = strip(read(PAGE));
  must(/@ComponentV2\b/.test(c), `${PAGE}: is @ComponentV2`);
  for (const d of ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Consume', '@Provide', '@ObjectLink']) {
    must(!new RegExp(`${d}\\b`).test(c), `${PAGE}: no surviving ${d}`);
  }
  must(/connectNavStack\(\)\.stack/.test(c), `${PAGE}: navigation via connectNavStack().stack`);
  must(/connectAuthIdentity\(\)/.test(c) && /connectAuthCookie\(\)/.test(c) && /connectAuthSessionSignal\(\)/.test(c) && /connectLocalDataSignal\(\)/.test(c),
    `${PAGE}: reads the auth/session/local-data mirrors`);
  must(/@Monitor\([^)]*authIdentity\.tokenConfigured[^)]*\)/.test(c), `${PAGE}: multi-path @Monitor for onAuthChanged`);
  // The title-bar refresh button (notificationAction command bus) was removed — pull-to-refresh
  // covers reload — so the page must no longer read that mirror.
  must(!/connectNotificationAction\(\)/.test(c), `${PAGE}: notificationAction command bus retired (no title-bar refresh)`);
  must(/@Monitor\(\s*['"]localData\.updatedAt['"]\s*\)/.test(c), `${PAGE}: @Monitor('localData.updatedAt')`);
  // The tab badge clear stays imperative through the publishNotificationUnreadCount write-through
  // helper; row-level unread derives from the NotificationSeenSettings last-seen baseline.
  must(/publishNotificationUnreadCount\(/.test(c), `${PAGE}: clears the unread count via the write-through helper`);
  must(/NotificationSeenSettings\.loadLastSeen\(/.test(c), `${PAGE}: row unread derives from the per-account last-seen baseline`);
  must(!/AppStorage\.get<[^>]*>\(\s*StorageKeys\.NOTIFICATION_UNREAD_COUNT/.test(c), `${PAGE}: no legacy NOTIFICATION_UNREAD_COUNT AppStorage.get (V2-only)`);
  const mirror = strip(read('shared/src/main/ets/state/NotificationUnreadState.ets'));
  must(/connectNotificationUnread\(\)\.count\s*=/.test(mirror), `NotificationUnreadState: publishNotificationUnreadCount writes the V2 mirror`);
  must(!/AppStorage\.(set|setOrCreate)<[^>]*>\(\s*StorageKeys\.NOTIFICATION_UNREAD_COUNT/.test(mirror), `NotificationUnreadState: no legacy NOTIFICATION_UNREAD_COUNT AppStorage dual-write (V2-only)`);
}

console.log(`\nnotification-page-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
