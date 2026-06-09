import { AppStrings } from '../i18n/AppStrings'

const IMAGE_EXT_REGEX: RegExp = /\.(jpe?g|png|gif|webp|bmp|svg|avif|heic|heif)(?:[?#].*)?$/i
const VIDEO_EXT_REGEX: RegExp = /\.(mp4|webm|mov|m4v|m3u8)(?:[?#].*)?$/i
const MEDIA_QUERY_EXT_REGEX: RegExp = /[?&](?:format|fm|ext|type|output)=([a-z0-9/]+)/i
const ILLEGAL_TITLE_CHARS: RegExp = /[\\/:*?"<>|]/g
const YOUTUBE_ID_REGEX: RegExp = /(?:youtube\.com\/(?:watch\?[^#]*v=|embed\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})/i
const VIMEO_ID_REGEX: RegExp = /vimeo\.com\/(?:.*\/)?([0-9]{6,})/i
// Embedded-player srcs as V2EX emits them inside content_rendered: the current
// wrapper iframe uses youtube.com/embed/<id> or protocol-relative
// player.vimeo.com/video/<id>; pre-2014 Flash <object> markup uses /v/<id>.
const YOUTUBE_EMBED_SRC_REGEX: RegExp = /youtube(?:-nocookie)?\.com\/(?:embed|v)\/([A-Za-z0-9_-]{6,})/i
const VIMEO_PLAYER_SRC_REGEX: RegExp = /player\.vimeo\.com\/video\/([0-9]+)/i
const GIST_REGEX: RegExp = /gist\.github\.com\/([^/?#]+)\/([A-Za-z0-9]+)/i
const IMGUR_SINGLE_IMAGE_PAGE_REGEX: RegExp = /^https?:\/\/(?:www\.)?imgur\.com\/([A-Za-z0-9]{5,12})(?:[?#].*)?$/i
const IMGUR_COLLECTION_PAGE_REGEX: RegExp = /^https?:\/\/(?:www\.)?imgur\.com\/(?:gallery|a)\//i

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

export interface MediaLinkPreview {
  url: string
  title: string
  subtitle: string
  label: string
}

export interface EmbeddedVideoInfo {
  provider: string
  providerLabel: string
  videoId: string
  watchUrl: string
  // '' when the provider has no static thumbnail endpoint (Vimeo needs an API call)
  coverUrl: string
}

export type MediaUrlKind =
  'directImage' |
  'directVideo' |
  'knownImageHostDirect' |
  'imageHostPageResolved' |
  'probeRequired' |
  'nonImageLink' |
  'unsupported'

export interface MediaUrlResult {
  originalUrl: string
  normalizedUrl: string
  renderUrl: string
  kind: MediaUrlKind
  isImage: boolean
  isVideo: boolean
  shouldProbe: boolean
}

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

  static isStandaloneHttpUrl(raw: string): boolean {
    const clean = (raw ?? '').trim()
    if (!clean || /\s/.test(clean)) {
      return false
    }
    return MediaUrlUtils.isHttpUrl(clean)
  }

  static isProbablyImageUrl(raw: string): boolean {
    return MediaUrlUtils.resolveMediaUrl(raw).isImage
  }

  static imageUrlForRender(raw: string): string {
    const result = MediaUrlUtils.resolveMediaUrl(raw)
    return result.isImage ? result.renderUrl : ''
  }

  static videoUrlForRender(raw: string): string {
    const result = MediaUrlUtils.resolveMediaUrl(raw)
    return result.isVideo ? result.renderUrl : ''
  }

  static resolveMediaUrl(raw: string): MediaUrlResult {
    const originalUrl = (raw ?? '').trim()
    const normalizedUrl = MediaUrlUtils.normalizeUrl(originalUrl)
    if (!normalizedUrl) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, '', 'unsupported', false, false, false)
    }
    if (!MediaUrlUtils.isHttpUrl(normalizedUrl)) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, normalizedUrl, 'unsupported', false, false, false)
    }
    if (VIDEO_EXT_REGEX.test(normalizedUrl) || MediaUrlUtils.videoExtensionFromUrl(normalizedUrl)) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, normalizedUrl, 'directVideo', false, true, false)
    }
    if (IMAGE_EXT_REGEX.test(normalizedUrl) || MediaUrlUtils.imageExtensionFromUrl(normalizedUrl)) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, normalizedUrl, 'directImage', true, false, false)
    }
    if (IMAGE_HOST_PREFIXES.some((prefix: string) => normalizedUrl.startsWith(prefix))) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, normalizedUrl, 'knownImageHostDirect', true, false, false)
    }

    const imgurDirect = MediaUrlUtils.resolveImgurSingleImagePage(normalizedUrl)
    if (imgurDirect) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, imgurDirect, 'imageHostPageResolved', true, false, false)
    }
    if (IMGUR_COLLECTION_PAGE_REGEX.test(normalizedUrl)) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, normalizedUrl, 'nonImageLink', false, false, false)
    }

    if (MediaUrlUtils.isProbeCandidate(normalizedUrl)) {
      return MediaUrlUtils.result(originalUrl, normalizedUrl, normalizedUrl, 'probeRequired', false, false, true)
    }
    return MediaUrlUtils.result(originalUrl, normalizedUrl, normalizedUrl, 'nonImageLink', false, false, false)
  }

  static resolveByContentType(raw: string, contentType: string): MediaUrlResult {
    const base = MediaUrlUtils.resolveMediaUrl(raw)
    if (base.isImage || base.isVideo || !base.shouldProbe) {
      return base
    }
    if (MediaUrlUtils.imageExtensionFromContentType(contentType)) {
      return MediaUrlUtils.result(base.originalUrl, base.normalizedUrl, base.normalizedUrl, 'directImage', true, false, false)
    }
    if (MediaUrlUtils.videoExtensionFromContentType(contentType)) {
      return MediaUrlUtils.result(base.originalUrl, base.normalizedUrl, base.normalizedUrl, 'directVideo', false, true, false)
    }
    return MediaUrlUtils.result(base.originalUrl, base.normalizedUrl, base.normalizedUrl, 'nonImageLink', false, false, false)
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
    if (clean === 'image/bmp') {
      return 'bmp'
    }
    if (clean === 'image/svg+xml') {
      return 'svg'
    }
    if (clean === 'image/avif') {
      return 'avif'
    }
    if (clean === 'image/heic') {
      return 'heic'
    }
    if (clean === 'image/heif') {
      return 'heif'
    }
    return ''
  }

  static imageExtensionFromUrl(raw: string): string {
    const url = MediaUrlUtils.normalizeUrl(raw)
    const clean = url.split('#')[0]
    const queryMatch = clean.match(MEDIA_QUERY_EXT_REGEX)
    const queryExt = MediaUrlUtils.normalizeImageExtension(queryMatch?.[1] || '')
    if (queryExt) {
      return queryExt
    }

    const path = clean.split('?')[0]
    const match = path.match(/\.([a-z0-9]+)$/i)
    return MediaUrlUtils.normalizeImageExtension(match?.[1] || '')
  }

  static videoExtensionFromContentType(contentType: string): string {
    const clean = (contentType || '').toLowerCase().split(';')[0].trim()
    if (clean === 'video/mp4' || clean === 'application/mp4') {
      return 'mp4'
    }
    if (clean === 'video/webm') {
      return 'webm'
    }
    if (clean === 'video/quicktime') {
      return 'mov'
    }
    if (clean === 'video/x-m4v') {
      return 'm4v'
    }
    if (clean === 'application/vnd.apple.mpegurl' || clean === 'application/x-mpegurl' || clean === 'audio/mpegurl') {
      return 'm3u8'
    }
    return ''
  }

  static videoExtensionFromUrl(raw: string): string {
    const url = MediaUrlUtils.normalizeUrl(raw)
    const clean = url.split('#')[0]
    const queryMatch = clean.match(MEDIA_QUERY_EXT_REGEX)
    const queryExt = MediaUrlUtils.normalizeVideoExtension(queryMatch?.[1] || '')
    if (queryExt) {
      return queryExt
    }

    const path = clean.split('?')[0]
    const match = path.match(/\.([a-z0-9]+)$/i)
    return MediaUrlUtils.normalizeVideoExtension(match?.[1] || '')
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
    const withoutExt = last.replace(/\.(jpe?g|png|gif|webp|bmp|svg|avif|heic|heif)$/i, '')
    const clean = withoutExt
      .replace(ILLEGAL_TITLE_CHARS, '_')
      .replace(/\s+/g, '_')
      .trim()
    if (clean) {
      return clean.substring(0, 48)
    }
    return `${fallbackPrefix}_${Date.now()}`
  }

  static buildLinkPreview(raw: string, text: string = ''): MediaLinkPreview {
    const url = MediaUrlUtils.normalizeUrl(raw)
    const host = MediaUrlUtils.hostFromUrl(url)
    const displayText = (text || '').trim()
    const titleFromText = displayText && MediaUrlUtils.normalizeUrl(displayText) !== url ? displayText : ''
    const youtubeId = MediaUrlUtils.youtubeVideoId(url)
    if (youtubeId) {
      return {
        url: url,
        title: titleFromText || AppStrings.text($r('app.string.media_youtube_video'), 'YouTube video'),
        subtitle: host || url,
        label: 'YouTube'
      }
    }

    const vimeoId = MediaUrlUtils.vimeoVideoId(url)
    if (vimeoId) {
      return {
        url: url,
        title: titleFromText || AppStrings.text($r('app.string.media_vimeo_video'), 'Vimeo video'),
        subtitle: host || url,
        label: 'Vimeo'
      }
    }

    const videoExt = MediaUrlUtils.videoExtensionFromUrl(url)
    if (videoExt) {
      return {
        url: url,
        title: titleFromText || MediaUrlUtils.imageTitleFromUrl(url, 'v2next_video'),
        subtitle: host || url,
        label: AppStrings.text($r('app.string.media_video_link'), 'Video')
      }
    }

    const gistName = MediaUrlUtils.gistName(url)
    if (gistName) {
      return {
        url: url,
        title: titleFromText || gistName,
        subtitle: host || url,
        label: 'Gist'
      }
    }

    if (MediaUrlUtils.isImgurPage(url)) {
      return {
        url: url,
        title: titleFromText || AppStrings.text($r('app.string.media_imgur_page'), 'Imgur page'),
        subtitle: host || url,
        label: 'Imgur'
      }
    }

    if (MediaUrlUtils.isHostOrSubdomain(host, 'v2ex.com') || MediaUrlUtils.isHostOrSubdomain(host, 'v2ex.co')) {
      return {
        url: url,
        title: titleFromText || AppStrings.text($r('app.string.media_v2ex_link'), 'V2EX link'),
        subtitle: host || url,
        label: 'V2EX'
      }
    }

    return {
      url: url,
      title: titleFromText || host || url,
      subtitle: url,
      label: AppStrings.text($r('app.string.media_link_label'), 'Link')
    }
  }

  // Maps an embedded-player src restored from V2EX content_rendered back to the
  // canonical watch URL. Returns null for non-whitelisted sources so callers can
  // degrade to a plain link instead of dropping content.
  static embeddedVideoFromSrc(raw: string): EmbeddedVideoInfo | null {
    const url = MediaUrlUtils.normalizeUrl(raw)
    if (!url) {
      return null
    }
    const youtubeMatch = url.match(YOUTUBE_EMBED_SRC_REGEX)
    if (youtubeMatch && youtubeMatch[1]) {
      return {
        provider: 'youtube',
        providerLabel: 'YouTube',
        videoId: youtubeMatch[1],
        watchUrl: `https://www.youtube.com/watch?v=${youtubeMatch[1]}`,
        coverUrl: `https://i.ytimg.com/vi/${youtubeMatch[1]}/hqdefault.jpg`
      }
    }
    const vimeoMatch = url.match(VIMEO_PLAYER_SRC_REGEX)
    if (vimeoMatch && vimeoMatch[1]) {
      return {
        provider: 'vimeo',
        providerLabel: 'Vimeo',
        videoId: vimeoMatch[1],
        watchUrl: `https://vimeo.com/${vimeoMatch[1]}`,
        coverUrl: ''
      }
    }
    return null
  }

  static hostFromUrl(raw: string): string {
    const url = MediaUrlUtils.normalizeUrl(raw)
    const match = url.match(/^https?:\/\/([^/?#]+)/i)
    return (match?.[1] || '').toLowerCase()
  }

  private static normalizeImageExtension(raw: string): string {
    let ext = (raw || '').toLowerCase().trim()
    if (ext.indexOf('/') >= 0) {
      ext = ext.split('/').pop() || ''
    }
    if (ext === 'jpeg' || ext === 'jpg') {
      return 'jpg'
    }
    if (ext === 'png' || ext === 'gif' || ext === 'webp' || ext === 'bmp' ||
      ext === 'svg' || ext === 'avif' || ext === 'heic' || ext === 'heif') {
      return ext
    }
    return ''
  }

  private static normalizeVideoExtension(raw: string): string {
    let ext = (raw || '').toLowerCase().trim()
    if (ext.indexOf('/') >= 0) {
      ext = ext.split('/').pop() || ''
    }
    if (ext === 'mp4' || ext === 'webm' || ext === 'mov' || ext === 'm4v' || ext === 'm3u8') {
      return ext
    }
    return ''
  }

  private static youtubeVideoId(url: string): string {
    const match = url.match(YOUTUBE_ID_REGEX)
    return match?.[1] || ''
  }

  private static vimeoVideoId(url: string): string {
    const match = url.match(VIMEO_ID_REGEX)
    return match?.[1] || ''
  }

  private static gistName(url: string): string {
    const match = url.match(GIST_REGEX)
    if (!match || !match[1] || !match[2]) {
      return ''
    }
    return `${match[1]}/${match[2]}`
  }

  private static isImgurPage(url: string): boolean {
    const host = MediaUrlUtils.hostFromUrl(url)
    if (host === 'i.imgur.com') {
      return false
    }
    return IMGUR_SINGLE_IMAGE_PAGE_REGEX.test(url) || IMGUR_COLLECTION_PAGE_REGEX.test(url)
  }

  private static isHostOrSubdomain(host: string, domain: string): boolean {
    return host === domain || host.endsWith(`.${domain}`)
  }

  private static resolveImgurSingleImagePage(url: string): string {
    if (IMGUR_COLLECTION_PAGE_REGEX.test(url)) {
      return ''
    }
    const match = url.match(IMGUR_SINGLE_IMAGE_PAGE_REGEX)
    if (!match || !match[1]) {
      return ''
    }
    return `https://i.imgur.com/${match[1]}.png`
  }

  private static isProbeCandidate(url: string): boolean {
    if (!MediaUrlUtils.isStandaloneHttpUrl(url)) {
      return false
    }
    const host = MediaUrlUtils.hostFromUrl(url)
    if (!host || MediaUrlUtils.isHostOrSubdomain(host, 'github.com') ||
      MediaUrlUtils.isHostOrSubdomain(host, 'youtube.com') ||
      MediaUrlUtils.isHostOrSubdomain(host, 'youtu.be') ||
      MediaUrlUtils.isHostOrSubdomain(host, 'vimeo.com') ||
      MediaUrlUtils.isHostOrSubdomain(host, 'v2ex.com') ||
      MediaUrlUtils.isHostOrSubdomain(host, 'v2ex.co')) {
      return false
    }
    return true
  }

  private static result(
    originalUrl: string,
    normalizedUrl: string,
    renderUrl: string,
    kind: MediaUrlKind,
    isImage: boolean,
    isVideo: boolean,
    shouldProbe: boolean
  ): MediaUrlResult {
    return {
      originalUrl: originalUrl,
      normalizedUrl: normalizedUrl,
      renderUrl: renderUrl,
      kind: kind,
      isImage: isImage,
      isVideo: isVideo,
      shouldProbe: shouldProbe
    }
  }
}
