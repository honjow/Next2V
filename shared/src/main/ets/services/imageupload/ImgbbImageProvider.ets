import { util } from '@kit.ArkTS'
import { ImageUploadProvider, ImageUploadResult, ImageUploadErrorCode } from './ImageUploadProvider'
import { ImageUploadClient, ImageUploadHttpResult } from '../../network/ImageUploadClient'
import { ImageUploadSettings } from '../../settings/ImageUploadSettings'

const IMGBB_UPLOAD_URL: string = 'https://api.imgbb.com/1/upload'

interface ImgbbData {
  url?: string
  delete_url?: string
}

interface ImgbbError {
  message?: string
  code?: number
}

interface ImgbbResponse {
  data?: ImgbbData
  error?: ImgbbError
}

/**
 * ImgBB upload with the user's own API key. The key rides the query string (?key=) and the image is sent
 * as a raw base64 form field (no `data:` prefix) — an `application/x-www-form-urlencoded` string body that
 * reuses the proxy-safe `postForm` path. Registration still works at imgbb.com, unlike Imgur.
 */
export class ImgbbImageProvider implements ImageUploadProvider {
  async uploadImage(bytes: Uint8Array, mimeType: string, fileName: string): Promise<ImageUploadResult> {
    const apiKey = ImageUploadSettings.current().imgbbApiKey
    if (!apiKey) {
      throw new Error(ImageUploadErrorCode.NO_CREDENTIAL)
    }
    const base64 = new util.Base64Helper().encodeToStringSync(bytes)
    const url = `${IMGBB_UPLOAD_URL}?key=${encodeURIComponent(apiKey)}`
    const headers: Record<string, string> = { 'Accept': 'application/json' }
    const fields: Record<string, string> = { 'image': base64 }
    let httpResult: ImageUploadHttpResult = { responseCode: 0, body: '' }
    try {
      httpResult = await ImageUploadClient.postForm(url, headers, fields)
    } catch (_error) {
      throw new Error(ImageUploadErrorCode.NETWORK)
    }
    if (httpResult.responseCode === 413) {
      throw new Error(ImageUploadErrorCode.TOO_LARGE)
    }
    if (httpResult.responseCode === 429) {
      throw new Error(ImageUploadErrorCode.RATE_LIMIT)
    }
    if (httpResult.responseCode === 401) {
      // Missing/invalid API key.
      throw new Error(ImageUploadErrorCode.FORBIDDEN)
    }
    const parsed = ImgbbImageProvider.parse(httpResult.body)
    if (httpResult.responseCode === 400) {
      // ImgBB returns 400 for both a bad key ("Invalid API v1 key") and a bad image; disambiguate by the
      // error message so the user gets the right hint.
      const message = parsed && parsed.error && parsed.error.message ? parsed.error.message.toLowerCase() : ''
      throw new Error(message.indexOf('key') >= 0 ? ImageUploadErrorCode.FORBIDDEN : ImageUploadErrorCode.BAD_IMAGE)
    }
    if (!parsed || !parsed.data || !parsed.data.url) {
      throw new Error(ImageUploadErrorCode.SERVER)
    }
    const result = new ImageUploadResult()
    result.url = parsed.data.url
    result.deleteHash = parsed.data.delete_url || ''
    return result
  }

  private static parse(body: string): ImgbbResponse | null {
    try {
      return JSON.parse(body) as ImgbbResponse
    } catch (_error) {
      return null
    }
  }
}
