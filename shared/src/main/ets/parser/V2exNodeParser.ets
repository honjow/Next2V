import type { V2exNodeTopicsPageSnapshot } from '../network/NetworkTypes'
import { V2exTabParser } from './V2exTabParser'

export interface V2exFavoriteNode {
  name: string
  title: string
  topics?: number
  avatarMini?: string
  avatarNormal?: string
  avatarLarge?: string
  avatarXLarge?: string
}

export interface V2exNodeNavigationSection {
  title: string
  titleKey?: string
  nodes: V2exFavoriteNode[]
}

/**
 * V2EX 节点相关 HTML 解析器
 * - 当前用于解析 /my/nodes 的收藏节点列表
 */
export class V2exNodeParser {
  static parseNodeTopicsPage(html: string): V2exNodeTopicsPageSnapshot {
    return {
      topicIds: V2exTabParser.extractTopicIds(html || ''),
      hasMore: V2exNodeParser.extractHasMore(html || '')
    }
  }

  /**
   * 从 /my/nodes HTML 中提取收藏节点（name + title）
   */
  static extractFavoriteNodes(html: string): V2exFavoriteNode[] {
    if (!html) {
      return []
    }
    const nodes: V2exFavoriteNode[] = []
    const seen: Set<string> = new Set()
    const linkRe = /<a[^>]+href=['"]\/go\/([a-zA-Z0-9_-]+)['"][^>]*>([\s\S]*?)<\/a>/gi
    let m: RegExpExecArray | null = linkRe.exec(html)
    while (m) {
      const name = (m[1] || '').trim()
      if (name && !seen.has(name)) {
        const parsed = V2exNodeParser.extractNodeTitleParts(V2exNodeParser.compactText(m[2] || ''), name)
        nodes.push(parsed)
        seen.add(name)
      }
      m = linkRe.exec(html)
    }
    return nodes
  }

  static extractNodeNavigationSections(html: string): V2exNodeNavigationSection[] {
    if (!html) {
      return []
    }
    const sections: V2exNodeNavigationSection[] = []
    const boxRe = /<div class=['"]box['"][^>]*>([\s\S]*?)<\/div>\s*(?:<div class=['"]sep20['"]><\/div>|<div class=['"]sep['"]><\/div>)/gi
    let boxMatch: RegExpExecArray | null = boxRe.exec(html)
    while (boxMatch) {
      const box = boxMatch[1] || ''
      const nodes = V2exNodeParser.extractFavoriteNodes(box).map((node: V2exFavoriteNode): V2exFavoriteNode => {
        return { name: node.name, title: node.title }
      })
      const title = V2exNodeParser.extractNavigationSectionTitle(box)
      const titleKey = V2exNodeParser.homeNavigationSectionTitleKey(title)
      if (title && titleKey && nodes.length > 0) {
        sections.push({ title: title, titleKey: titleKey, nodes: nodes })
      }
      boxMatch = boxRe.exec(html)
    }
    return sections
  }

