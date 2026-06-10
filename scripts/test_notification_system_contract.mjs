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

const networkTypes = read('shared/src/main/ets/network/NetworkTypes.ets')
for (const field of [
  'reply_content?: string',
  'reply_content_rendered?: string',
  'delete_id?: number',
  'delete_once?: string',
]) {
  assert(networkTypes.includes(field), `V2exNotification missing ${field}`)
}

const parser = read('shared/src/main/ets/parser/V2exNotificationParser.ets')
for (const token of [
  'extractPayloadHtml(cell)',
  'extractDeleteAction(cell)',
  'reply_content: replyContent',
  'reply_content_rendered: replyContentRendered',
  'payload: replyContent',
  'payload_rendered: replyContentRendered',
  'delete_id: deleteAction.id',
  'delete_once: deleteAction.once',
  'extractMemberAvatar(cell, username)',
  'deleteNotification\\s*\\(',
  '\\bpayload\\b',
  '.replace(/<img\\b[^>]*>/gi, ` ${V2exNotificationParser.getImagePlaceholder()} `)',
  'const username = labelUsername && labelUsername !== V2exNotificationParser.getImagePlaceholder() ? labelUsername : hrefUsername',
]) {
  assert(parser.includes(token), `notification parser contract missing ${token}`)
}

const apiService = read('shared/src/main/ets/network/ApiService.ets')
for (const token of [
  'async getNotificationUnreadCountWithCookie(cookie: string): Promise<number>',
  "this.getCookieHtml('/', cookie)",
  'V2exSessionParser.extractUnreadNotificationCount(html)',
  'async deleteNotificationWithCookie(',
  'verifyPage: number = 1',
  "`/delete/notification/${notificationId}?once=${encodeURIComponent(once)}`",
  'private async deleteNotificationWithCookieRequest(',
  'private async latestNotificationDeleteAction(',
  '[NotificationDelete] cookie refreshed_action',
  'http.RequestMethod.POST',
  "'X-Requested-With': 'XMLHttpRequest'",
  '[NotificationDelete] cookie start',
  '[NotificationDelete] cookie request_done',
  '[NotificationDelete] cookie verified',
  'safeOperationErrorMessage(error: Error): string',
  "once=<redacted>",
  'if (await this.isNotificationDeletedFromCookiePage(cookie, action.id, safeVerifyPage))',
  'private async isNotificationDeletedFromCookiePage(',
  'const latest = await this.getNotificationsWithCookie(cookie, page)',
  'item.id === notificationId || item.delete_id === notificationId',
  'throw ApiErrors.notificationDeleteNotApplied()',
  "'/notifications'",
]) {
  assert(apiService.includes(token), `ApiService cookie delete contract missing ${token}`)
}

const vm = read('entry/src/main/ets/viewmodel/NotificationCenterViewModel.ets')
assert(!vm.includes("'已读'"), 'NotificationCenterViewModel should not emit a visible read tag')
const sourceMethodMatch = vm.match(/private source\(context: NotificationAuthContext\): NotificationSource \{([\s\S]*?)\n  \}/)
assert(sourceMethodMatch, 'NotificationCenterViewModel missing source selector')
assert(
  sourceMethodMatch[1].indexOf("return 'cookie'") >= 0 &&
    sourceMethodMatch[1].indexOf("return 'cookie'") < sourceMethodMatch[1].indexOf("return 'pat'"),
  'NotificationCenterViewModel must prefer Web-session notifications over stale API v2 notifications when both auth sources exist'
)
for (const token of [
  'canDeleteItem(context: NotificationAuthContext, item: V2exNotification)',
  'sourceKeyFor(context: NotificationAuthContext): NotificationSource',
  'async unreadCountFromCookie(cookie: string): Promise<number>',
  'webDeleteId(item: V2exNotification): number',
  'webDeleteOnce(item: V2exNotification): string',
  'body: this.displayBody(kindTag, body, compactTopicThanks)',
  'replyContent: this.displayReplyContent(kindTag, item, compactTopicThanks)',
  'replyRenderedContent: this.displayReplyRenderedContent(kindTag, item, compactTopicThanks)',
  'if (kindTag === KIND_FAVORITE || compactTopicThanks)',
  'private replyRenderedContent(item: V2exNotification): string',
  'private firstReadableContent(candidates: (string | undefined)[]): string',
  'private readableNotificationContent(raw: string): string',
  ".replace(/<img\\b[^>]*>/gi, ' [IMG] ')",
  'return unread ? READ_TAG_UNREAD : ' + "''",
  'return read ? ' + "''" + ' : READ_TAG_UNREAD',
]) {
  assert(vm.includes(token), `NotificationCenterViewModel contract missing ${token}`)
}

