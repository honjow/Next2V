/**
 * V2EX 登录态 HTML 解析器
 * - 用于从需要登录的页面（如 /settings）提取当前用户名
 */
export class V2exSessionParser {
  /**
   * 从 HTML 中提取当前登录用户名（member name）
   * 典型形态: <a href="/member/xxx" class="top">xxx</a>
   */
  static extractUsername(html: string): string {
    if (!html) {
      return ''
    }
    const re = /<a\s+href=['"]\/member\/([0-9A-Za-z_]+)['"]\s+class=['"]top['"]\s*>/i
    const m = html.match(re)
    return m && m[1] ? m[1] : ''
  }
}
