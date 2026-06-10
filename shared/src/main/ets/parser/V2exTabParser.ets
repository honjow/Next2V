import type { V2exMember, V2exNode, V2exTopic } from '../network/NetworkTypes'
import { HtmlEntityUtils } from '../utils/HtmlEntityUtils'
import { V2exUrlRouter } from '../utils/V2exUrlRouter'
import { HttpClient } from '../network/HttpClient'

export interface V2exBlockedIdLists {
  ignoredTopicIds: number[]
  blockedMemberIds: number[]
  ignoredTopicsPresent: boolean
  blockedMembersPresent: boolean
  ignoredRawLength: number
  blockedRawLength: number
}

interface V2exJsNumberArrayExtraction {
  ids: number[]
  present: boolean
  rawLength: number
}

/**
 * V2EX 首页 HTML 解析器
 * 从 /?tab=xxx 的 HTML 页面中提取主题列表 / ID 列表。
 */
export class V2exTabParser {
  static parseTopicList(html: string): V2exTopic[] {
    // Strip <script>/<style>/comments FIRST. V2EX's lscache topic-read tracker embeds an example link in a
    // JS comment — `// href is something like "/t/1234#reply567"` — and the placeholder fallback below used
    // to match that `/t/1234`, producing a bogus empty-title topic that navigated to an unrelated topic
    // (seen on nodes whose real rows didn't parse, e.g. ServerCC). Stripping non-content removes the trap.
    const clean = V2exTabParser.stripNonContent(html || '')
    const topics: V2exTopic[] = []
    const cells = V2exTabParser.extractTopicCells(clean)
    const seen: Set<number> = new Set()
    for (const cell of cells) {
      const topic = V2exTabParser.parseTopicCell(cell)
      if (topic && !seen.has(topic.id)) {
        seen.add(topic.id)
        topics.push(topic)
      }
    }
    if (topics.length > 0) {
      return topics
    }
    // Empty main list: fall back ONLY to main-row topic-link ids, never the broad
    // /t/NNN scoop in extractTopicIds(). On an empty hot tab the main feed has no
    // topic-link rows, but the page still carries `/t/NNN` links in the right
    // sidebar ("今日热议主题") — scooping those produced ghost placeholder topics
    // (no title/author/node) in 最热 when the site's daily hot list was still empty.
    return V2exTabParser.extractMainFeedTopicLinkIds(clean).map((id: number): V2exTopic => V2exTabParser.placeholderTopic(id))
  }

