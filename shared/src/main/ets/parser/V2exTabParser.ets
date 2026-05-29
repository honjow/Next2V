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
    const topics: V2exTopic[] = []
    const cells = V2exTabParser.extractTopicCells(html || '')
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
    return V2exTabParser.extractTopicIds(html).map((id: number): V2exTopic => V2exTabParser.placeholderTopic(id))
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
    const ids: Set<number> = new Set()
    const topicLinkRegex = /id=["']topic-link-(\d+)["']/g
    let match: RegExpExecArray | null
    while ((match = topicLinkRegex.exec(html)) !== null) {
      ids.add(parseInt(match[1], 10))
    }
    if (ids.size > 0) {
      return Array.from(ids)
    }

    const regex = /\/t\/(\d+)/g
    while ((match = regex.exec(html)) !== null) {
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
    const nodeName = V2exTabParser.extractFirst(cell, /<a[^>]*class=["']node["'][^>]*href=["']\/go\/([^"']+)["'][^>]*>/i)
    const nodeTitle = V2exTabParser.extractFirst(cell, /<a[^>]*class=["']node["'][^>]*>[\s\S]*?([^<>]+)<\/a>/i)
    const replies = V2exTabParser.parseNumber(V2exTabParser.extractFirst(cell, /<a[^>]*class=["']count_[^"']*["'][^>]*>(\d+)<\/a>/i))
    const lastReplyBy = V2exTabParser.extractFirst(cell, /Last(?:ly)? replied by\s*<strong>\s*<a[^>]*\/member\/[^>]+>([^<]+)<\/a>/i)
    const titleTime = V2exTabParser.extractFirst(cell, /<span[^>]*title=["']([^"']+\+08:00)["'][^>]*>/i)
    const created = V2exTabParser.parseTimeSeconds(titleTime)

    const member: V2exMember = {
      id: uid,
      username: V2exTabParser.decode(username),
      tagline: '',
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
      replies: replies,
      member: member,
      node: node,
      created: created,
      last_modified: created,
      last_touched: created,
      last_reply_by: V2exTabParser.decode(lastReplyBy)
    }
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
