import type { V2exMember, V2exNotification } from '../network/NetworkTypes'

interface ParsedNotificationTopic {
  id: number
  title: string
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
        const item = V2exNotificationParser.parseCell(id, cell)
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
      const item = V2exNotificationParser.parseCell(id, m[2] || '')
      if (item) {
        items.push(item)
      }
      m = cellRe.exec(html)
    }
    return items
  }

  private static parseCell(id: number, cell: string): V2exNotification | null {
    const topic = V2exNotificationParser.extractTopic(cell)
    const member = V2exNotificationParser.extractMember(cell)
    const text = V2exNotificationParser.compactText(cell)
    if (!text && !topic.title) {
      return null
    }
    return {
      id: id,
      member: member,
      text: text,
      title: topic.title,
      topic_id: topic.id,
      topic_title: topic.title,
      created: 0,
      last_modified: 0
    }
  }

  private static extractTopic(cell: string): ParsedNotificationTopic {
    const re = /<a[^>]+href=['"]\/t\/(\d+)(?:#[^'"]*)?['"][^>]*>([\s\S]*?)<\/a>/i
    const m = cell.match(re)
    if (!m) {
      return { id: 0, title: '' }
    }
    return {
      id: Number.parseInt(m[1] || '0'),
      title: V2exNotificationParser.compactText(m[2] || '')
    }
  }

  private static extractMember(cell: string): V2exMember | undefined {
    const re = /<a[^>]+href=['"]\/member\/([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/i
    const m = cell.match(re)
    if (!m) {
      return undefined
    }
    const username = V2exNotificationParser.compactText(m[2] || '') || V2exNotificationParser.decodeHtml(m[1] || '')
    return {
      id: 0,
      username: username,
      tagline: '',
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
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
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }
}
