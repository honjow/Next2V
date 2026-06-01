#!/usr/bin/env node

// Notification unread-marker lifecycle contract.
//
// The row-level 未读 marker is a one-shot runtime visual projection, never stable cached data:
// fetching /notifications is consume-on-read, so a marker is derived only from (a) fresh item-level
// unread flags or (b) the entry badge count captured immediately before the user actively entered
// the tab. This contract mechanically pins the invariants that keep that lifecycle correct so a
// future refactor cannot silently reintroduce the "count projected onto stale cached rows" bug.

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

const occurrences = (sourceText, needle) => sourceText.split(needle).length - 1

const page = read('entry/src/main/ets/pages/NotificationPage.ets')

// --- Invariant 1: cache application must never apply the badge-count fallback. ---------------------
const cacheLoad = methodBody(page, 'private loadNotificationCache(')
assert(
  cacheLoad.includes('this.cachedViewedUnreadKeys(result.items)'),
  'NotificationPage cache apply must derive markers via cachedViewedUnreadKeys (content-only)'
)
assert(
  !cacheLoad.includes('reconcileFreshViewedUnreadKeys'),
  'NotificationPage cache apply must not reuse the fresh-network reconciliation (it can project the count fallback)'
)
assert(
  !cacheLoad.includes('captureNotificationEntryUnreadHint') && !cacheLoad.includes('entryUnreadHint'),
  'NotificationPage cache apply must not capture or pass the entry unread badge hint onto cached rows'
)
const cachedKeys = methodBody(page, 'private cachedViewedUnreadKeys(')
assert(
  !cachedKeys.includes('.slice(0,') && !cachedKeys.includes('unreadHint') && !cachedKeys.includes('unreadCount('),
  'cachedViewedUnreadKeys must not project a count/top-N fallback onto cached ordering'
)
assert(
  cachedKeys.includes('this.retainViewedUnreadKeys(items)'),
  'cachedViewedUnreadKeys must only retain in-session markers that still match cached rows'
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

// --- Invariant 3: the count fallback is gated to the active fresh page-1 network load only. -------
assert(
  occurrences(page, 'this.captureNotificationEntryUnreadHint()') === 1,
  'the entry unread hint must be captured in exactly one place (the fresh page-1 refresh)'
)
const refreshNotifications = methodBody(page, 'private async refreshNotifications')
assert(
  refreshNotifications.includes('this.captureNotificationEntryUnreadHint()') &&
    refreshNotifications.includes('this.reconcileFreshViewedUnreadKeys('),
  'refreshNotifications (active fresh page-1) must capture the entry hint and reconcile fresh markers'
)
assert(
  refreshNotifications.includes("result.source === 'cookie' ? entryUnreadHint : 0"),
  'the entry hint must only feed cookie/Web-session page-1 results (the v2 API carries item-level unread)'
)
assert(
  refreshNotifications.indexOf('this.captureNotificationEntryUnreadHint()') <
    refreshNotifications.indexOf('await this.notificationVm.loadPage('),
  'the entry hint must be captured before the consume-on-read /notifications fetch clears the badge'
)
const loadMore = methodBody(page, 'private loadMoreNotifications(): void')
assert(
  !loadMore.includes('reconcileFreshViewedUnreadKeys') &&
    !loadMore.includes('captureNotificationEntryUnreadHint') &&
    !loadMore.includes('viewedUnreadNotificationKeys ='),
  'load-more must not project or re-derive page-1 unread markers'
)
const captureHint = methodBody(page, 'private captureNotificationEntryUnreadHint(): number')
assert(
  captureHint.includes('Math.max(0, this.notificationUnread.count)') &&
    !captureHint.includes('this.notificationEntryUnread'),
  'captureNotificationEntryUnreadHint must read the badge as a one-shot snapshot, not accumulate a running max'
)

// --- Invariant 4: a clean fresh refresh (no item unread, no hint) clears stale local keys. --------
const reconcile = methodBody(page, 'private reconcileFreshViewedUnreadKeys(')
assert(
  !reconcile.includes('retainViewedUnreadKeys'),
  'fresh reconciliation must not retain stale fallback keys after a successful refresh'
)
assert(
  reconcile.includes('this.notificationVm.unreadCount(items) > 0') &&
    reconcile.includes('this.unreadKeysFromItems(items)'),
  'fresh reconciliation must derive markers from real item-level unread flags first'
)
assert(
  reconcile.includes('entryUnreadHint > 0') && reconcile.includes('.slice(0, Math.min(entryUnreadHint, items.length))'),
  'fresh reconciliation must project the one-shot entry hint onto the fresh page-1 rows'
)
const reconcileTrimmed = reconcile.replace(/\s+/g, ' ')
assert(
  reconcileTrimmed.endsWith('return [] }'),
  'fresh reconciliation must clear local keys (return []) when there is no unread truth and no hint'
)

// --- Invariant 5 (defense in depth): cache restore stays non-consuming (no /notifications fetch). -
assert(
  !cacheLoad.includes('.loadPage(') && !cacheLoad.includes('getNotificationsWithCookie'),
  'cache restore must not trigger the consume-on-read /notifications list fetch'
)

console.log('notification unread marker contract ok')
