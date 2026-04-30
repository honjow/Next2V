/**
 * 图片 URL 处理工具
 */
export class ImageUtils {
  /** V2EX 返回的头像 URL 是 // 开头，需要补 https: 前缀 */
  static avatarUrl(path: string): string {
    if (!path) {
      return ''
    }
    if (path.startsWith('//')) {
      return `https:${path}`
    }
    if (path.startsWith('http')) {
      return path
    }
    return `https://www.v2ex.com${path}`
  }
}
