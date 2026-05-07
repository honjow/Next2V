import type {
  V2exMemberActionState, V2exMemberPageSnapshot, V2exMemberRepliesPageSnapshot, V2exMemberTopicsPageSnapshot,
  V2exUserReply
} from '../network/NetworkTypes'
import { V2exTabParser } from './V2exTabParser'

interface ReplyMeta {
  topicId: number
  topicTitle: string
  targetFloor: number
  nodeName: string
  nodeTitle: string
  topicAuthor: string
  created: number
}

interface TimeMeta {
  created: number
  text: string
}

interface ParsedNodeRef {
  name: string
  title: string
}

interface ParsedTopicRef {
  id: number
  title: string
  floor: number
}

export class V2exMemberPageParser {
  static parse(html: string, username: string): V2exMemberPageSnapshot {
    return {
      topicIds: V2exMemberPageParser.extractVisibleTopicIds(html),
      topicsHidden: V2exMemberPageParser.extractTopicsHidden(html),
      replies: V2exMemberPageParser.extractRecentReplies(html),
      actions: V2exMemberPageParser.extractActionState(html, username)
    }
  }

  static parseTopicsPage(html: string): V2exMemberTopicsPageSnapshot {
    return {
      topicIds: V2exMemberPageParser.extractVisibleTopicIds(html),
      topicsHidden: V2exMemberPageParser.extractTopicsHidden(html),
      hasMore: V2exMemberPageParser.extractHasMore(html)
    }
  }

  static parseRepliesPage(html: string): V2exMemberRepliesPageSnapshot {
    return {
      replies: V2exMemberPageParser.extractRecentReplies(html),
      hasMore: V2exMemberPageParser.extractHasMore(html)
    }
  }

  static extractTopicsHidden(html: string): boolean {
    return /主题列表被隐藏|topics list is hidden|topics list.*hidden/i.test(html || '')
  }

