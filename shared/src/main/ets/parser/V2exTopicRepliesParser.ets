import type { V2exMember, V2exReply } from '../network/NetworkTypes'
import { HtmlEntityUtils } from '../utils/HtmlEntityUtils'

interface ParsedMemberMeta {
  id: number
  username: string
  avatar: string
}

/** Parses public /t/{topicId} HTML replies when legacy /api/replies/show.json is stale. */
export class V2exTopicRepliesParser {
  static parseReplies(html: string): V2exReply[] {
    if (!html) {
      return []
    }

    const replies: V2exReply[] = []
    const replyRe = /<div\s+id=['"]r_(\d+)['"][^>]*class=['"][^'"]*\bcell\b[^'"]*['"][^>]*>([\s\S]*?)(?=<div\s+id=['"]r_\d+['"][^>]*class=['"][^'"]*\bcell\b|<div\s+class=['"]sep20['"]|$)/gi
    let m: RegExpExecArray | null = replyRe.exec(html)
    while (m) {
      const id = V2exTopicRepliesParser.parseNumber(m[1] || '')
      const block = m[2] || ''
      const contentRendered = V2exTopicRepliesParser.extractReplyContentHtml(block)
      const member = V2exTopicRepliesParser.extractMember(block)
      if (id > 0 && contentRendered.length > 0 && member.username.length > 0) {
        replies.push({
          id,
          thanks: V2exTopicRepliesParser.extractThanks(block),
          thanked: V2exTopicRepliesParser.extractThankedByCurrentUser(block, id),
          content: V2exTopicRepliesParser.replyHtmlToMarkdown(contentRendered),
          content_rendered: contentRendered,
          member: V2exTopicRepliesParser.toMember(member),
          created: V2exTopicRepliesParser.extractCreated(block),
          last_modified: 0
        })
      }
      m = replyRe.exec(html)
    }
    return replies
  }

  static extractPageCount(html: string): number {
    if (!html) {
      return 1
    }
    let max = 1
    const pageRe = /[?&]p=(\d+)/gi
    let m: RegExpExecArray | null = pageRe.exec(html)
    while (m) {
      const page = V2exTopicRepliesParser.parseNumber(m[1] || '')
      if (page > max) {
        max = page
      }
      m = pageRe.exec(html)
    }
    return max
  }

