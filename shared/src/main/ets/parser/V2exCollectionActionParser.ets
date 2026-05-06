export interface V2exToggleAction {
  /** 当前是否处于已开启状态（例如：已收藏/已关注） */
  currentlyOn: boolean
  /** 直接访问即可切换状态的站内路径（例如：/favorite/... 或 /unfavorite/...） */
  actionPath: string
}

/**
 * 站内收藏/关注操作解析器
 * - 用于从主题/节点 HTML 中提取收藏/取消收藏的链接
 */
export class V2exCollectionActionParser {
  static extractTopicFavoriteToggle(html: string, topicId: number): V2exToggleAction | null {
    if (!html || topicId <= 0) {
      return null
    }
    const unfavRe = new RegExp(`href=['"]([^'"]*\\/unfavorite\\/topic\\/${topicId}[^'"]*)['"]`, 'i')
    const unfav = html.match(unfavRe)
    if (unfav && unfav[1]) {
      return { currentlyOn: true, actionPath: V2exCollectionActionParser.decodeHtml(unfav[1]) }
    }

    const favRe = new RegExp(`href=['"]([^'"]*\\/favorite\\/topic\\/${topicId}[^'"]*)['"]`, 'i')
    const fav = html.match(favRe)
    if (fav && fav[1]) {
      return { currentlyOn: false, actionPath: V2exCollectionActionParser.decodeHtml(fav[1]) }
    }

    const once = V2exCollectionActionParser.extractOnce(html)
    if (!once) {
      return null
    }
    return { currentlyOn: false, actionPath: `/favorite/topic/${topicId}?once=${once}` }
  }

  static extractNodeFavoriteToggle(html: string): V2exToggleAction | null {
    if (!html) {
      return null
    }
    const unfavRe = /href=['"]([^'"]*\/unfavorite\/node\/\d+[^'"]*)['"]/i
    const unfav = html.match(unfavRe)
    if (unfav && unfav[1]) {
      return { currentlyOn: true, actionPath: V2exCollectionActionParser.decodeHtml(unfav[1]) }
    }

    const favRe = /href=['"]([^'"]*\/favorite\/node\/\d+[^'"]*)['"]/i
    const fav = html.match(favRe)
    if (fav && fav[1]) {
      return { currentlyOn: false, actionPath: V2exCollectionActionParser.decodeHtml(fav[1]) }
    }

    return null
  }

  static extractOnce(html: string): string {
    if (!html) {
      return ''
    }
    const varRe = /var\s+once\s*=\s*"(\d+)"\s*;/i
    const m = html.match(varRe)
    if (m && m[1]) {
      return m[1]
    }
    const inputRe = /<input[^>]*name=['"]once['"][^>]*value=['"]([^'"]+)['"][^>]*>/i
    const m2 = html.match(inputRe)
    if (m2 && m2[1]) {
      return m2[1]
    }
    const hrefRe = /once=(\d+)/i
    const m3 = html.match(hrefRe)
    if (m3 && m3[1]) {
      return m3[1]
    }
    return ''
  }

  private static decodeHtml(value: string): string {
    return (value || '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }
}
