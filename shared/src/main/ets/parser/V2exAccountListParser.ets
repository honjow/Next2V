import { V2exTabParser } from './V2exTabParser'

export interface V2exAccountMemberListItem {
  username: string
  avatar: string
  subtitle: string
}

export class V2exAccountListParser {
  static extractMembers(html: string, excludedUsername: string = ''): V2exAccountMemberListItem[] {
    const clean = html || ''
    const excluded = (excludedUsername || '').trim().toLowerCase()
    const items: V2exAccountMemberListItem[] = []
    const seen: Set<string> = new Set()
    const memberRe = /<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>([\s\S]*?)<\/a>/gi
    let m: RegExpExecArray | null = memberRe.exec(clean)
    while (m) {
      const username = (m[1] || '').trim()
      if (username && username.toLowerCase() !== excluded && !seen.has(username)) {
        const label = V2exAccountListParser.compactText(m[2] || '')
        items.push({
          username: username,
          avatar: V2exAccountListParser.extractNearbyAvatar(clean, m.index, username),
          subtitle: label && label !== username ? label : ''
        })
        seen.add(username)
      }
      m = memberRe.exec(clean)
    }
    return items
  }

  static extractTopicIds(html: string): number[] {
    return V2exTabParser.extractTopicIds(html || '')
  }

  private static extractNearbyAvatar(html: string, linkIndex: number, username: string): string {
    const start = Math.max(0, linkIndex - 600)
    const end = Math.min(html.length, linkIndex + 600)
    const block = html.slice(start, end)
    const imgRe = /<img[^>]+src=['"]([^'"]+)['"][^>]*>/gi
    let m: RegExpExecArray | null = imgRe.exec(block)
    while (m) {
      const src = V2exAccountListParser.decodeHtml(m[1] || '').trim()
      if (src.indexOf(username) >= 0 || src.indexOf('/avatar/') >= 0) {
        return V2exAccountListParser.normalizeImageUrl(src)
      }
      m = imgRe.exec(block)
    }
    return ''
  }

  private static normalizeImageUrl(src: string): string {
    if (!src) {
      return ''
    }
    if (src.startsWith('//')) {
      return `https:${src}`
    }
    return src
  }

  private static compactText(html: string): string {
    return V2exAccountListParser.decodeHtml(html.replace(/<script[\s\S]*?<\/script>/gi, ' ')
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