  private static extractNavigationSectionTitle(html: string): string {
    const titleMatch = html.match(/<span[^>]+class=['"][^'"]*(?:fade|gray)[^'"]*['"][^>]*>([\s\S]*?)<\/span>/i)
    if (!titleMatch) {
      return ''
    }
    return V2exNodeParser.compactText(titleMatch[1] || '')
  }

  static extractStructuredNodeNavigationSections(html: string): V2exNodeNavigationSection[] {
    if (!html) {
      return []
    }
    const sections: V2exNodeNavigationSection[] = []
    const rowContainers = V2exNodeParser.extractNodeNavigationRowContainers(html)
    for (let i = 0; i < rowContainers.length; i++) {
      const section = V2exNodeParser.extractNodeNavigationRow(rowContainers[i] || '')
      if (section) {
        sections.push(section)
      }
    }
    return sections
  }

  private static extractNodeNavigationRow(cellHtml: string): V2exNodeNavigationSection | null {
    if (!cellHtml || cellHtml.indexOf('<table') < 0 || cellHtml.indexOf('/go/') < 0) {
      return null
    }
    const firstRow = V2exNodeParser.extractFirstTagBlock(cellHtml, 'tr')
    if (!firstRow) {
      return null
    }
    const cells = V2exNodeParser.extractTagBlocks(firstRow, 'td')
    if (cells.length < 2) {
      return null
    }
    const title = V2exNodeParser.extractNavigationRowTitle(cells[0] || '')
    if (!title) {
      return null
    }
    let linksHtml = ''
    for (let i = 1; i < cells.length; i++) {
      linksHtml += cells[i] || ''
    }
    const nodes = V2exNodeParser.extractFavoriteNodes(linksHtml).map((node: V2exFavoriteNode): V2exFavoriteNode => {
      return { name: node.name, title: node.title }
    })
    if (nodes.length === 0) {
      return null
    }
    return { title: title, nodes: nodes }
  }

  private static extractNavigationRowTitle(html: string): string {
    const spanBlocks = V2exNodeParser.extractTagBlocks(html, 'span')
    for (let i = 0; i < spanBlocks.length; i++) {
      const span = spanBlocks[i] || ''
      if (V2exNodeParser.tagHasClass(span, 'fade')) {
        return V2exNodeParser.compactText(span)
      }
    }
    return ''
  }

  private static extractNodeNavigationRowContainers(html: string): string[] {
    const containers: string[] = []
    if (!html) {
      return containers
    }
    const divStartRe = /<div\b[^>]*>/gi
    let match: RegExpExecArray | null = divStartRe.exec(html)
    while (match) {
      const openTag = match[0] || ''
      const start = match.index
      if (V2exNodeParser.tagHasClass(openTag, 'cell') || V2exNodeParser.tagHasClass(openTag, 'inner')) {
        const end = V2exNodeParser.findMatchingTagEnd(html, 'div', start)
        if (end > start) {
          containers.push(html.slice(start, end))
          divStartRe.lastIndex = end
        }
      }
      match = divStartRe.exec(html)
    }
    return containers
  }

  private static extractFirstTagBlock(html: string, tagName: string): string {
    const blocks = V2exNodeParser.extractTagBlocks(html, tagName)
    return blocks.length > 0 ? (blocks[0] || '') : ''
  }

  private static extractTagBlocks(html: string, tagName: string): string[] {
    const blocks: string[] = []
    if (!html || !tagName) {
      return blocks
    }
    const tagRe = new RegExp(`<\\/?${tagName}\\b[^>]*>`, 'gi')
    let match: RegExpExecArray | null = tagRe.exec(html)
    while (match) {
      const tag = match[0] || ''
      const start = match.index
      if (!tag.startsWith('</')) {
        const end = V2exNodeParser.findMatchingTagEnd(html, tagName, start)
        if (end > start) {
          blocks.push(html.slice(start, end))
          tagRe.lastIndex = end
        }
      }
      match = tagRe.exec(html)
    }
    return blocks
  }

  private static findMatchingTagEnd(html: string, tagName: string, start: number): number {
    const tagRe = new RegExp(`<\\/?${tagName}\\b[^>]*>`, 'gi')
    tagRe.lastIndex = Math.max(0, start)
    let depth = 0
    let match: RegExpExecArray | null = tagRe.exec(html)
    while (match) {
      const tag = match[0] || ''
      if (tag.startsWith('</')) {
        depth--
        if (depth === 0) {
          return tagRe.lastIndex
        }
      } else if (!tag.endsWith('/>')) {
        depth++
      }
      match = tagRe.exec(html)
    }
    return -1
  }

  private static tagHasClass(tagHtml: string, className: string): boolean {
    const firstTagEnd = tagHtml.indexOf('>')
    const firstTag = firstTagEnd >= 0 ? tagHtml.slice(0, firstTagEnd + 1) : tagHtml
    const classMatch = firstTag.match(/\sclass=['\"]([^'\"]*)['\"]/i)
    if (!classMatch) {
      return false
    }
    const classes = (classMatch[1] || '').split(/\s+/)
    return classes.indexOf(className) >= 0
  }

  private static homeNavigationSectionTitleKey(title: string): string {
    const clean = (title || '').trim()
    switch (clean) {
      case 'Hottest Nodes':
        return 'discover_node_navigation_hottest'
      case 'Recently Created':
      case 'Recently Created Nodes':
        return 'discover_node_navigation_recently_created'
      default:
        return ''
    }
  }

  private static extractNodeTitleParts(text: string, name: string): V2exFavoriteNode {
    const clean = (text || '').trim()
    const match = clean.match(/^(.+?)\s+(\d{2,})$/)
    if (match) {
      return {
        name: name,
        title: (match[1] || name).trim(),
        topics: Number.parseInt(match[2] || '0', 10)
      }
    }
    return { name: name, title: clean || name }
  }

  private static extractHasMore(html: string): boolean {
    const currentMatch = html.match(/<a[^>]*class=['"][^'"]*page_current[^'"]*['"][^>]*>(\d+)<\/a>/i)
    if (currentMatch && currentMatch[1]) {
      const current = Number.parseInt(currentMatch[1], 10)
      const pageRe = /[?&]p=(\d+)/gi
      let max = current
      let m: RegExpExecArray | null = pageRe.exec(html)
      while (m) {
        const page = Number.parseInt(m[1] || '0', 10)
        if (page > max) {
          max = page
        }
        m = pageRe.exec(html)
      }
      return max > current
    }
    return /[?&]p=2/i.test(html)
  }

  private static compactText(html: string): string {
    return V2exNodeParser.decodeHtml(html.replace(/<script[\s\S]*?<\/script>/gi, ' ')
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
