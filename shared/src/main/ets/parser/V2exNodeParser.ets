import type { V2exNodeTopicsPageSnapshot } from '../network/NetworkTypes'
import { V2exTabParser } from './V2exTabParser'

export interface V2exFavoriteNode {
  name: string
  title: string
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
        const title = V2exNodeParser.compactText(m[2] || '')
        nodes.push({ name, title: title || name })
        seen.add(name)
      }
      m = linkRe.exec(html)
    }
    return nodes
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
