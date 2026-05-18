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
  ".replace(/<img\\b[^>]*>/gi, ' 图片 ')",
  "const username = labelUsername && labelUsername !== '图片' ? labelUsername : hrefUsername",
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
  "fields['once'] = once",
  'ApiService.encodeFormFields(fields)',
  'http.RequestMethod.POST',
  "'X-Requested-With': 'XMLHttpRequest'",
  'if (await this.isNotificationDeletedFromCookiePage(cookie, notificationId, safeVerifyPage))',
  'private async isNotificationDeletedFromCookiePage(cookie: string, notificationId: number, page: number): Promise<boolean>',
  'const latest = await this.getNotificationsWithCookie(cookie, page)',
  'item.id === notificationId || item.delete_id === notificationId',
  "throw new Error('删除通知未生效，请稍后重试')",
  "'/notifications'",
]) {
  assert(apiService.includes(token), `ApiService cookie delete contract missing ${token}`)
}

const vm = read('entry/src/main/ets/viewmodel/NotificationCenterViewModel.ets')
assert(!vm.includes("'已读'"), 'NotificationCenterViewModel should not emit a visible read tag')
for (const token of [
  'canDeleteItem(context: NotificationAuthContext, item: V2exNotification)',
  'unreadCount(items: V2exNotification[]): number',
  'async unreadCountFromCookie(cookie: string): Promise<number>',
  'webDeleteId(item: V2exNotification): number',
  'webDeleteOnce(item: V2exNotification): string',
  'body: this.displayBody(kindTag, body)',
  'replyContent: this.displayReplyContent(kindTag, item)',
  'replyRenderedContent: this.displayReplyRenderedContent(kindTag, item)',
  "if (kindTag === '收藏')",
  'private replyRenderedContent(item: V2exNotification): string',
  'private firstReadableContent(candidates: (string | undefined)[]): string',
  'private readableNotificationContent(raw: string): string',
  ".replace(/<img\\b[^>]*>/gi, ' 图片 ')",
  "tag === '未读'",
  "return unread ? '未读' : ''",
  "return read ? '' : '未读'",
]) {
  assert(vm.includes(token), `NotificationCenterViewModel contract missing ${token}`)
}

const page = read('entry/src/main/ets/pages/NotificationPage.ets')
assert(!page.includes('NotificationSummaryCard({'), 'NotificationPage must not render the old summary card as the first list item')
const localDataHandlerMatch = page.match(/onLocalDataUpdated\(_propName: string\): void \{([\s\S]*?)\n  \}/)
assert(localDataHandlerMatch, 'NotificationPage missing onLocalDataUpdated handler')
assert(
  !localDataHandlerMatch[1].includes('resetNotificationState()'),
  'NotificationPage must not blank the notification list on local data updates'
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
  '@StorageLink(StorageKeys.NOTIFICATION_UNREAD_COUNT) notificationUnreadCount: number = 0',
  'this.notificationVm.canDeleteItem(this.notificationAuthContext(), item)',
  'const verifyPage = this.notificationPageForItem(item)',
  'this.api.deleteNotificationWithCookie(cookie, notificationId, once, verifyPage)',
  'AlertDialog.show({',
  "value: '删除'",
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
  '@State private viewedUnreadNotificationKeys: string[] = []',
  'private notificationEntryUnreadCount: number = 0',
  'this.viewedUnreadKeysForLoadedItems(',
  'this.notificationsWithoutReadState(result.items)',
  'private captureNotificationEntryUnreadCount(): number',
  'private viewedUnreadKeysForLoadedItems(',
  'private notificationWithoutReadState(item: V2exNotification): V2exNotification',
  'this.notificationUnreadCount = 0',
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
  '@Prop replyContent: string =',
  '@Prop replyRenderedContent: string =',
  'source: this.replyPreviewSource()',
  'topMargin: 0',
  '@Prop memberName: string =',
  '@Prop avatarUrl: string =',
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
for (const token of [
  '@Prop badgeCount: number = 0',
  'if (this.badgeCount > 0)',
  'private badgeText(): string',
  "'99+'",
]) {
  assert(mainTabIcon.includes(token), `MainTabIcon badge contract missing ${token}`)
}

const index = read('entry/src/main/ets/pages/Index.ets')
for (const token of [
  '@StorageLink(StorageKeys.NOTIFICATION_UNREAD_COUNT) notificationUnreadCount: number = 0',
  'private refreshNotificationBadge(): void',
  'private canApplyNotificationBadgeRequest(requestId: number): boolean',
  'this.notificationBadgeRequestId++',
  'this.refreshNotificationBadge()',
  'this.notificationVm.unreadCountFromCookie(cookie)',
  'badgeCount: idx === 2 ? this.notificationUnreadCount : 0',
]) {
  assert(index.includes(token), `Index notification badge contract missing ${token}`)
}

const sessionParser = read('shared/src/main/ets/parser/V2exSessionParser.ets')
for (const token of [
  'static extractUnreadNotificationCount(html: string): number',
  '/notifications',
  'extractFirstNumber(text)',
]) {
  assert(sessionParser.includes(token), `V2exSessionParser unread-count contract missing ${token}`)
}

console.log('notification system contract ok')
