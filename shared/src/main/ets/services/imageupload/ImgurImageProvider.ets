import { util } from '@kit.ArkTS'
import { ImageUploadProvider, ImageUploadResult, ImageUploadErrorCode } from './ImageUploadProvider'
import { ImageUploadClient, ImageUploadHttpResult } from '../../network/ImageUploadClient'
import { ImageUploadSettings } from '../../settings/ImageUploadSettings'

const IMGUR_UPLOAD_URL: string = 'https://api.imgur.com/3/image'

interface ImgurResponseData {
  link?: string
  deletehash?: string
}

interface ImgurResponse {
  data?: ImgurResponseData
  success?: boolean
  status?: number
}

/**
 * Anonymous Imgur upload using the user-supplied Client-ID (`Authorization: Client-ID <id>`). The image
 * is sent as a base64 form field (`image=<base64>&type=base64`) so the whole thing is a string body that
 * works over every proxy mode. A bundled shared Client-ID would get rate-limited across the userbase, so
 * an empty Client-ID is treated as a hard error that the editor turns into "go configure it".
 */
export class ImgurImageProvider implements ImageUploadProvider {
  async uploadImage(bytes: Uint8Array, mimeType: string, fileName: string): Promise<ImageUploadResult> {
    const clientId = ImageUploadSettings.current().imgurClientId
    if (!clientId) {
      throw new Error(ImageUploadErrorCode.NO_CLIENT_ID)
    }
    const base64 = new util.Base64Helper().encodeToStringSync(bytes)
    const headers: Record<string, string> = {
      'Authorization': `Client-ID ${clientId}`,
      'Accept': 'application/json',
    }
    const fields: Record<string, string> = {
      'image': base64,
      'type': 'base64',
    }
    let httpResult: ImageUploadHttpResult = { responseCode: 0, body: '' }
    try {
      httpResult = await ImageUploadClient.postForm(IMGUR_UPLOAD_URL, headers, fields)
    } catch (_error) {
      throw new Error(ImageUploadErrorCode.NETWORK)
    }
    // Map the common HTTP failures before parsing. 403 covers both a bad Client-ID and Imgur's regional
    // blocks (e.g. the UK geoblock since 2025-09-30); the UI keeps the message generic.
    if (httpResult.responseCode === 413) {
      // Request Entity Too Large — the encoded image exceeds Imgur's limit.
      throw new Error(ImageUploadErrorCode.TOO_LARGE)
    }
    if (httpResult.responseCode === 429) {
      throw new Error(ImageUploadErrorCode.RATE_LIMIT)
    }
    if (httpResult.responseCode === 401 || httpResult.responseCode === 403) {
      throw new Error(ImageUploadErrorCode.FORBIDDEN)
    }
    if (httpResult.responseCode === 400) {
      throw new Error(ImageUploadErrorCode.BAD_IMAGE)
    }
    const parsed = ImgurImageProvider.parse(httpResult.body)
    if (!parsed || parsed.success !== true || !parsed.data || !parsed.data.link) {
      throw new Error(ImageUploadErrorCode.SERVER)
    }
    const result = new ImageUploadResult()
    result.url = parsed.data.link
    result.deleteHash = parsed.data.deletehash || ''
    return result
  }

  private static parse(body: string): ImgurResponse | null {
    try {
      // Over-capacity / nginx errors return non-JSON HTML — guard the parse so it surfaces as SERVER.
      return JSON.parse(body) as ImgurResponse
    } catch (_error) {
      return null
    }
  }
}
