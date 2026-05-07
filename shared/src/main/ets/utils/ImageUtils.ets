import { ApiConstants } from '../constants/ApiConstants'

const PROTOCOL_RELATIVE_PREFIX: string = '//'
const HTTP_PREFIX: string = 'http'

/**
 * 图片 URL 处理工具
 */
export class ImageUtils {
  /** V2EX 返回的头像 URL 是 // 开头，需要补 https: 前缀 */
  static avatarUrl(path: string): string {
    if (!path) {
      return ''
    }
    const source = ImageUtils.preferLargeAvatar(path)
    if (source.startsWith(PROTOCOL_RELATIVE_PREFIX)) {
      return `https:${source}`
    }
    if (source.startsWith(HTTP_PREFIX)) {
      return source
    }
    return `${ApiConstants.BASE_URL_COM}${source}`
  }

  private static preferLargeAvatar(path: string): string {
    return (path || '')
      .replace('/mini.png', '/large.png')
      .replace('/normal.png', '/large.png')
      .replace('/mini.jpg', '/large.jpg')
      .replace('/normal.jpg', '/large.jpg')
      .replace('/mini.jpeg', '/large.jpeg')
      .replace('/normal.jpeg', '/large.jpeg')
      .replace('/mini.webp', '/large.webp')
      .replace('/normal.webp', '/large.webp')
  }
}
