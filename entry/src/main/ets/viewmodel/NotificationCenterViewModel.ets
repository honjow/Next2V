import { ApiService } from 'shared'
import type { V2exNotification } from 'shared'

export type NotificationSource = 'pat' | 'cookie' | 'none'

export interface NotificationAuthContext {
  tokenConfigured: boolean
  token: string
  cookieConfigured: boolean
  cookie: string
}

export interface NotificationPageResult {
  items: V2exNotification[]
  page: number
  hasMore: boolean
  source: NotificationSource
  sourceLabel: string
}

export interface NotificationMetadata {
  kindTag: string
  readTag: string
  topicId: number
  targetFloor: number
  title: string
  body: string
  replyContent: string
  replyRenderedContent: string
  memberName: string
  avatarUrl: string
  canDeleteWithCookie: boolean
}

interface NotificationReadStateBag {
  unread?: boolean | number
  is_unread?: boolean | number
  isUnread?: boolean | number
  read?: boolean | number
  is_read?: boolean | number
  isRead?: boolean | number
}

export class NotificationCenterViewModel {
  private api: ApiService

  constructor(api: ApiService = new ApiService()) {
    this.api = api
  }

  hasAuth(context: NotificationAuthContext): boolean {
    return this.source(context) !== 'none'
  }

  canDelete(context: NotificationAuthContext): boolean {
    return context.tokenConfigured && !!context.token
  }

  canDeleteItem(context: NotificationAuthContext, item: V2exNotification): boolean {
    if (this.canDelete(context)) {
      return true
    }
    return context.cookieConfigured && !!context.cookie && this.webDeleteId(item) > 0 && !!this.webDeleteOnce(item)
  }

  async loadPage(
    context: NotificationAuthContext,
    page: number,
    pageSize: number
  ): Promise<NotificationPageResult> {
    const source = this.source(context)
    if (source === 'none') {
      return {
        items: [],
        page: page,
        hasMore: false,
        source: source,
        sourceLabel: this.sourceLabel(source)
      }
    }

    const items = source === 'pat'
      ? await this.api.getNotifications(context.token, page)
      : await this.api.getNotificationsWithCookie(context.cookie, page)
    return {
      items: items,
      page: page,
      hasMore: items.length >= pageSize,
      source: source,
      sourceLabel: this.sourceLabel(source)
    }
  }

  mergeUnique(existing: V2exNotification[], incoming: V2exNotification[]): V2exNotification[] {
    const seen = new Set<number>(existing.map((item: V2exNotification) => item.id))
    const unique = incoming.filter((item: V2exNotification) => item && item.id > 0 && !seen.has(item.id))
    return existing.concat(unique)
  }

  metadata(item: V2exNotification): NotificationMetadata {
    const body = this.body(item)
    const kindTag = this.kindTag(item, body)
    return {
      kindTag: kindTag,
      readTag: this.readTag(item),
      topicId: this.topicId(item),
      targetFloor: this.targetFloor(item),
      title: this.title(item),
      body: this.displayBody(kindTag, body),
      replyContent: this.displayReplyContent(kindTag, item),
      replyRenderedContent: this.displayReplyRenderedContent(kindTag, item),
      memberName: item.member?.username || '',
      avatarUrl: item.member?.avatar_normal || item.member?.avatar_large || item.member?.avatar_mini || '',
      canDeleteWithCookie: this.webDeleteId(item) > 0 && !!this.webDeleteOnce(item)
    }
  }

  unreadCount(items: V2exNotification[]): number {
    if (!Array.isArray(items)) {
      return 0
    }
    return items.filter((item: V2exNotification) => this.isUnread(item)).length
  }

  async unreadCountFromCookie(cookie: string): Promise<number> {
    return this.api.getNotificationUnreadCountWithCookie(cookie)
  }

  webDeleteId(item: V2exNotification): number {
    const id = item.delete_id || item.id || 0
    return id > 0 ? id : 0
  }

  webDeleteOnce(item: V2exNotification): string {
    return (item.delete_once || '').trim()
  }

  kindSummary(items: V2exNotification[]): string {
    const counts: Record<string, number> = {}
    items.forEach((item: V2exNotification) => {
      const kind = this.metadata(item).kindTag
      counts[kind] = (counts[kind] || 0) + 1
    })
    const order: string[] = ['回复', '提及', '感谢', '收藏', '关注', '系统', '通知']
    const parts: string[] = []
    order.forEach((kind: string) => {
      const count = counts[kind] || 0
      if (count > 0) {
        parts.push(`${kind} ${count}`)
      }
    })
    return parts.join(' · ')
  }

  sourceLabel(source: NotificationSource): string {
    if (source === 'pat') {
      return 'API v2'
    }
    if (source === 'cookie') {
      return 'Web 会话'
    }
    return ''
  }

  sourceLabelFor(context: NotificationAuthContext): string {
    return this.sourceLabel(this.source(context))
  }

  sourceKeyFor(context: NotificationAuthContext): NotificationSource {
    return this.source(context)
  }

  private source(context: NotificationAuthContext): NotificationSource {
    if (context.cookieConfigured && !!context.cookie) {
      return 'cookie'
    }
    if (context.tokenConfigured && !!context.token) {
      return 'pat'
    }
    return 'none'
  }

