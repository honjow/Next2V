/**
 * V2EX 登录态 HTML 解析器
 * - 用于从需要登录的页面（如 /settings）提取当前用户名
 */
export class V2exSessionParser {
  /**
   * 从 HTML 中提取当前登录用户名（member name）。
   * 典型形态: <a href="/member/xxx" class="top">xxx</a>
   * V2EX 页面属性顺序/额外属性可能变化，因此按完整 a 标签解析。
   */
  static extractUsername(html: string): string {
    if (!html) {
      return ''
    }

    const links = html.match(/<a\b[^>]*>/gi) || []
    for (const link of links) {
      const href = V2exSessionParser.extractAttr(link, 'href')
      const className = V2exSessionParser.extractAttr(link, 'class')
      const member = V2exSessionParser.memberNameFromHref(href)
      if (member && V2exSessionParser.hasClass(className, 'top')) {
        return member
      }
    }

    return ''
  }

  static extractUnreadNotificationCount(html: string): number {
    if (!html) {
      return 0
    }
    const linkRe = /<a\b[^>]*href\s*=\s*(['"])\/notifications(?:\?[^'"]*)?\1[^>]*>([\s\S]*?)<\/a>/gi
    let m: RegExpExecArray | null = linkRe.exec(html)
    while (m) {
      const text = V2exSessionParser.compactText(m[2] || '')
      const count = V2exSessionParser.extractFirstNumber(text)
      if (count > 0) {
        return count
      }
      m = linkRe.exec(html)
    }
    return 0
  }

  private static memberNameFromHref(href: string): string {
    if (!href) {
      return ''
    }
    const m = href.match(/^\/member\/([0-9A-Za-z_]+)(?:[?#].*)?$/)
    return m && m[1] ? m[1] : ''
  }

  private static hasClass(className: string, expected: string): boolean {
    if (!className || !expected) {
      return false
    }
    return className.split(/\s+/).some((part: string) => part === expected)
  }

  private static extractAttr(tag: string, attrName: string): string {
    const re = new RegExp(`${attrName}\\s*=\\s*(['"])(.*?)\\1`, 'i')
    const m = tag.match(re)
    return m && m[2] ? V2exSessionParser.decodeHtml(m[2]) : ''
  }

  private static extractFirstNumber(text: string): number {
    const m = (text || '').match(/\d+/)
    if (!m || !m[0]) {
      return 0
    }
    const value = Number.parseInt(m[0])
    return Number.isFinite(value) && value > 0 ? value : 0
  }

  private static compactText(html: string): string {
    return V2exSessionParser.decodeHtml(html.replace(/<script[\s\S]*?<\/script>/gi, ' ')
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
