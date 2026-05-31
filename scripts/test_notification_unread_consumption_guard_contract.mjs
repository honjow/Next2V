#!/usr/bin/env node

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

const index = read('entry/src/main/ets/pages/Index.ets')
const notificationPage = read('entry/src/main/ets/pages/NotificationPage.ets')
const badgeRefresh = methodBody(index, 'private refreshNotificationBadge')
assert(
  !badgeRefresh.includes('.loadPage('),
  'Index.refreshNotificationBadge must not fetch the side-effectful notification list for PAT badge refresh'
)
assert(
  !badgeRefresh.includes('NotificationAuthContext'),
  'Index.refreshNotificationBadge must not construct notification list auth context for background badge refresh'
)
assert(
  badgeRefresh.includes('.unreadCountFromCookie(cookie)'),
  'Index.refreshNotificationBadge may keep only the proven safe cookie homepage badge scrape'
)
assert(
  index.includes('NotificationPage({') &&
    index.includes('refreshKey: this.notificationRefreshKey') &&
    index.includes('currentTab: this.ct'),
  'Index must pass active tab state into NotificationPage so hidden mounted pages cannot list-refresh off-tab'
)

// State Management V2 migration: @Watch('onAuthChanged') -> multi-path @Monitor; the V2 handler
// signature dropped the (_propName) arg.
const authChanged = methodBody(notificationPage, 'onAuthChanged(): void')
assert(
  authChanged.includes('this.deferNotificationRefreshUntilVisible()'),
  'NotificationPage.onAuthChanged must defer auth-triggered notification list refresh while the tab is inactive'
)
assert(
  authChanged.indexOf('this.deferNotificationRefreshUntilVisible()') < authChanged.indexOf('this.loadAuthSnapshot(true)'),
  'NotificationPage.onAuthChanged must check the off-tab visibility guard before force-loading auth/list state'
)

const loadAuthSnapshot = methodBody(notificationPage, 'private loadAuthSnapshot')
assert(
  loadAuthSnapshot.includes('this.shouldLoadNotificationListForCurrentTab(forceNotifications)'),
  'NotificationPage.loadAuthSnapshot must gate notification list loading on active Notifications tab visibility'
)
assert(
  loadAuthSnapshot.includes('this.loadNotificationCache('),
  'NotificationPage.loadAuthSnapshot should still keep non-consuming local cache restore behavior'
)
assert(
  loadAuthSnapshot.indexOf('this.loadNotificationCache(') < loadAuthSnapshot.indexOf('this.loadNotifications(forceNotifications)'),
  'NotificationPage.loadAuthSnapshot should restore local cache before any guarded network list refresh'
)
assert(
  notificationPage.includes('private shouldLoadNotificationListForCurrentTab(forceNotifications: boolean): boolean'),
  'NotificationPage must centralize the active-tab guard for side-effectful notification list reads'
)
const refreshNotifications = methodBody(notificationPage, 'private async refreshNotifications')
assert(
  refreshNotifications.indexOf('this.shouldLoadNotificationListForCurrentTab(force)') >= 0 &&
    refreshNotifications.indexOf('this.shouldLoadNotificationListForCurrentTab(force)') < refreshNotifications.indexOf('this.notificationVm.loadPage('),
  'NotificationPage.refreshNotifications must apply the active-tab guard before the side-effectful notification list loadPage call'
)
assert(
  notificationPage.includes('/notifications list reads mark V2EX unread state as consumed'),
  'NotificationPage must document why notification list reads are gated as side-effectful'
)

console.log('notification unread consumption guard contract ok')