  private static extractReplyContentHtml(block: string): string {
    const m = (block || '').match(/<div[^>]*class=['"][^'"]*\breply_content\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i)
    return m && m[1] ? m[1].trim() : ''
  }

  private static extractMember(block: string): ParsedMemberMeta {
    const clean = block || ''
    const avatarMatch = clean.match(/<img[^>]+class=['"][^'"]*\bavatar\b[^'"]*['"][^>]*>/i)
    const avatarTag = avatarMatch && avatarMatch[0] ? avatarMatch[0] : ''
    const avatar = V2exTopicRepliesParser.extractAttr(avatarTag, 'src')
    const avatarAlt = V2exTopicRepliesParser.extractAttr(avatarTag, 'alt')
    const uid = V2exTopicRepliesParser.parseNumber(V2exTopicRepliesParser.extractAttr(avatarTag, 'data-uid'))
    const memberMatch = clean.match(/<a[^>]+href=['"]\/member\/([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/i)
    const username = memberMatch
      ? V2exTopicRepliesParser.decodeHtml(memberMatch[1] || V2exTopicRepliesParser.stripTags(memberMatch[2] || ''))
      : V2exTopicRepliesParser.decodeHtml(avatarAlt)
    return {
      id: uid,
      username,
      avatar
    }
  }

  private static toMember(meta: ParsedMemberMeta): V2exMember {
    const avatar = V2exTopicRepliesParser.normalizeAvatar(meta.avatar)
    return {
      id: meta.id,
      username: meta.username,
      tagline: '',
      avatar_mini: avatar,
      avatar_normal: avatar,
      avatar_large: avatar
    }
  }

  private static extractCreated(block: string): number {
    const m = (block || '').match(/<span[^>]*class=['"][^'"]*\bago\b[^'"]*['"][^>]*title=['"]([^'"]+)['"][^>]*>/i) ||
      (block || '').match(/<span[^>]*title=['"]([^'"]+)['"][^>]*class=['"][^'"]*\bago\b[^'"]*['"][^>]*>/i)
    if (!m || !m[1]) {
      return 0
    }
    return V2exTopicRepliesParser.parseAbsoluteTime(m[1])
  }

  private static parseAbsoluteTime(text: string): number {
    const m = (text || '').match(/(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/) 
    if (!m) {
      return 0
    }
    const d = new Date(
      V2exTopicRepliesParser.parseNumber(m[1] || '0'),
      V2exTopicRepliesParser.parseNumber(m[2] || '1') - 1,
      V2exTopicRepliesParser.parseNumber(m[3] || '1'),
      V2exTopicRepliesParser.parseNumber(m[4] || '0'),
      V2exTopicRepliesParser.parseNumber(m[5] || '0'),
      V2exTopicRepliesParser.parseNumber(m[6] || '0')
    )
    return Math.floor(d.getTime() / 1000)
  }

  private static extractThanks(block: string): number {
    const heartCount = (block || '').match(/<span[^>]*class=['"][^'"]*\bsmall\b[^'"]*\bfade\b[^'"]*['"][^>]*>[\s\S]*?(?:heart|❤️)[\s\S]*?(\d+)\s*<\/span>/i)
    if (heartCount && heartCount[1]) {
      return V2exTopicRepliesParser.parseNumber(heartCount[1])
    }
    const m = (block || '').match(/(\d+)\s*(?:个)?感谢|thanks[^>]*>\s*(\d+)/i)
    if (!m) {
      return 0
    }
    return V2exTopicRepliesParser.parseNumber(m[1] || m[2] || '')
  }

  private static extractThankedByCurrentUser(block: string, replyId: number): boolean {
    if (!block || replyId <= 0) {
      return false
    }
    const areaId = new RegExp(`id=['\"]thank_area_${replyId}['\"]`, 'i')
    if (!areaId.test(block)) {
      return false
    }
    if (new RegExp(`thankReply\\(\\s*${replyId}\\s*\\)`, 'i').test(block)) {
      return false
    }
    return /已感谢|感谢已发送|thanked|heart_|thank_area/i.test(block)
  }

  private static replyHtmlToMarkdown(html: string): string {
    return V2exTopicRepliesParser.decodeHtml((html || '')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>\s*<p[^>]*>/gi, '\n\n')
      .replace(/<p[^>]*>/gi, '')
      .replace(/<\/p>/gi, '')
      .replace(/<pre[^>]*><code[^>]*>([\s\S]*?)<\/code><\/pre>/gi, '\n```\n$1\n```\n')
      .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>\s*(<img\b[^>]*>)\s*<\/a>/gi,
        (_match: string, href: string, imgTag: string) => V2exTopicRepliesParser.imageTagToMarkdown(imgTag, href))
      .replace(/<img\b[^>]*>/gi,
        (match: string) => V2exTopicRepliesParser.imageTagToMarkdown(match, ''))
      .replace(/@?\s*<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>[\s\S]*?<\/a>/gi, '[@$1](/member/$1)')
      .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)')
      .replace(/<[^>]+>/g, ''))
      .replace(/\n{3,}/g, '\n\n')
      .trim()
  }

  private static imageTagToMarkdown(tag: string, fallbackHref: string): string {
    const src = V2exTopicRepliesParser.extractAttr(tag, 'src') ||
      V2exTopicRepliesParser.decodeHtml(fallbackHref || '').trim()
    if (!src) {
      return ''
    }
    return src
  }

  private static extractAttr(tag: string, name: string): string {
    if (!tag || !name) {
      return ''
    }
    const re = new RegExp(`${name}=['"]([^'"]*)['"]`, 'i')
    const m = tag.match(re)
    return m && m[1] ? V2exTopicRepliesParser.decodeHtml(m[1]) : ''
  }

  private static normalizeAvatar(url: string): string {
    const clean = (url || '').trim()
    if (clean.startsWith('//')) {
      return `https:${clean}`
    }
    return clean
  }

  private static stripTags(html: string): string {
    return (html || '').replace(/<[^>]+>/g, '')
  }

  private static decodeHtml(value: string): string {
    return HtmlEntityUtils.decode(value || '')
  }

  private static parseNumber(value: string): number {
    const parsed = Number.parseInt(value || '0', 10)
    return Number.isFinite(parsed) ? parsed : 0
  }
}