const page = read('entry/src/main/ets/pages/NotificationPage.ets')
assert(!page.includes('NotificationSummaryCard({'), 'NotificationPage must not render the old summary card as the first list item')
const refreshKeyHandlerMatch = page.match(/onRefreshKeyChanged\(\): void \{([\s\S]*?)\n  \}/)
assert(refreshKeyHandlerMatch, 'NotificationPage missing onRefreshKeyChanged handler')
assert(
  !refreshKeyHandlerMatch[1].includes('resetNotificationState()'),
  'NotificationPage must not blank the notification list on tab re-entry refresh'
)
assert(
  refreshKeyHandlerMatch[1].includes('loadAuthSnapshot(true)'),
  'NotificationPage tab re-entry refresh must still request a forced notification refresh'
)
const authHandlerMatch = page.match(/onAuthChanged\(\): void \{([\s\S]*?)\n  \}/)
assert(authHandlerMatch, 'NotificationPage missing onAuthChanged handler')
assert(
  authHandlerMatch[1].includes('currentNotificationIdentityKey()') &&
    !authHandlerMatch[1].includes('resetNotificationState()'),
  'NotificationPage auth watcher must compare effective identity and not unconditionally reset on AUTH_SESSION_UPDATED_AT'
)
const localDataHandlerMatch = page.match(/onLocalDataUpdated\(\): void \{([\s\S]*?)\n  \}/)
assert(localDataHandlerMatch, 'NotificationPage missing onLocalDataUpdated handler')
assert(
  !localDataHandlerMatch[1].includes('resetNotificationState()'),
  'NotificationPage must not blank the notification list on local data updates'
)
assert(
  !localDataHandlerMatch[1].includes('loadAuthSnapshot(true)') &&
    !localDataHandlerMatch[1].includes('loadNotifications('),
  'NotificationPage must not turn broad LOCAL_DATA_UPDATED_AT into a notification network refresh'
)
assert(
  page.includes('@Local private notificationInitialSettled: boolean = false') &&
    page.includes('@Local private isNotificationAuthLoading: boolean = false') &&
    page.includes('private shouldShowNotificationInitialLoading(): boolean') &&
    page.includes('private shouldShowNotificationEmptyState(): boolean') &&
    page.includes('this.shouldShowNotificationEmptyState()'),
  'NotificationPage must gate 暂无通知 behind an explicit settled initial lifecycle state'
)
assert(
  page.includes('private notificationIdentityKey: string =') &&
    page.includes('private currentNotificationIdentityKey(') &&
    page.includes('if (this.notificationIdentityKey && nextIdentity !== this.notificationIdentityKey)') &&
    page.includes('this.resetNotificationState()') &&
    page.includes('this.notificationIdentityKey = nextIdentity'),
  'NotificationPage must hard reset only after effective notification owner/source changes'
)
assert(
  page.includes('this.notificationInitialSettled = true') &&
    page.includes('if (this.notifications.length > 0 && !this.notificationLoadedFromCache)'),
  'NotificationPage must preserve rows during soft refresh and prevent cache from overwriting fresh rows'
)
const loadAuthSnapshotStart = page.indexOf('private loadAuthSnapshot(forceNotifications: boolean = false): void {')
const refreshVisibleStart = page.indexOf('private refreshVisibleNotificationsIfNeeded(): void {')
assert(loadAuthSnapshotStart >= 0 && refreshVisibleStart > loadAuthSnapshotStart, 'NotificationPage missing loadAuthSnapshot body')
const loadAuthSnapshotBody = page.slice(loadAuthSnapshotStart, refreshVisibleStart)
// Reads of /notifications consume unread state, so the authenticated list refresh must be gated
// behind the active-tab check (commit ee2a53a: "guard unread list refresh timing"). The cache load
// still runs first but cannot clobber a fresh refresh — that is enforced by the in-flight / fresh-rows
// guards asserted further below — so the historical "refresh-before-cache call order" is no longer the
// mechanism; the gated refresh is.
assert(
  loadAuthSnapshotBody.indexOf('this.loadNotificationCache(snapshot.username || this.session.username)') >= 0 &&
    loadAuthSnapshotBody.indexOf('if (this.shouldLoadNotificationListForCurrentTab(forceNotifications)) {') >= 0 &&
    loadAuthSnapshotBody.indexOf('this.loadNotifications(forceNotifications)') >
      loadAuthSnapshotBody.indexOf('if (this.shouldLoadNotificationListForCurrentTab(forceNotifications)) {'),
  'NotificationPage must gate the authenticated list refresh behind the active-tab check (consume-on-read safety)'
)
assert(
  page.includes('tokenConfigured: this.authIdentity.tokenConfigured || token.length > 0'),
  'NotificationPage auth context must treat the freshly loaded token as configured before StorageLink propagation'
)
const resetNotificationStateMatch = page.match(/private resetNotificationState\(\): void \{([\s\S]*?)\n  \}/)
assert(resetNotificationStateMatch, 'NotificationPage missing resetNotificationState body')
assert(
  resetNotificationStateMatch[1].includes("this.authToken = ''"),
  'NotificationPage auth reset must clear the local token so stale PAT auth cannot refresh before snapshot reload'
)
assert(
  page.includes('private notificationRefreshRequestId: number = 0') &&
    page.includes('private notificationCacheRequestId: number = 0'),
  'NotificationPage must keep request ids for notification refresh/cache ordering'
)
assert(
  page.includes('private pendingNotificationForceRefresh: boolean = false') &&
    page.includes('this.pendingNotificationForceRefresh = true') &&
    page.includes('private replayPendingNotificationForceRefresh(): void') &&
    page.includes('this.loadAuthSnapshot(true)'),
  'NotificationPage must replay a forced tab refresh that arrived during the hidden first notification load'
)
assert(
  page.includes('const requestId = ++this.notificationRefreshRequestId') &&
    page.includes('this.notificationCacheRequestId++'),
  'NotificationPage refresh must invalidate older notification cache loads'
)
assert(
  page.includes('const refreshInFlightAtStart = this.isNotificationLoading') &&
    page.includes('if (refreshInFlightAtStart || this.isNotificationLoading)'),
  'NotificationPage cache load must not apply while an authenticated refresh is in flight'
)
assert(
  page.includes('if (this.notifications.length > 0 && !this.notificationLoadedFromCache)'),
  'NotificationPage cache load must not overwrite already loaded fresh notifications'
)
const deleteItemMatch = page.match(/private deleteNotificationItem\(item: V2exNotification\): void \{([\s\S]*?)\n  \}/)
assert(deleteItemMatch, 'NotificationPage missing deleteNotificationItem body')
assert(
  deleteItemMatch[1].indexOf('this.deleteNotificationWithCookie(item)') >= 0 &&
    deleteItemMatch[1].indexOf('this.deleteNotificationWithCookie(item)') < deleteItemMatch[1].indexOf('this.deleteNotification(item)'),
  'NotificationPage must delete Web-session notification rows with the Web delete action before falling back to PAT delete'
)
for (const forbidden of [
  'NotificationDeleteConfirmDialog',
  'CustomDialogController',
  'fakeDeleteRequestForTest',
  'DELETE_REQUEST_TEST_DELAY_MS',
]) {
  assert(!page.includes(forbidden), `NotificationPage must not retain temporary/custom delete confirmation code: ${forbidden}`)
}
for (const token of [
  'this.notificationVm.canDeleteItem(this.notificationAuthContext(), item)',
  'const verifyPage = this.notificationPageForItem(item)',
  'this.api.deleteNotificationWithCookie(cookie, notificationId, once, verifyPage)',
  'this.getUIContext().showAlertDialog({',
  "value: $r('app.string.common_delete')",
  'private notificationPageForItem(item: V2exNotification): number',
  'private deleteNotificationInBackground(',
  'private retryDeleteNotificationRequest(request: () => Promise<void>, attempt: number): Promise<void>',
  'if (attempt >= 2)',
  'private deleteRetryDelayMs(attempt: number): number',
  'private restoreNotificationAfterDeleteFailure(item: V2exNotification, originalIndex: number): void',
  'this.pendingNotificationDeletes.add(notificationId)',
  'this.restoreNotificationAfterDeleteFailure(item, originalIndex)',
  'private publishUnreadCount(): void',
  'this.publishUnreadCount()',
  '@Local private viewedUnreadNotificationKeys: string[] = []',
  'NotificationSeenSettings.loadLastSeen(',
  'this.timeBasedUnreadKeys(result.items, unreadBaseline)',
  'NotificationSeenSettings.saveLastSeen(',
  'this.notificationsWithoutReadState(result.items)',
  'private timeBasedUnreadKeys(',
  'private notificationSeenOwner(): string',
  'private notificationWithoutReadState(item: V2exNotification): V2exNotification',
  'publishNotificationUnreadCount(0)',
  'replyContent: display.replyContent',
  'replyRenderedContent: display.replyRenderedContent',
]) {
  assert(page.includes(token), `NotificationPage contract missing ${token}`)
}

