#!/usr/bin/env node

// Notification unread-marker lifecycle contract (time-based).
//
// The row-level 未读 marker derives from ONE truth: created > per-account lastSeen
// (NotificationSeenSettings). The former entry-badge top-N projection raced the async
// badge probe (V2EX /notifications is consume-on-read, so a missed projection could
// never recover) and only worked for the cookie source — this contract pins the
// replacement lifecycle so a refactor cannot silently reintroduce projection bugs:
//   - fresh page-1 refresh: load baseline -> mark created>baseline -> persist lastSeen=now
//   - load-more: extend markers with the SAME session baseline (never reload/persist)
//   - cache restore: retain-only, never derive markers, never fetch
//   - tapping a row clears its marker immediately
//   - missing baseline (first use) marks nothing

import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

function methodBody(sourceText, signature) {
  const start = sourceText.indexOf(signature)
  assert(start >= 0, `missing method: ${signature}`)
  const brace = sourceText.indexOf('{', start)
  assert(brace >= 0, `missing method body for: ${signature}`)
  let depth = 0
  for (let i = brace; i < sourceText.length; i += 1) {
    const ch = sourceText[i]
    if (ch === '{') {
      depth += 1
    } else if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return sourceText.slice(start, i + 1)
      }
    }
  }
  throw new Error(`unterminated method body for: ${signature}`)
}

const page = read('entry/src/main/ets/pages/NotificationPage.ets')
const settings = read('shared/src/main/ets/settings/NotificationSeenSettings.ets')

// --- Invariant 1: cache application never derives markers (retain-only, non-consuming). -----------
const cacheLoad = methodBody(page, 'private loadNotificationCache(')
assert(
  cacheLoad.includes('this.cachedViewedUnreadKeys(result.items)'),
  'NotificationPage cache apply must derive markers via cachedViewedUnreadKeys (content-only)'
)
assert(
  !cacheLoad.includes('timeBasedUnreadKeys') && !cacheLoad.includes('loadLastSeen'),
  'NotificationPage cache apply must not re-derive markers (cached rows were already seen last session)'
)
const cachedKeys = methodBody(page, 'private cachedViewedUnreadKeys(')
assert(
  cachedKeys.includes('this.retainViewedUnreadKeys(items)'),
  'cachedViewedUnreadKeys must only retain in-session markers that still match cached rows'
)
assert(
  !cacheLoad.includes('.loadPage(') && !cacheLoad.includes('getNotificationsWithCookie'),
  'cache restore must not trigger the consume-on-read /notifications list fetch'
)

// --- Invariant 2: opening a notification clears its local row marker before/while routing. --------
const openNotification = methodBody(page, 'private openNotification(item: V2exNotification): void')
assert(
  openNotification.includes('this.clearViewedUnreadKey(item)'),
  'openNotification must clear the local unread marker for the tapped row'
)
assert(
  openNotification.indexOf('this.clearViewedUnreadKey(item)') < openNotification.indexOf('pushPathByName'),
  'openNotification must clear the marker before/while routing, not after'
)
const clearKey = methodBody(page, 'private clearViewedUnreadKey(item: V2exNotification): void')
assert(
  clearKey.includes('this.notificationItemKey(item)') &&
    clearKey.includes('this.viewedUnreadNotificationKeys =') &&
    clearKey.includes('.filter('),
  'clearViewedUnreadKey must remove notificationItemKey(item) by reassigning viewedUnreadNotificationKeys'
)

// --- Invariant 3: fresh page-1 refresh is the only place that loads + persists the baseline. ------
const refreshNotifications = methodBody(page, 'private async refreshNotifications')
assert(
  refreshNotifications.includes('NotificationSeenSettings.loadLastSeen('),
  'refreshNotifications must load the per-account last-seen baseline'
)
assert(
  refreshNotifications.includes('this.timeBasedUnreadKeys(result.items, unreadBaseline)'),
  'refreshNotifications must derive markers from created > baseline (single truth source)'
)
assert(
  refreshNotifications.includes('NotificationSeenSettings.saveLastSeen('),
  'refreshNotifications must persist lastSeen after a successful fresh load (refresh marks everything seen)'
)
assert(
  refreshNotifications.indexOf('this.viewedUnreadNotificationKeys = this.timeBasedUnreadKeys(') <
    refreshNotifications.indexOf('NotificationSeenSettings.saveLastSeen('),
  'markers must be derived from the OLD baseline before the new lastSeen is persisted'
)
assert(
  !refreshNotifications.includes('entryUnreadHint') && !refreshNotifications.includes("source === 'cookie'"),
  'the badge-count projection is retired: no entry hint, no cookie-source gating'
)
assert(
  refreshNotifications.includes('this.notificationUnreadBaselineSeconds = unreadBaseline'),
  'refreshNotifications must stash the session baseline for load-more continuation'
)

// --- Invariant 4: load-more extends markers with the session baseline (no reload, no persist). ----
const loadMore = methodBody(page, 'private loadMoreNotifications(): void')
assert(
  loadMore.includes('this.timeBasedUnreadKeys(result.items, this.notificationUnreadBaselineSeconds)'),
  'load-more must extend markers using the session baseline (deeper unread than one page)'
)
assert(
  !loadMore.includes('loadLastSeen') && !loadMore.includes('saveLastSeen'),
  'load-more must not reload or persist the baseline'
)

// --- Invariant 5: the marker derivation is conservative. -------------------------------------------
const derive = methodBody(page, 'private timeBasedUnreadKeys(')
assert(
  derive.includes('> 0') && derive.includes('> baselineSeconds'),
  'timeBasedUnreadKeys must require created > 0 (parse failures never mark) and created > baseline'
)
const owner = methodBody(page, 'private notificationSeenOwner(): string')
assert(
  owner.includes('username') && !owner.includes('sourceKeyFor'),
  'the last-seen owner key must be the username, not the auth source (cookie<->pat keeps one baseline)'
)

// --- Invariant 6: missing baseline marks nothing (first install never floods markers). ------------
assert(
  settings.includes('MISSING_LAST_SEEN: number = Number.MAX_SAFE_INTEGER'),
  'NotificationSeenSettings.MISSING_LAST_SEEN must be MAX_SAFE_INTEGER so a missing baseline marks nothing'
)
assert(
  /return value > 0 \? value : NotificationSeenSettings\.MISSING_LAST_SEEN/.test(settings),
  'loadLastSeen must map absent/zero values to MISSING_LAST_SEEN'
)

console.log('notification unread marker contract ok (time-based)')
