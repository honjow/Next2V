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
    if (path.startsWith(PROTOCOL_RELATIVE_PREFIX)) {
      return `https:${path}`
    }
    if (path.startsWith(HTTP_PREFIX)) {
      return path
    }
    return `${ApiConstants.BASE_URL_COM}${path}`
  }
}