  // Main-feed topic ids only (id="topic-link-NNN"); deliberately omits the
  // /t/NNN fallback so the right-sidebar hot-topic widget can never leak into a
  // tab feed. extractTopicIds() keeps that fallback for member/node parsing.
  private static extractMainFeedTopicLinkIds(clean: string): number[] {
    const ids: Set<number> = new Set()
    const topicLinkRegex = /id=["']topic-link-(\d+)["']/g
    let match: RegExpExecArray | null = topicLinkRegex.exec(clean)
    while (match !== null) {
      ids.add(parseInt(match[1], 10))
      match = topicLinkRegex.exec(clean)
    }
    return Array.from(ids)
  }

  // Remove scripts, styles, and HTML comments so topic-id extraction never picks up `/t/NNN` references
  // that live in tracking JS or comments rather than the real topic list.
  private static stripNonContent(html: string): string {
    return (html || '')
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
      .replace(/<!--[\s\S]*?-->/g, ' ')
  }

  /** Extract login-state ignored topic IDs and blocked member IDs from V2EX topic-list scripts. */
  static extractBlockedIdLists(html: string): V2exBlockedIdLists {
    const ignoredTopics = V2exTabParser.extractJsNumberArray(html || '', 'ignored_topics')
    const blockedMembers = V2exTabParser.extractJsNumberArray(html || '', 'blocked')
    return {
      ignoredTopicIds: ignoredTopics.ids,
      blockedMemberIds: blockedMembers.ids,
      ignoredTopicsPresent: ignoredTopics.present,
      blockedMembersPresent: blockedMembers.present,
      ignoredRawLength: ignoredTopics.rawLength,
      blockedRawLength: blockedMembers.rawLength,
    }
  }

  /**
   * 从 HTML 中提取主题 ID 列表
   * 优先匹配主列表里的 topic-link，避免右栏热门主题污染不同 tab 的结果。
   */
  static extractTopicIds(html: string): number[] {
    // Strip non-content so the `/t/NNN` fallback never matches tracking-JS / comment links.
    const clean = V2exTabParser.stripNonContent(html)
    const ids: Set<number> = new Set()
    const topicLinkRegex = /id=["']topic-link-(\d+)["']/g
    let match: RegExpExecArray | null
    while ((match = topicLinkRegex.exec(clean)) !== null) {
      ids.add(parseInt(match[1], 10))
    }
    if (ids.size > 0) {
      return Array.from(ids)
    }

    const regex = /\/t\/(\d+)/g
    while ((match = regex.exec(clean)) !== null) {
      ids.add(parseInt(match[1], 10))
    }
    return Array.from(ids)
  }

  /**
   * 验证提取结果是否合理
   * V2EX 首页正常每页约 20 条
   */
  static isValid(ids: number[]): boolean {
    return ids.length > 0 && ids.length <= 100
  }

  // Whether the list page has a page AFTER the current one — read from the pagination footer
  // (page_current + the highest ?p=N), NOT from a per-page item count. The favorites page
  // (/my/topics) returns fewer items per page than a tab feed's 20, so a `count >= 20` heuristic
  // wrongly stops after page 1. Mirrors V2exNodeParser.extractHasMore.
  static hasNextPage(html: string): boolean {
    const clean = V2exTabParser.stripNonContent(html || '')
    const currentMatch = clean.match(/<a[^>]*class=['"][^'"]*page_current[^'"]*['"][^>]*>(\d+)<\/a>/i)
    if (currentMatch && currentMatch[1]) {
      const current = parseInt(currentMatch[1], 10)
      const pageRe = /[?&]p=(\d+)/gi
      let max = current
      let m: RegExpExecArray | null = pageRe.exec(clean)
      while (m !== null) {
        const page = parseInt(m[1] || '0', 10)
        if (page > max) {
          max = page
        }
        m = pageRe.exec(clean)
      }
      return max > current
    }
    return /[?&]p=2/i.test(clean)
  }

  static hasMoreRecentTopicsLink(html: string): boolean {
    const clean = V2exTabParser.stripNonContent(html || '')
    return /<a\b[^>]*href=["']\/recent(?:[?#][^"']*)?["'][^>]*>[\s\S]*?<\/a>/i.test(clean)
  }

  private static extractJsNumberArray(html: string, variableName: string): V2exJsNumberArrayExtraction {
    if (!html || !variableName) {
      return { ids: [], present: false, rawLength: 0 }
    }
    const pattern = new RegExp('(?:^|[^0-9A-Za-z_])' + variableName + '\\s*=\\s*\\[([^\\]]*)\\]', 'm')
    const match = html.match(pattern)
    if (!match || match.length < 2) {
      return { ids: [], present: false, rawLength: 0 }
    }
    const ids: number[] = []
    const seen: Set<number> = new Set()
    const valueRegex = /(?:^|[^\d-])(\d+)/g
    let valueMatch: RegExpExecArray | null
    const raw = match[1] || ''
    while ((valueMatch = valueRegex.exec(raw)) !== null) {
      const id = parseInt(valueMatch[1], 10)
      if (id > 0 && !seen.has(id)) {
        ids.push(id)
        seen.add(id)
      }
    }
    return { ids: ids, present: true, rawLength: raw.length }
  }

  private static extractTopicCells(html: string): string[] {
    const cells: string[] = []
    const cellRegex = /<div\s+class=["']cell(?:\s+item|[^"']*\bt_\d+\b)[^"']*["'][\s\S]*?(?=<div\s+class=["']cell(?:\s+item|[^"']*\bt_\d+\b)[^"']*["']|<\/div>\s*<\/div>\s*<div\s+class=["']inner["']|<\/body>)/gi
    let match: RegExpExecArray | null
    while ((match = cellRegex.exec(html)) !== null) {
      const cell = match[0] || ''
      if (cell.indexOf('topic-link-') >= 0) {
        cells.push(cell)
      }
    }
    return cells
  }

  private static parseTopicCell(cell: string): V2exTopic | null {
    const linkMatch = cell.match(/<a[^>]*id=["']topic-link-(\d+)["'][^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i) ||
      cell.match(/<a[^>]*href=["']([^"']*\/t\/(\d+)[^"']*)["'][^>]*id=["']topic-link-\d+["'][^>]*>([\s\S]*?)<\/a>/i)
    if (!linkMatch) {
      return null
    }
    let id = 0
    let href = ''
    let title = ''
    if ((linkMatch[1] || '').indexOf('/t/') >= 0) {
      href = linkMatch[1] || ''
      id = parseInt(linkMatch[2] || '0', 10)
      title = linkMatch[3] || ''
    } else {
      id = parseInt(linkMatch[1] || '0', 10)
      href = linkMatch[2] || ''
      title = linkMatch[3] || ''
    }
    if (id <= 0) {
      return null
    }

    const avatarMatch = cell.match(/<img[^>]*class=["']avatar["'][^>]*>/i)
    const avatarTag = avatarMatch ? avatarMatch[0] : ''
    const username = V2exTabParser.extractAttr(avatarTag, 'alt') || V2exTabParser.extractFirst(cell, /\/member\/([^"'\s<>]+)/i)
    const uid = V2exTabParser.parseNumber(V2exTabParser.extractAttr(avatarTag, 'data-uid'))
    const avatar = V2exUrlRouter.withSelectedBaseUrl(V2exTabParser.extractAttr(avatarTag, 'src'), HttpClient.getInstance().getBaseUrl())
    const cleanUsername = V2exTabParser.decode(username)
    const nodeName = V2exTabParser.extractFirst(cell, /<a[^>]*class=["']node["'][^>]*href=["']\/go\/([^"']+)["'][^>]*>/i)
    const nodeTitle = V2exTabParser.extractFirst(cell, /<a[^>]*class=["']node["'][^>]*>[\s\S]*?([^<>]+)<\/a>/i)
    const replies = V2exTabParser.parseNumber(V2exTabParser.extractFirst(cell, /<a[^>]*class=["']count_[^"']*["'][^>]*>(\d+)<\/a>/i))
    const lastReplyBy = V2exTabParser.extractLastReplyBy(cell)
    const titleTime = V2exTabParser.extractFirst(cell, /<span[^>]*title=["']([^"']+\+08:00)["'][^>]*>/i)
    const created = V2exTabParser.parseTimeSeconds(titleTime)

    const member: V2exMember = {
      id: uid,
      username: cleanUsername,
      tagline: '',
      pro: V2exTabParser.hasMemberRole(cell, cleanUsername, 'PRO') ? 1 : 0,
      mod: V2exTabParser.hasMemberRole(cell, cleanUsername, 'MOD') ? 1 : 0,
      avatar_mini: avatar,
      avatar_normal: avatar,
      avatar_large: avatar
    }
    const node: V2exNode = {
      id: 0,
      name: V2exTabParser.decode(nodeName),
      title: V2exTabParser.decode(nodeTitle || nodeName),
      title_alternative: '',
      url: nodeName ? V2exUrlRouter.withSelectedBaseUrl(`/go/${nodeName}`, HttpClient.getInstance().getBaseUrl()) : '',
      topics: 0,
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
    return {
      id: id,
      title: V2exTabParser.decode(title),
      url: V2exUrlRouter.withSelectedBaseUrl(href.split('#')[0], HttpClient.getInstance().getBaseUrl()),
      content: '',
      content_rendered: '',
      pinned: V2exTabParser.isPinnedTopicCell(cell) ? 1 : 0,
      replies: replies,
      member: member,
      node: node,
      created: created,
      last_modified: created,
      last_touched: created,
      last_reply_by: V2exTabParser.decode(lastReplyBy)
    }
  }

  private static isPinnedTopicCell(cell: string): boolean {
    return /corner_star\.png/i.test(cell || '')
  }

  private static hasMemberRole(html: string, username: string, role: string): boolean {
    const cleanUsername = (username || '').trim()
    const cleanRole = (role || '').trim()
    if (!cleanUsername || !cleanRole) {
      return false
    }
    const escapedUsername = cleanUsername.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const memberLink = new RegExp(`<a\\b[^>]*href=["'][^"']*\\/member\\/${escapedUsername}(?:[?#][^"']*)?["'][^>]*>[\\s\\S]*?<\\/a>`, 'gi')
    const escapedRole = cleanRole.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const rolePattern = new RegExp(`(?:^|\\s)${escapedRole}(?:\\s|$)`, 'i')
    const roleClassPattern = new RegExp(`class=["'][^"']*(?:\\bbadge\\b[^"']*\\b${escapedRole}\\b|\\b${escapedRole}\\b[^"']*\\bbadge\\b)[^"']*["']`, 'i')
    let match: RegExpExecArray | null = memberLink.exec(html || '')
    while (match !== null) {
      const linkHtml = match[0] || ''
      if (!/<img\b/i.test(linkHtml)) {
        const start = match.index + linkHtml.length
        const nearby = (html || '').slice(start, Math.min((html || '').length, start + 220))
        const text = HtmlEntityUtils.decode(nearby.replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ')
        if (roleClassPattern.test(nearby) || rolePattern.test(text)) {
          return true
        }
      }
      match = memberLink.exec(html || '')
    }
    return false
  }

  private static extractLastReplyBy(cell: string): string {
    const match = (cell || '').match(/(?:Last(?:ly)?\s+replied\s+by|最后回复(?:来自|由)?)[\s\S]*?<a[^>]*href=["'][^"']*\/member\/([^"'?#\s<>]+)(?:[?#][^"']*)?["'][^>]*>([\s\S]*?)<\/a>/i)
    if (match && match[2]) {
      return V2exTabParser.decode(match[2])
    }
    if (match && match[1]) {
      return V2exTabParser.decode(match[1])
    }
    return ''
  }

  private static placeholderTopic(id: number): V2exTopic {
    return {
      id: id,
      title: '',
      url: V2exUrlRouter.withSelectedBaseUrl(`/t/${id}`, HttpClient.getInstance().getBaseUrl()),
      content: '',
      content_rendered: '',
      replies: 0,
      member: { id: 0, username: '', tagline: '', avatar_mini: '', avatar_normal: '', avatar_large: '' },
      node: { id: 0, name: '', title: '', title_alternative: '', url: '', topics: 0, avatar_mini: '', avatar_normal: '', avatar_large: '' },
      created: 0,
      last_modified: 0,
      last_touched: 0
    }
  }

  private static extractAttr(tag: string, attr: string): string {
    const escaped = attr.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const match = tag.match(new RegExp(`${escaped}=["']([^"']*)["']`, 'i'))
    return match && match[1] ? V2exTabParser.decode(match[1]) : ''
  }

  private static extractFirst(text: string, pattern: RegExp): string {
    const match = text.match(pattern)
    return match && match[1] ? V2exTabParser.decode(match[1]) : ''
  }

  private static parseNumber(value: string): number {
    const n = parseInt((value || '').replace(/[^0-9]/g, ''), 10)
    return Number.isFinite(n) ? n : 0
  }

  private static parseTimeSeconds(value: string): number {
    const clean = (value || '').trim()
    if (!clean) {
      return 0
    }
    const timestamp = Date.parse(clean.replace(' +08:00', '+08:00'))
    if (!Number.isFinite(timestamp)) {
      return 0
    }
    return Math.floor(timestamp / 1000)
  }

  private static decode(value: string): string {
    return HtmlEntityUtils.decode((value || '').replace(/<[^>]+>/g, '').trim())
  }
}
