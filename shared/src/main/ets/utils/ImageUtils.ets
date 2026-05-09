import { ApiConstants } from '../constants/ApiConstants'
import type { V2exMember } from '../network/NetworkTypes'

const PROTOCOL_RELATIVE_PREFIX: string = '//'
const HTTP_PREFIX: string = 'http'

export type AvatarSize = 'large' | 'xlarge' | 'xxlarge' | 'xxxlarge'

/**
 * 图片 URL 处理工具
 */
export class ImageUtils {
  /** V2EX 返回的头像 URL 是 // 开头，需要补 https: 前缀 */
  static avatarUrl(path: string, size: AvatarSize = 'large'): string {
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

  /**
   * Selects the best avatar URL that the V2EX API actually returned for a member.
   * Do not synthesize xlarge/xxlarge/xxxlarge URLs here; some users only have large.
   */
  static memberAvatarUrl(member: V2exMember | null | undefined, preferred: AvatarSize = 'xlarge'): string {
    if (!member) {
      return ''
    }

    const source = ImageUtils.memberAvatarSource(member, preferred)
    return ImageUtils.avatarUrl(source)
  }

  /** 将 V2EX 头像 URL 的 mini/normal 尺寸安全升级为 API/CDN 常见的 large 尺寸。 */
  private static preferLargeAvatar(path: string, size: AvatarSize = 'large'): string {
    return (path || '')
      .replace(/_(?:mini|normal)(\.\w+)([?#].*)?$/, `_${size}$1$2`)
      .replace(/\/(?:mini|normal)(\.\w+)([?#].*)?$/, '/large$1$2')
  }

  private static memberAvatarSource(member: V2exMember, preferred: AvatarSize): string {
    if (preferred === 'xxxlarge' && member.avatar_xxxlarge) {
      return member.avatar_xxxlarge
    }
    if ((preferred === 'xxxlarge' || preferred === 'xxlarge') && member.avatar_xxlarge) {
      return member.avatar_xxlarge
    }
    if (preferred !== 'large' && member.avatar_xlarge) {
      return member.avatar_xlarge
    }
    return member.avatar_large || member.avatar_normal || member.avatar_mini || ''
  }
}