const components = read('entry/src/main/ets/components/NotificationPageComponents.ets')
assert(!components.includes('NotificationSummaryCard'), 'old NotificationSummaryCard component should be removed')
for (const token of [
  'Avatar({',
  'MarkdownContent({',
  '@Param replyContent: string =',
  '@Param replyRenderedContent: string =',
  'source: this.replyPreviewSource()',
  'topMargin: 0',
  '@Param memberName: string =',
  '@Param avatarUrl: string =',
  'private replyPreviewSource(): string',
  'SymbolGlyph($r',
]) {
  assert(components.includes(token), `Notification UI component contract missing ${token}`)
}
for (const forbidden of [
  'Image(this.replyImageUrl)',
  '@Prop replyImageUrl',
  '.width(120)',
  '.height(120)',
]) {
  assert(!components.includes(forbidden), `Notification UI must not keep custom fixed image preview: ${forbidden}`)
}

const mainTabIcon = read('entry/src/main/ets/components/MainTabIcon.ets')
const mainTabBaseIconBlock = mainTabIcon.slice(0, mainTabIcon.indexOf('if (this.badgeCount > 0)'))
for (const token of [
  '@Param badgeCount: number = 0',
  'if (this.badgeCount > 0)',
  'private badgeText(): string',
  "'99+'",
  'Stack({ alignContent: Alignment.Center })',
  'Stack({ alignContent: Alignment.TopEnd })',
  'SymbolGlyph ignored translate-based compensation on',
  'const MAIN_TAB_SYMBOL_GLYPH_LAYOUT_OFFSET_VP = 3',
  'Row() {',
  'Blank()',
  '.width(MAIN_TAB_SYMBOL_GLYPH_LAYOUT_OFFSET_VP)',
  '.justifyContent(FlexAlign.Start)',
  '.alignItems(VerticalAlign.Center)',
]) {
  assert(mainTabIcon.includes(token), `MainTabIcon badge contract missing ${token}`)
}
assert(
  mainTabIcon.indexOf('.justifyContent(FlexAlign.Start)') <
    mainTabIcon.indexOf('if (this.badgeCount > 0)'),
  'MainTabIcon must apply real layout compensation to the base SymbolGlyph owner before the badge overlay'
)
assert(
  !mainTabIcon.includes('MAIN_TAB_SYMBOL_GLYPH_CENTER_OFFSET_X') &&
    !mainTabIcon.includes('.translate({ x: MAIN_TAB_SYMBOL_GLYPH_CENTER_OFFSET_X })'),
  'MainTabIcon must not rely on translate-only SymbolGlyph compensation; device QA showed it is ignored/not observable'
)
assert(
  !/Row\s*\(\s*\)\s*\{\s*SymbolGlyph\s*\(/s.test(mainTabIcon),
  'MainTabIcon must not use the start-only Row pattern; QA3 showed it over-corrects 9px left'
)
assert(
  !mainTabBaseIconBlock.includes('.translate('),
  'MainTabIcon must not apply SymbolGlyph translate-only compensation; it is not observable in real layout dumps'
)
assert(
  !/Stack\s*\(\s*\{\s*alignContent:\s*Alignment\.TopEnd\s*\}\s*\)\s*\{\s*SymbolGlyph\s*\(/s.test(mainTabIcon),
  'MainTabIcon must not align the base SymbolGlyph with a top-end badge Stack'
)
assert(
  /Stack\s*\(\s*\{\s*alignContent:\s*Alignment\.Center\s*\}\s*\)\s*\{\s*Row\s*\(\s*\)\s*\{\s*Blank\s*\(\s*\)\s*\.width\(MAIN_TAB_SYMBOL_GLYPH_LAYOUT_OFFSET_VP\)\s*SymbolGlyph\s*\(/s.test(mainTabIcon),
  'MainTabIcon base SymbolGlyph must be placed by a real-layout 3vp spacer inside the fixed icon area'
)
assert(
  /Row\s*\(\s*\)\s*\{[\s\S]*Blank\s*\(\s*\)\s*\.width\(MAIN_TAB_SYMBOL_GLYPH_LAYOUT_OFFSET_VP\)[\s\S]*SymbolGlyph\s*\([\s\S]*\.fontSize\(ThemeConstants\.INDICATOR_SIZE - 6\)[\s\S]*\}\s*\.width\(ThemeConstants\.INDICATOR_SIZE\)\s*\.height\(ThemeConstants\.INDICATOR_SIZE - 2\)\s*\.justifyContent\(FlexAlign\.Start\)\s*\.alignItems\(VerticalAlign\.Center\)/s.test(mainTabIcon),
  'MainTabIcon must offset the 22vp SymbolGlyph with a real 3vp leading spacer in the unchanged 28vp icon area'
)
assert(
  /if\s*\(this\.badgeCount > 0\)\s*\{\s*Stack\s*\(\s*\{\s*alignContent:\s*Alignment\.TopEnd\s*\}\s*\)\s*\{\s*Text\(this\.badgeText\(\)\)/s.test(mainTabIcon),
  'MainTabIcon badge must use its own top-end overlay without shifting the base icon'
)

const index = read('entry/src/main/ets/pages/Index.ets')
for (const token of [
  'private notificationUnread: NotificationUnreadState = connectNotificationUnread()',
  'private refreshNotificationBadge(): void',
  'private canApplyNotificationBadgeRequest(requestId: number): boolean',
  'this.notificationBadgeRequestId++',
  'this.refreshNotificationBadge()',
  '.unreadCountFromCookie(cookie)',
  'badgeCount: idx === 2 ? this.notificationUnread.count : 0',
]) {
  assert(index.includes(token), `Index notification badge contract missing ${token}`)
}
const accountTabHandler = index.match(/if \(i === 3\) \{([\s\S]*?)\n        \}/)
assert(accountTabHandler, 'Index account tab handler missing')
assert(
  !accountTabHandler[1].includes('refreshLocalData()') &&
    !accountTabHandler[1].includes('LOCAL_DATA_UPDATED_AT'),
  'Switching to 我的 must not publish broad LOCAL_DATA_UPDATED_AT and indirectly force notification refresh'
)

const sessionParser = read('shared/src/main/ets/parser/V2exSessionParser.ets')
for (const token of [
  'static extractUnreadNotificationCount(html: string): number',
  '/notifications',
  'extractFirstNumber(text)',
]) {
  assert(sessionParser.includes(token), `V2exSessionParser unread-count contract missing ${token}`)
}

const cacheCoordinator = read('entry/src/main/ets/model/NotificationCacheCoordinator.ets')
assert(
  cacheCoordinator.includes('source: string') &&
    cacheCoordinator.includes('NotificationPageCoordinator.ownerKey(username, storedUsername, sessionUsername, source)'),
  'Notification cache coordinator must include auth source in cache ownership'
)
const pageCoordinator = read('entry/src/main/ets/model/NotificationPageCoordinator.ets')
assert(
  pageCoordinator.includes("':source:' + cleanSource") &&
    pageCoordinator.includes("cleanSource === 'none'"),
  'Notification owner key must separate PAT and Web-session caches'
)

console.log('notification system contract ok')
