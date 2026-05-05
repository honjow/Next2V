/**
 * V2EX 首页 HTML 解析器
 * 从 /?tab=xxx 的 HTML 页面中提取主题 ID 列表
 */
export class V2exTabParser {
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
}
