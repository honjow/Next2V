import { ApiConstants } from '../constants/ApiConstants'

const PROTOCOL_RELATIVE_PREFIX: string = '//'
const HTTP_PREFIX: string = 'http'

type AvatarSize = 'xlarge' | 'xxlarge' | 'xxxlarge'

/**
 * 图片 URL 处理工具
 */
export class ImageUtils {
  /** V2EX 返回的头像 URL 是 // 开头，需要补 https: 前缀 */
  static avatarUrl(path: string, size: AvatarSize = 'xlarge'): string {
    if (!path) {
      return ''
    }
    const source = ImageUtils.preferLargeAvatar(path, size)
    if (source.startsWith(PROTOCOL_RELATIVE_PREFIX)) {
      return `https:${source}`
    }
    if (source.startsWith(HTTP_PREFIX)) {
      return source
    }
    return `${ApiConstants.BASE_URL_COM}${source}`
  }

  /** 将 V2EX 头像 URL 的 mini/normal 尺寸升级为更适合列表显示的尺寸。 */
  private static preferLargeAvatar(path: string, size: AvatarSize = 'xlarge'): string {
    return (path || '')
      .replace(/_(?:mini|normal)(\.\w+)([?#].*)?$/, `_${size}$1$2`)
      .replace(/\/(?:mini|normal)(\.\w+)([?#].*)?$/, '/large$1$2')
  }
}
