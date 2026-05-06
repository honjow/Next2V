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
    return {
      kindTag: this.kindTag(item, body),
      readTag: this.readTag(item),
      topicId: this.topicId(item),
      targetFloor: this.targetFloor(item),
      title: this.title(item),
      body: body
    }
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

  private source(context: NotificationAuthContext): NotificationSource {
    if (context.tokenConfigured && !!context.token) {
      return 'pat'
    }
    if (context.cookieConfigured && !!context.cookie) {
      return 'cookie'
    }
    return 'none'
  }

  private readTag(item: V2exNotification): string {
    const bag = item as NotificationReadStateBag

    const unread = this.flag(bag.unread)
    if (unread !== null) {
      return unread ? '未读' : '已读'
    }
    const isUnread = this.flag(bag.is_unread)
    if (isUnread !== null) {
      return isUnread ? '未读' : '已读'
    }
    const isUnreadCamel = this.flag(bag.isUnread)
    if (isUnreadCamel !== null) {
      return isUnreadCamel ? '未读' : '已读'
    }

    const read = this.flag(bag.read)
    if (read !== null) {
      return read ? '已读' : '未读'
    }
    const isRead = this.flag(bag.is_read)
    if (isRead !== null) {
      return isRead ? '已读' : '未读'
    }
    const isReadCamel = this.flag(bag.isRead)
    if (isReadCamel !== null) {
      return isReadCamel ? '已读' : '未读'
    }
    return ''
  }

  private kindTag(item: V2exNotification, body: string): string {
    const text = `${item.title || ''} ${body} ${item.payload || ''} ${item.payload_rendered || ''}`.toLowerCase()
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
    return item.text || item.content || item.payload || item.content_rendered || item.payload_rendered || ''
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

  private containsAny(text: string, needles: string[]): boolean {
    return needles.some((needle: string) => text.indexOf(needle) >= 0)
  }
}
