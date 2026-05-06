export interface V2exFavoriteNode {
  name: string
  title: string
}

/**
 * V2EX 节点相关 HTML 解析器
 * - 当前用于解析 /my/nodes 的收藏节点列表
 */
export class V2exNodeParser {
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