  static extractHasMore(html: string): boolean {
    const clean = html || ''
    const currentMatch = clean.match(/<a[^>]*class=['"][^'"]*page_current[^'"]*['"][^>]*>(\d+)<\/a>/i)
    if (currentMatch && currentMatch[1]) {
      const current = Number.parseInt(currentMatch[1], 10)
      const pageRe = /[?&]p=(\d+)/gi
      let max = current
      let m: RegExpExecArray | null = pageRe.exec(clean)
      while (m) {
        const page = Number.parseInt(m[1] || '0', 10)
        if (page > max) {
          max = page
        }
        m = pageRe.exec(clean)
      }
      return max > current
    }
    return /[?&]p=2/i.test(clean)
  }

  static extractVisibleTopicIds(html: string): number[] {
    if (!html) {
      return []
    }
    const marker = html.indexOf('cell_tabs')
    const recentReplies = V2exMemberPageParser.findRepliesSectionStart(html)
    const start = marker >= 0 ? marker : 0
    const end = recentReplies > start ? recentReplies : html.length
    return V2exTabParser.extractTopicIds(html.slice(start, end))
  }

  static extractRecentReplies(html: string): V2exUserReply[] {
    if (!html) {
      return []
    }
    const sectionStart = V2exMemberPageParser.findRepliesSectionStart(html)
    if (sectionStart < 0) {
      return V2exMemberPageParser.extractRepliesFromSection(html)
    }
    const section = html.slice(sectionStart)
    return V2exMemberPageParser.extractRepliesFromSection(section)
  }

  private static extractRepliesFromSection(section: string): V2exUserReply[] {
    const replies: V2exUserReply[] = []
    const re = /(<div[^>]*class=['"][^'"]*\bdock_area\b[^'"]*['"][^>]*>[\s\S]*?)<div[^>]*class=['"][^'"]*\binner\b[^'"]*['"][^>]*>\s*<div[^>]*class=['"][^'"]*\breply_content\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>\s*<\/div>/gi
    let m: RegExpExecArray | null = re.exec(section)
    while (m) {
      const meta = V2exMemberPageParser.extractReplyMeta(m[1] || '')
      if (meta.topicId > 0) {
        replies.push({
          topic_id: meta.topicId,
          topic_title: meta.topicTitle,
          target_floor: meta.targetFloor,
          node_name: meta.nodeName,
          node_title: meta.nodeTitle,
          topic_author: meta.topicAuthor,
          content: V2exMemberPageParser.replyHtmlToMarkdown(m[2] || ''),
          created: meta.created
        })
      }
      m = re.exec(section)
    }
    return replies
  }

  private static findRepliesSectionStart(html: string): number {
    return (html || '').search(/最近回复|recent replies/i)
  }

  static extractActionState(html: string, username: string): V2exMemberActionState | null {
    if (!html || !username) {
      return null
    }
    const memberId = V2exMemberPageParser.extractMemberId(html)
    const followOff = V2exMemberPageParser.findActionPath(html, 'unfollow', username) ||
      V2exMemberPageParser.findMemberIdActionPath(html, 'unfollow', memberId)
    const followOn = V2exMemberPageParser.findActionPath(html, 'follow', username) ||
      V2exMemberPageParser.findMemberIdActionPath(html, 'follow', memberId)
    const blockOff = V2exMemberPageParser.findActionPath(html, 'unblock', username) ||
      V2exMemberPageParser.findMemberIdActionPath(html, 'unblock', memberId)
    const blockOn = V2exMemberPageParser.findActionPath(html, 'block', username) ||
      V2exMemberPageParser.findMemberIdActionPath(html, 'block', memberId)
    if (!followOff && !followOn && !blockOff && !blockOn) {
      return null
    }
    return {
      following: followOff.length > 0,
      followPath: followOff || followOn,
      blocked: blockOff.length > 0,
      blockPath: blockOff || blockOn
    }
  }

  private static extractDockArea(block: string): string {
    const m = (block || '').match(/<div class=['"]dock_area['"]>([\s\S]*?)<\/div>/i)
    return m && m[1] ? m[1] : block
  }

  private static extractReplyMeta(dock: string): ReplyMeta {
    const time = V2exMemberPageParser.extractCreated(dock)
    const author = V2exMemberPageParser.extractLinkText(dock, /href=['"]\/member\/([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/i)
    const node = V2exMemberPageParser.extractNode(dock)
    const topic = V2exMemberPageParser.extractTopic(dock)
    return {
      topicId: topic.id,
      topicTitle: topic.title,
      targetFloor: topic.floor,
      nodeName: node.name,
      nodeTitle: node.title,
      topicAuthor: author,
      created: time.created
    }
  }

  private static extractNode(html: string): ParsedNodeRef {
    const m = (html || '').match(/href=['"]\/go\/([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/i)
    if (!m) {
      return { name: '', title: '' }
    }
    return {
      name: V2exMemberPageParser.decodeHtml(m[1] || ''),
      title: V2exMemberPageParser.compactText(m[2] || '')
    }
  }

  private static extractTopic(html: string): ParsedTopicRef {
    const m = (html || '').match(/href=['"]\/t\/(\d+)(#[^'"]*)?['"][^>]*>([\s\S]*?)<\/a>/i)
    if (!m) {
      return { id: 0, title: '', floor: 0 }
    }
    return {
      id: Number.parseInt(m[1] || '0'),
      title: V2exMemberPageParser.compactText(m[3] || ''),
      floor: V2exMemberPageParser.extractTargetFloor(m[2] || '')
    }
  }

  private static extractTargetFloor(fragment: string): number {
    const m = (fragment || '').match(/#(?:reply|r_?)(\d+)/i) || (fragment || '').match(/#(\d+)/)
    if (!m || !m[1]) {
      return 0
    }
    const parsed = Number.parseInt(m[1], 10)
    return Number.isFinite(parsed) ? parsed : 0
  }

  private static extractCreated(html: string): TimeMeta {
    const m = (html || '').match(/<span[^>]*title=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/span>/i)
    if (m && m[1]) {
      const created = V2exMemberPageParser.parseAbsoluteTime(m[1])
      if (created > 0) {
        return { created, text: V2exMemberPageParser.compactText(m[2] || '') }
      }
    }
    return { created: 0, text: '' }
  }

  private static parseAbsoluteTime(text: string): number {
    const m = (text || '').match(/(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/)
    if (!m) {
      return 0
    }
    const d = new Date(
      Number.parseInt(m[1] || '0'),
      Number.parseInt(m[2] || '1') - 1,
      Number.parseInt(m[3] || '1'),
      Number.parseInt(m[4] || '0'),
      Number.parseInt(m[5] || '0'),
      Number.parseInt(m[6] || '0')
    )
    return Math.floor(d.getTime() / 1000)
  }

  private static findActionPath(html: string, action: string, username: string): string {
    const escapedUser = V2exMemberPageParser.escapeRegExp(username)
    const re = new RegExp(`href=['"]([^'"]*\\/${action}\\/(?:member\\/)?${escapedUser}[^'"]*)['"]`, 'i')
    const m = html.match(re)
    return m && m[1] ? V2exMemberPageParser.decodeHtml(m[1]) : ''
  }

  private static findMemberIdActionPath(html: string, action: string, memberId: number): string {
    if (memberId <= 0) {
      return ''
    }
    const direct = new RegExp(`['"]([^'"]*\\/${action}\\/${memberId}\\?once=\\d+[^'"]*)['"]`, 'i')
    const directMatch = (html || '').match(direct)
    if (directMatch && directMatch[1]) {
      return V2exMemberPageParser.decodeHtml(directMatch[1])
    }
    const actionBlock = new RegExp(`<input[^>]+onclick=['"][^'"]*\\/${action}\\/${memberId}\\?once=(\\d+)[^'"]*['"][^>]*>`, 'i')
    const actionMatch = (html || '').match(actionBlock)
    if (actionMatch && actionMatch[1]) {
      return `/${action}/${memberId}?once=${actionMatch[1]}`
    }
    return ''
  }

  private static extractMemberId(html: string): number {
    const clean = html || ''
    const numberText =
      (clean.match(/V2EX\s*第\s*(\d+)\s*号/i) || clean.match(/第\s*(\d+)\s*号会员/i) || clean.match(/member_id['"]?\s*[:=]\s*['"]?(\d+)/i))
    if (!numberText || !numberText[1]) {
      return 0
    }
    const parsed = Number.parseInt(numberText[1], 10)
    return Number.isFinite(parsed) ? parsed : 0
  }

  private static extractLinkText(html: string, re: RegExp): string {
    const m = (html || '').match(re)
    if (!m) {
      return ''
    }
    return V2exMemberPageParser.compactText(m[2] || m[1] || '')
  }

  private static replyHtmlToMarkdown(html: string): string {
    return V2exMemberPageParser.decodeHtml((html || '')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/@?\s*<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>[\s\S]*?<\/a>/gi, '[@$1](/member/$1)')
      .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)')
      .replace(/<[^>]+>/g, ''))
      .replace(/\n{3,}/g, '\n\n')
      .trim()
  }

  private static compactText(html: string): string {
    return V2exMemberPageParser.decodeHtml((html || '').replace(/<[^>]+>/g, ' '))
      .replace(/\s+/g, ' ')
      .trim()
  }

  private static decodeHtml(value: string): string {
    return (value || '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&nbsp;/g, ' ')
  }

  private static escapeRegExp(value: string): string {
    return (value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  }
}
