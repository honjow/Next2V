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
    const seen: Set<string> = new Set()
    const items: V2exAccountMemberListItem[] = []
    const blocks = V2exAccountListParser.extractMemberBlocks(clean)
    for (const block of blocks) {
      const blockItems = V2exAccountListParser.extractMembersFromBlock(block)
      for (const item of blockItems) {
        if (item.username && item.username.toLowerCase() !== excluded && !seen.has(item.username)) {
          items.push(item)
          seen.add(item.username)
        }
      }
    }
    if (items.length > 0) {
      return items
    }
    return V2exAccountListParser.extractLinkedMembers(clean, excluded, seen)
  }

  static extractTopicIds(html: string): number[] {
    return V2exTabParser.extractTopicIds(html || '')
  }

  private static extractMemberBlocks(html: string): string[] {
    const blocks: string[] = []
    const rowRe = /<tr\b[\s\S]*?<\/tr>/gi
    let rowMatch: RegExpExecArray | null = rowRe.exec(html)
    while (rowMatch) {
      const row = rowMatch[0] || ''
      if (V2exAccountListParser.hasAvatarImage(row) && V2exAccountListParser.hasMemberLink(row)) {
        blocks.push(row)
      }
      rowMatch = rowRe.exec(html)
    }
    if (blocks.length > 0) {
      return blocks
    }

    const cellStarts: number[] = []
    const cellRe = /<div[^>]+class=['"][^'"]*\bcell\b[^'"]*['"][^>]*>/gi
    let cellMatch: RegExpExecArray | null = cellRe.exec(html)
    while (cellMatch) {
      cellStarts.push(cellMatch.index)
      cellMatch = cellRe.exec(html)
    }
    for (let i = 0; i < cellStarts.length; i++) {
      const start = cellStarts[i]
      const end = i + 1 < cellStarts.length ? cellStarts[i + 1] : html.length
      const cell = html.slice(start, end)
      if (V2exAccountListParser.hasAvatarImage(cell) && V2exAccountListParser.hasMemberLink(cell)) {
        blocks.push(cell)
      }
    }
    return blocks
  }

  private static extractMembersFromBlock(block: string): V2exAccountMemberListItem[] {
    const items: V2exAccountMemberListItem[] = []
    const avatarOwner = V2exAccountListParser.extractAvatarLinkedUsername(block)
    const blockAvatar = V2exAccountListParser.extractAvatarFromHtml(block)
    const seen: Set<string> = new Set()
    const linkRe = /<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>([\s\S]*?)<\/a>/gi
    let m: RegExpExecArray | null = linkRe.exec(block)
    while (m) {
      const username = (m[1] || '').trim()
      if (username && !seen.has(username)) {
        const label = V2exAccountListParser.compactText(m[2] || '')
        const linkAvatar = V2exAccountListParser.extractAvatarFromHtml(m[2] || '')
        items.push({
          username: username,
          avatar: linkAvatar || (username === avatarOwner ? blockAvatar : ''),
          subtitle: label && label !== username ? label : ''
        })
        seen.add(username)
      }
      m = linkRe.exec(block)
    }
    if (items.length === 0 && avatarOwner) {
      items.push({
        username: avatarOwner,
        avatar: blockAvatar,
        subtitle: ''
      })
    }
    return items
  }

  private static extractAvatarLinkedUsername(html: string): string {
    const linkRe = /<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>([\s\S]*?)<\/a>/gi
    let m: RegExpExecArray | null = linkRe.exec(html)
    while (m) {
      if (V2exAccountListParser.hasAvatarImage(m[2] || '')) {
        return (m[1] || '').trim()
      }
      m = linkRe.exec(html)
    }
    return ''
  }

  private static extractLinkedMembers(html: string, excluded: string, seen: Set<string>): V2exAccountMemberListItem[] {
    const items: V2exAccountMemberListItem[] = []
    const memberRe = /<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>([\s\S]*?)<\/a>/gi
    let m: RegExpExecArray | null = memberRe.exec(html)
    while (m) {
      const username = (m[1] || '').trim()
      if (username && username.toLowerCase() !== excluded && !seen.has(username)) {
        const label = V2exAccountListParser.compactText(m[2] || '')
        const avatar = V2exAccountListParser.extractAvatarFromHtml(m[2] || '')
        if (avatar) {
          items.push({
            username: username,
            avatar: avatar,
            subtitle: label && label !== username ? label : ''
          })
          seen.add(username)
        }
      }
      m = memberRe.exec(html)
    }
    return items
  }

  private static hasMemberLink(html: string): boolean {
    return /href=['"]\/member\/[0-9A-Za-z_]+['"]/i.test(html)
  }

  private static hasAvatarImage(html: string): boolean {
    return V2exAccountListParser.extractAvatarFromHtml(html).length > 0
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
