import { ApiConstants } from '../constants/ApiConstants'
import type { V2exMember } from '../network/NetworkTypes'

const PROTOCOL_RELATIVE_PREFIX: string = '//'
const HTTP_PREFIX: string = 'http'

export type AvatarSize = 'large' | 'xlarge' | 'xxlarge' | 'xxxlarge'

/**
 * Image URL processing utility
 */
export class ImageUtils {
  /** V2EX avatar URLs start with //, need https: prefix prepended */
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

  /** Safely upgrade V2EX avatar URL from mini/normal to large size (common in API/CDN). */
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
