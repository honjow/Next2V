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

  private static decodeHtml(value: string): string {
    return value
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }
}
