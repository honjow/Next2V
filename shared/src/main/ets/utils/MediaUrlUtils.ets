const IMAGE_EXT_REGEX: RegExp = /\.(jpe?g|png|gif|webp)(?:[?#].*)?$/i
const IMAGE_QUERY_EXT_REGEX: RegExp = /[?&](?:format|fm|ext)=([a-z0-9]+)/i
const ILLEGAL_TITLE_CHARS: RegExp = /[\\/:*?"<>|]/g

const IMAGE_HOST_PREFIXES: string[] = [
  'https://i.imgur.com/',
  'http://i.imgur.com/',
  'https://sm.ms/',
  'http://sm.ms/',
  'https://s2.loli.net/',
  'http://s2.loli.net/',
  'https://v2ex.assets.uxengine.net/',
  'http://v2ex.assets.uxengine.net/',
  'https://i.v2ex.co/',
  'http://i.v2ex.co/',
  'https://i.v2ex.com/',
  'http://i.v2ex.com/',
  'https://raw.githubusercontent.com/',
  'http://raw.githubusercontent.com/',
  'https://pbs.twimg.com/media/',
  'http://pbs.twimg.com/media/',
  'https://github.com/user-attachments/assets/',
  'http://github.com/user-attachments/assets/',
]

export class MediaUrlUtils {
  static normalizeUrl(raw: string): string {
    const url = (raw ?? '').trim()
    if (!url) {
      return ''
    }
    if (url.startsWith('//')) {
      return `https:${url}`
    }
    return url
  }

  static isHttpUrl(raw: string): boolean {
    const url = MediaUrlUtils.normalizeUrl(raw)
    return url.startsWith('http://') || url.startsWith('https://')
  }

  static isProbablyImageUrl(raw: string): boolean {
    const url = MediaUrlUtils.normalizeUrl(raw)
    if (!MediaUrlUtils.isHttpUrl(url)) {
      return false
    }
    if (IMAGE_EXT_REGEX.test(url)) {
      return true
    }
    return IMAGE_HOST_PREFIXES.some((prefix: string) => url.startsWith(prefix))
  }

  static imageExtensionFromContentType(contentType: string): string {
    const clean = (contentType || '').toLowerCase().split(';')[0].trim()
    if (clean === 'image/jpeg' || clean === 'image/jpg') {
      return 'jpg'
    }
    if (clean === 'image/png') {
      return 'png'
    }
    if (clean === 'image/gif') {
      return 'gif'
    }
    if (clean === 'image/webp') {
      return 'webp'
    }
    return ''
  }

  static imageExtensionFromUrl(raw: string): string {
    const url = MediaUrlUtils.normalizeUrl(raw)
    const clean = url.split('#')[0]
    const queryMatch = clean.match(IMAGE_QUERY_EXT_REGEX)
    const queryExt = MediaUrlUtils.normalizeImageExtension(queryMatch?.[1] || '')
    if (queryExt) {
      return queryExt
    }

    const path = clean.split('?')[0]
    const match = path.match(/\.([a-z0-9]+)$/i)
    return MediaUrlUtils.normalizeImageExtension(match?.[1] || '')
  }

  static preferredImageExtension(raw: string, contentType: string = ''): string {
    return MediaUrlUtils.imageExtensionFromContentType(contentType) ||
      MediaUrlUtils.imageExtensionFromUrl(raw) ||
      'jpg'
  }

  static imageTitleFromUrl(raw: string, fallbackPrefix: string = 'v2next_image'): string {
    const url = MediaUrlUtils.normalizeUrl(raw)
    const path = url.split('#')[0].split('?')[0]
    const last = path.split('/').pop() || ''
    const withoutExt = last.replace(/\.(jpe?g|png|gif|webp)$/i, '')
    const clean = withoutExt
      .replace(ILLEGAL_TITLE_CHARS, '_')
      .replace(/\s+/g, '_')
      .trim()
    if (clean) {
      return clean.substring(0, 48)
    }
    return `${fallbackPrefix}_${Date.now()}`
  }

  private static normalizeImageExtension(raw: string): string {
    const ext = (raw || '').toLowerCase()
    if (ext === 'jpeg' || ext === 'jpg') {
      return 'jpg'
    }
    if (ext === 'png' || ext === 'gif' || ext === 'webp') {
      return ext
    }
    return ''
  }
}
