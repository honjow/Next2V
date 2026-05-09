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
        const linkHtml = m[2] || ''
        items.push({
          username: username,
          avatar: V2exAccountListParser.extractAvatarFromHtml(linkHtml) ||
            V2exAccountListParser.extractScopedAvatar(clean, m.index, username),
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

  private static extractScopedAvatar(html: string, linkIndex: number, username: string): string {
    const block = V2exAccountListParser.extractMemberBlock(html, linkIndex)
    const direct = V2exAccountListParser.extractAvatarFromHtml(block)
    if (direct) {
      return direct
    }
    return V2exAccountListParser.extractNearestAvatar(html, linkIndex, username)
  }

  private static extractMemberBlock(html: string, linkIndex: number): string {
    const divCellStart = Math.max(
      html.lastIndexOf('<div class="cell"', linkIndex),
      html.lastIndexOf("<div class='cell'", linkIndex)
    )
    if (divCellStart >= 0) {
      const cellEnd = html.indexOf('</div>', linkIndex)
      if (cellEnd > divCellStart) {
        return html.slice(divCellStart, cellEnd)
      }
    }
    const rowStart = html.lastIndexOf('<tr', linkIndex)
    if (rowStart >= 0) {
      const rowEnd = html.indexOf('</tr>', linkIndex)
      if (rowEnd > rowStart) {
        return html.slice(rowStart, rowEnd)
      }
    }
    const tdStart = html.lastIndexOf('<td', linkIndex)
    if (tdStart >= 0) {
      const tdEnd = html.indexOf('</td>', linkIndex)
      if (tdEnd > tdStart) {
        return html.slice(tdStart, tdEnd)
      }
    }
    const start = Math.max(0, linkIndex - 240)
    const end = Math.min(html.length, linkIndex + 240)
    return html.slice(start, end)
  }

  private static extractAvatarFromHtml(html: string): string {
    const imgRe = /<img[^>]+src=['"]([^'"]+)['"][^>]*>/gi
    let m: RegExpExecArray | null = imgRe.exec(html)
    while (m) {
      const src = V2exAccountListParser.decodeHtml(m[1] || '').trim()
      if (V2exAccountListParser.isAvatarImage(src)) {
        return V2exAccountListParser.normalizeImageUrl(src)
      }
      m = imgRe.exec(html)
    }
    return ''
  }

  private static extractNearestAvatar(html: string, linkIndex: number, username: string): string {
    const start = Math.max(0, linkIndex - 240)
    const end = Math.min(html.length, linkIndex + 240)
    const block = html.slice(start, end)
    const localLinkIndex = linkIndex - start
    const imgRe = /<img[^>]+src=['"]([^'"]+)['"][^>]*>/gi
    let bestSrc = ''
    let bestDistance = 1000000000
    let m: RegExpExecArray | null = imgRe.exec(block)
    while (m) {
      const src = V2exAccountListParser.decodeHtml(m[1] || '').trim()
      if (src.indexOf(username) >= 0 || V2exAccountListParser.isAvatarImage(src)) {
        const distance = Math.abs(m.index - localLinkIndex)
        if (distance < bestDistance) {
          bestDistance = distance
          bestSrc = src
        }
      }
      m = imgRe.exec(block)
    }
    return V2exAccountListParser.normalizeImageUrl(bestSrc)
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

  private static isAvatarImage(src: string): boolean {
    const lower = (src || '').toLowerCase()
    return lower.indexOf('/avatar/') >= 0 || lower.indexOf('/gravatar/') >= 0
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