  private readTag(item: V2exNotification): string {
    const bag = item as NotificationReadStateBag

    const unread = this.flag(bag.unread)
    if (unread !== null) {
      return unread ? '未读' : ''
    }
    const isUnread = this.flag(bag.is_unread)
    if (isUnread !== null) {
      return isUnread ? '未读' : ''
    }
    const isUnreadCamel = this.flag(bag.isUnread)
    if (isUnreadCamel !== null) {
      return isUnreadCamel ? '未读' : ''
    }

    const read = this.flag(bag.read)
    if (read !== null) {
      return read ? '' : '未读'
    }
    const isRead = this.flag(bag.is_read)
    if (isRead !== null) {
      return isRead ? '' : '未读'
    }
    const isReadCamel = this.flag(bag.isRead)
    if (isReadCamel !== null) {
      return isReadCamel ? '' : '未读'
    }
    return ''
  }

  private kindTag(item: V2exNotification, body: string): string {
    const text = `${item.title || ''} ${body} ${this.replyContent(item)} ${item.payload || ''} ${item.payload_rendered || ''}`.toLowerCase()
    if (this.containsAny(text, ['提到了你', 'mentioned you', 'mention'])) {
      return '提及'
    }
    if (this.containsAny(text, ['回复了你', '回复了你的', 'replied', 'reply'])) {
      return '回复'
    }
    if (this.containsAny(text, ['感谢了你', 'thanks', 'thanked'])) {
      return '感谢'
    }
    if (this.containsAny(text, ['收藏了你', 'favorite', 'favorited', '收藏'])) {
      return '收藏'
    }
    if (this.containsAny(text, ['关注了你', 'followed', '关注'])) {
      return '关注'
    }
    if (this.containsAny(text, ['system', '系统'])) {
      return '系统'
    }
    return body || item.title ? '通知' : '系统'
  }

  private title(item: V2exNotification): string {
    return item.topic_title || item.title || item.member?.username || '通知'
  }

  private body(item: V2exNotification): string {
    return item.text || item.content || item.content_rendered || ''
  }

  private displayBody(kindTag: string, body: string): string {
    if (kindTag === '收藏') {
      return ''
    }
    return body
  }

  private displayReplyContent(kindTag: string, item: V2exNotification): string {
    if (kindTag === '收藏') {
      return ''
    }
    return this.replyContent(item)
  }

  private displayReplyRenderedContent(kindTag: string, item: V2exNotification): string {
    if (kindTag === '收藏') {
      return ''
    }
    return this.replyRenderedContent(item)
  }

  private replyContent(item: V2exNotification): string {
    return this.firstReadableContent([
      item.reply_content,
      item.payload,
      item.content,
      item.reply_content_rendered,
      item.payload_rendered,
      item.content_rendered
    ])
  }

  private firstReadableContent(candidates: (string | undefined)[]): string {
    for (const candidate of candidates) {
      const readable = this.readableNotificationContent(candidate || '')
      if (readable) {
        return readable
      }
    }
    return ''
  }

  private readableNotificationContent(raw: string): string {
    const clean = (raw || '').trim()
    if (!clean) {
      return ''
    }
    return this.decodeHtml(clean
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<img\b[^>]*>/gi, ' 图片 ')
      .replace(/<br\s*\/?>/gi, ' ')
      .replace(/<\/p>/gi, ' ')
      .replace(/<[^>]+>/g, ' '))
      .replace(/\s+/g, ' ')
      .trim()
  }

  private decodeHtml(value: string): string {
    return value
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }

  private replyRenderedContent(item: V2exNotification): string {
    return item.reply_content_rendered || item.payload_rendered || item.content_rendered || ''
  }

  private topicId(item: V2exNotification): number {
    if (item.topic_id && item.topic_id > 0) {
      return item.topic_id
    }
    const text = `${item.text || ''} ${item.content || ''} ${item.payload || ''} ${item.content_rendered || ''} ${item.payload_rendered || ''}`
    const match = text.match(/\/t\/(\d+)/)
    if (!match || !match[1]) {
      return 0
    }
    const parsed = Number(match[1])
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
  }

  private targetFloor(item: V2exNotification): number {
    if (item.target_floor && item.target_floor > 0) {
      return item.target_floor
    }
    const text = `${item.text || ''} ${item.content || ''} ${item.payload || ''} ${item.content_rendered || ''} ${item.payload_rendered || ''}`
    const match = text.match(/#(?:reply|r_?)(\d+)/i) || text.match(/(?:^|\s)#(\d+)(?:\s|$)/)
    if (!match || !match[1]) {
      return 0
    }
    const parsed = Number(match[1])
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
  }

  private flag(value?: boolean | number): boolean | null {
    if (typeof value === 'boolean') {
      return value
    }
    if (typeof value === 'number') {
      return value > 0
    }
    return null
  }

  private isUnread(item: V2exNotification): boolean {
    const tag = this.readTag(item)
    return tag === '未读'
  }

  private containsAny(text: string, needles: string[]): boolean {
    return needles.some((needle: string) => text.indexOf(needle) >= 0)
  }
}
