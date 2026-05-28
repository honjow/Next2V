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
      if (nodes.length > 0) {
        sections.push({ title: V2exNodeParser.normalizeNavigationSectionTitle(V2exNodeParser.extractNavigationSectionTitle(box) || '节点导航'), nodes: nodes })
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
    if (!html || html.indexOf('节点导航') < 0) {
      return []
    }
    const markerIndex = html.indexOf('节点导航')
    const source = html.slice(markerIndex)
    const sections: V2exNodeNavigationSection[] = []
    const cellRe = /<div class=['"]cell['"][^>]*>\s*<table[\s\S]*?<tr>\s*<td[^>]*>\s*<span[^>]+class=['"][^'"]*fade[^'"]*['"][^>]*>([\s\S]*?)<\/span>\s*<\/td>\s*<td[\s\S]*?>([\s\S]*?)<\/td>\s*<\/tr>\s*<\/table>\s*<\/div>/gi
    let cellMatch: RegExpExecArray | null = cellRe.exec(source)
    while (cellMatch) {
      const title = V2exNodeParser.normalizeNavigationSectionTitle(V2exNodeParser.compactText(cellMatch[1] || ''))
      const nodes = V2exNodeParser.extractFavoriteNodes(cellMatch[2] || '').map((node: V2exFavoriteNode): V2exFavoriteNode => {
        return { name: node.name, title: node.title }
      })
      if (title && title !== '节点导航' && nodes.length > 0) {
        sections.push({ title: title, nodes: nodes })
      }
      cellMatch = cellRe.exec(source)
    }
    return sections
  }

  private static normalizeNavigationSectionTitle(title: string): string {
    const clean = (title || '').trim()
    if (clean === 'Hottest Nodes') {
      return '最热节点'
    }
    return clean
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
