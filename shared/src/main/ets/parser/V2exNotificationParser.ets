import type { V2exMember, V2exNotification } from '../network/NetworkTypes'

interface ParsedNotificationTopic {
  id: number
  title: string
  targetFloor: number
}

interface ParsedNotificationCreatedMeta {
  created: number
  timeText: string
}

interface ParsedNotificationDeleteAction {
  id: number
  once: string
}

export class V2exNotificationParser {
  static extractNotifications(html: string): V2exNotification[] {
    if (!html) {
      return []
    }
    const items: V2exNotification[] = []
    const cellRe = /<div[^>]*(?:id=['"]n_(\d+)['"][^>]*class=['"][^'"]*cell[^'"]*['"]|class=['"][^'"]*cell[^'"]*['"][^>]*id=['"]n_(\d+)['"])[^>]*>([\s\S]*?)(?=<div[^>]*(?:id=['"]n_\d+['"][^>]*class=['"][^'"]*cell|class=['"][^'"]*cell[^'"]*['"][^>]*id=['"]n_\d+['"])|$)/gi
    let m: RegExpExecArray | null = cellRe.exec(html)
    while (m) {
      const id = Number.parseInt(m[1] || m[2] || '0')
      const cell = m[3] || ''
      if (id > 0) {
        const openTag = V2exNotificationParser.extractOpenTag(m[0] || '')
        const item = V2exNotificationParser.parseCell(id, openTag, cell)
        if (item) {
          items.push(item)
        }
      }
      m = cellRe.exec(html)
    }
    if (items.length > 0) {
      return items
    }
    return V2exNotificationParser.extractNotificationsFallback(html)
  }

  private static extractNotificationsFallback(html: string): V2exNotification[] {
    const items: V2exNotification[] = []
    const cellRe = /<div[^>]*id=['"]n_(\d+)['"][^>]*>([\s\S]*?)<\/div>/gi
    let m: RegExpExecArray | null = cellRe.exec(html)
    while (m) {
      const id = Number.parseInt(m[1] || '0')
      const openTag = V2exNotificationParser.extractOpenTag(m[0] || '')
      const item = V2exNotificationParser.parseCell(id, openTag, m[2] || '')
      if (item) {
        items.push(item)
      }
      m = cellRe.exec(html)
    }
    return items
  }

  private static parseCell(id: number, openTag: string, cell: string): V2exNotification | null {
    const topic = V2exNotificationParser.extractTopic(cell)
    const member = V2exNotificationParser.extractMember(cell)
    const rawText = V2exNotificationParser.compactText(cell)
    const meta = V2exNotificationParser.extractCreated(rawText)
    const unread = V2exNotificationParser.extractUnread(openTag)
    const replyContentRendered = V2exNotificationParser.extractPayloadHtml(cell)
    const replyContent = replyContentRendered ? V2exNotificationParser.compactText(replyContentRendered) : ''
    const deleteAction = V2exNotificationParser.extractDeleteAction(cell)
    const text = meta.timeText ? V2exNotificationParser.stripTimeSuffix(rawText, meta.timeText) : rawText
    if (!text && !topic.title) {
      return null
    }
    return {
      id: id,
      member: member,
      text: text,
      reply_content: replyContent,
      reply_content_rendered: replyContentRendered,
      payload: replyContent,
      payload_rendered: replyContentRendered,
      title: topic.title,
      topic_id: topic.id,
      topic_title: topic.title,
      target_floor: topic.targetFloor,
      delete_id: deleteAction.id,
      delete_once: deleteAction.once,
      created: meta.created,
      last_modified: 0,
      unread: unread === null ? undefined : unread
    }
  }

  private static extractOpenTag(html: string): string {
    if (!html) {
      return ''
    }
    const end = html.indexOf('>')
    if (end < 0) {
      return ''
    }
    return html.slice(0, end + 1)
  }

  private static extractUnread(openTag: string): boolean | null {
    if (!openTag) {
      return null
    }
    const classMatch = openTag.match(/class=['"]([^'"]+)['"]/i)
    const className = classMatch ? (classMatch[1] || '').toLowerCase() : ''
    if (!className) {
      return null
    }
    if (className.indexOf('unread') >= 0) {
      return true
    }
    return false
  }

  private static stripTimeSuffix(text: string, timeText: string): string {
    if (!text || !timeText) {
      return text
    }
    const idx = text.lastIndexOf(timeText)
    if (idx < 0) {
      return text
    }
    const end = idx + timeText.length
    if (end < text.length && text.slice(end).trim()) {
      return text
    }
    return (text.slice(0, idx) + text.slice(end)).replace(/\s+/g, ' ').trim()
  }

  private static extractCreated(text: string): ParsedNotificationCreatedMeta {
    const clean = (text || '').trim()
    if (!clean) {
      return { created: 0, timeText: '' }
    }

    const absolute = V2exNotificationParser.extractAbsoluteCreated(clean)
    if (absolute.created > 0) {
      return absolute
    }
    const relative = V2exNotificationParser.extractRelativeCreated(clean)
    if (relative.created > 0) {
      return relative
    }
    return { created: 0, timeText: '' }
  }

  private static extractRelativeCreated(text: string): ParsedNotificationCreatedMeta {
    const re = /(刚刚|半小时前|\d+\s*秒前|\d+\s*分钟前|\d+\s*小时\s*\d+\s*分钟前|\d+\s*小时前|\d+\s*天前|\d+\s*个月前|\d+\s*年前)/i
    const m = text.match(re)
    if (!m) {
      return { created: 0, timeText: '' }
    }
    const timeText = (m[1] || '').trim()
    if (!timeText) {
      return { created: 0, timeText: '' }
    }
    const now = Math.floor(Date.now() / 1000)
    if (timeText === '刚刚') {
      return { created: now, timeText: timeText }
    }
    if (timeText === '半小时前') {
      return { created: now - 30 * 60, timeText: timeText }
    }

    const hours = V2exNotificationParser.parseNumber(timeText, /(\d+)\s*小时/i)
    const minutes = V2exNotificationParser.parseNumber(timeText, /(\d+)\s*分钟/i)
    const seconds = V2exNotificationParser.parseNumber(timeText, /(\d+)\s*秒/i)
    const days = V2exNotificationParser.parseNumber(timeText, /(\d+)\s*天/i)
    const months = V2exNotificationParser.parseNumber(timeText, /(\d+)\s*个月/i)
    const years = V2exNotificationParser.parseNumber(timeText, /(\d+)\s*年/i)
    const diffSeconds = years * 365 * 86400 + months * 30 * 86400 + days * 86400 + hours * 3600 + minutes * 60 + seconds
    if (diffSeconds <= 0) {
      return { created: 0, timeText: '' }
    }
    return { created: now - diffSeconds, timeText: timeText }
  }

  private static extractAbsoluteCreated(text: string): ParsedNotificationCreatedMeta {
    const now = new Date()

    const ym = text.match(/(\d{4})-(\d{1,2})-(\d{1,2})\s*(\d{1,2}):(\d{2})(?::(\d{2}))?/i)
    if (ym) {
      const created = V2exNotificationParser.buildLocalTime(
        Number.parseInt(ym[1] || '0'),
        Number.parseInt(ym[2] || '0'),
        Number.parseInt(ym[3] || '0'),
        Number.parseInt(ym[4] || '0'),
        Number.parseInt(ym[5] || '0'),
        Number.parseInt(ym[6] || '0')
      )
      return created > 0 ? { created: created, timeText: ym[0] || '' } : { created: 0, timeText: '' }
    }

    const yesterday = text.match(/(昨天|前天)\s*(\d{1,2}):(\d{2})/i)
    if (yesterday) {
      const days = (yesterday[1] || '') === '前天' ? 2 : 1
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - days, Number.parseInt(yesterday[2] || '0'), Number.parseInt(yesterday[3] || '0'), 0)
      return { created: Math.floor(d.getTime() / 1000), timeText: yesterday[0] || '' }
    }

    const mdhm = text.match(/(\d{1,2})-(\d{1,2})\s*(\d{1,2}):(\d{2})/i)
    if (mdhm) {
      let year = now.getFullYear()
      const month = Number.parseInt(mdhm[1] || '0')
      const day = Number.parseInt(mdhm[2] || '0')
      const hour = Number.parseInt(mdhm[3] || '0')
      const minute = Number.parseInt(mdhm[4] || '0')
      const d = new Date(year, month - 1, day, hour, minute, 0)
      if (d.getTime() > now.getTime() + 5 * 60 * 1000) {
        year = year - 1
      }
      const d2 = new Date(year, month - 1, day, hour, minute, 0)
      return { created: Math.floor(d2.getTime() / 1000), timeText: mdhm[0] || '' }
    }

    const ymdChinese = text.match(/(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日(?:\s*(\d{1,2}):(\d{2}))?/i)
    if (ymdChinese) {
      const created = V2exNotificationParser.buildLocalTime(
        Number.parseInt(ymdChinese[1] || '0'),
        Number.parseInt(ymdChinese[2] || '0'),
        Number.parseInt(ymdChinese[3] || '0'),
        Number.parseInt(ymdChinese[4] || '0'),
        Number.parseInt(ymdChinese[5] || '0'),
        0
      )
      return created > 0 ? { created: created, timeText: ymdChinese[0] || '' } : { created: 0, timeText: '' }
    }

    return { created: 0, timeText: '' }
  }

  private static buildLocalTime(year: number, month: number, day: number, hour: number, minute: number, second: number): number {
    if (year <= 0 || month <= 0 || day <= 0) {
      return 0
    }
    const d = new Date(year, month - 1, day, hour || 0, minute || 0, second || 0)
    const ts = Math.floor(d.getTime() / 1000)
    return ts > 0 ? ts : 0
  }

  private static parseNumber(text: string, re: RegExp): number {
    const m = text.match(re)
    if (!m) {
      return 0
    }
    const n = Number.parseInt(m[1] || '0')
    return Number.isNaN(n) ? 0 : n
  }

  private static extractTopic(cell: string): ParsedNotificationTopic {
    const re = /<a[^>]+href=['"]\/t\/(\d+)([^'"]*)['"][^>]*>([\s\S]*?)<\/a>/i
    const m = cell.match(re)
    if (!m) {
      return { id: 0, title: '', targetFloor: 0 }
    }
    return {
      id: Number.parseInt(m[1] || '0'),
      title: V2exNotificationParser.compactText(m[3] || ''),
      targetFloor: V2exNotificationParser.extractTargetFloor(m[2] || '')
    }
  }

  private static extractTargetFloor(hrefTail: string): number {
    const match = (hrefTail || '').match(/#(?:reply|r_?)(\d+)/i) || (hrefTail || '').match(/#(\d+)/)
    if (!match || !match[1]) {
      return 0
    }
    const parsed = Number.parseInt(match[1] || '0')
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
  }

  private static extractMember(cell: string): V2exMember | undefined {
    const re = /<a[^>]+href=['"]\/member\/([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/i
    const m = cell.match(re)
    if (!m) {
      return undefined
    }
    const username = V2exNotificationParser.compactText(m[2] || '') || V2exNotificationParser.decodeHtml(m[1] || '')
    const avatar = V2exNotificationParser.extractMemberAvatar(cell, username)
    return {
      id: 0,
      username: username,
      tagline: '',
      avatar_mini: avatar,
      avatar_normal: avatar,
      avatar_large: avatar
    }
  }

  private static extractMemberAvatar(cell: string, username: string): string {
    const imgRe = /<img[^>]+(?:alt=['"]([^'"]*)['"][^>]*src=['"]([^'"]+)['"]|src=['"]([^'"]+)['"][^>]*alt=['"]([^'"]*)['"])[^>]*>/i
    const m = cell.match(imgRe)
    if (!m) {
      return ''
    }
    const alt = V2exNotificationParser.decodeHtml(m[1] || m[4] || '')
    if (username && alt && alt !== username) {
      return ''
    }
    return V2exNotificationParser.decodeHtml(m[2] || m[3] || '')
  }

  private static extractPayloadHtml(cell: string): string {
    const m = cell.match(/<div[^>]+class=['"][^'"]*\bpayload\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i)
    return m ? (m[1] || '').trim() : ''
  }

  private static extractDeleteAction(cell: string): ParsedNotificationDeleteAction {
    const m = cell.match(/deleteNotification\s*\(\s*['"]?(\d+)['"]?\s*,\s*['"]?([^'")\s]+)['"]?\s*\)/i)
    if (!m) {
      return { id: 0, once: '' }
    }
    const id = Number.parseInt(m[1] || '0')
    return {
      id: Number.isFinite(id) && id > 0 ? id : 0,
      once: V2exNotificationParser.decodeHtml(m[2] || '').trim()
    }
  }

  private static compactText(html: string): string {
    return V2exNotificationParser.decodeHtml(html.replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' '))
      .replace(/\s+/g, ' ')
      .trim()
  }

  private static decodeHtml(value: string): string {
    return value
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }
}
