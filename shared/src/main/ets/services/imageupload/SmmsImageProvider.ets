import { ImageUploadProvider, ImageUploadResult, ImageUploadErrorCode } from './ImageUploadProvider'
import { ImageUploadClient, ImageUploadHttpResult } from '../../network/ImageUploadClient'
import { ImageUploadSettings } from '../../settings/ImageUploadSettings'
import { ImageBytesUtils } from '../../utils/ImageBytesUtils'

// sm.ms migrated to s.ee (2026-02). The SM.MS-compatible upload endpoint is /api/v1/file/upload on s.ee.
const SMMS_UPLOAD_URL: string = 'https://s.ee/api/v1/file/upload'

interface SmmsData {
  url?: string
  hash?: string
}

interface SmmsResponse {
  success?: boolean
  code?: string
  message?: string
  data?: SmmsData
  // On a repeated upload sm.ms returns success:false, code:'image_repeated' and the EXISTING url here.
  images?: string
}

/**
 * S.EE upload (S.EE is the former sm.ms, migrated 2026-02) with the user's own API key. Uses the
 * SM.MS-compatible endpoint `https://s.ee/api/v1/file/upload`; like sm.ms it accepts a binary
 * `multipart/form-data` `smfile` part (no base64 field), so it uses the `postMultipart` path, and the JSON
 * response keeps the same `success` / `data.url` / `data.hash` shape. The `image_repeated` duplicate path
 * below is legacy sm.ms behavior kept as a harmless fallback (s.ee may not emit it). Users need a NEW s.ee
 * API key (s.ee/user/developers) — old sm.ms tokens do not carry over. Often needs the app proxy from
 * mainland China.
 */
export class SmmsImageProvider implements ImageUploadProvider {
  async uploadImage(
    bytes: Uint8Array,
    mimeType: string,
    fileName: string,
  ): Promise<ImageUploadResult> {
    const token = ImageUploadSettings.current().smmsToken
    if (!token) {
      throw new Error(ImageUploadErrorCode.NO_CREDENTIAL)
    }
    // sm.ms validates by extension; derive one from the sniffed MIME rather than trusting the picker name.
    const name = `image.${ImageBytesUtils.extensionFor(mimeType)}`
    const headers: Record<string, string> = {
      'Authorization': token,
      'Accept': 'application/json',
    }
    let httpResult: ImageUploadHttpResult = { responseCode: 0, body: '' }
    try {
      httpResult = await ImageUploadClient.postMultipart(
        SMMS_UPLOAD_URL,
        headers,
        'smfile',
        name,
        mimeType,
        bytes,
      )
    } catch (_error) {
      throw new Error(ImageUploadErrorCode.NETWORK)
    }
    if (httpResult.responseCode === 413) {
      throw new Error(ImageUploadErrorCode.TOO_LARGE)
    }
    if (httpResult.responseCode === 401 || httpResult.responseCode === 403) {
      throw new Error(ImageUploadErrorCode.FORBIDDEN)
    }
    const parsed = SmmsImageProvider.parse(httpResult.body)
    if (!parsed) {
      throw new Error(ImageUploadErrorCode.SERVER)
    }
    const code = (parsed.code || '').toLowerCase()
    // Duplicate upload: sm.ms returns success:false, code 'image_repeated', existing URL in `images`. Only
    // that exact code is a success — don't treat an `images` field in some other error shape as one.
    if (code === 'image_repeated' && parsed.images) {
      const dup = new ImageUploadResult()
      dup.url = parsed.images
      return dup
    }
    if (parsed.success === true && parsed.data && parsed.data.url) {
      const result = new ImageUploadResult()
      result.url = parsed.data.url
      result.deleteHash = parsed.data.hash || ''
      return result
    }
    // sm.ms returns HTTP 200 with success:false + a code for errors; map the known ones.
    if (code.indexOf('token') >= 0 || code.indexOf('unauthor') >= 0) {
      throw new Error(ImageUploadErrorCode.FORBIDDEN)
    }
    if (code.indexOf('flood') >= 0 || code.indexOf('limit') >= 0 || code.indexOf('rate') >= 0) {
      throw new Error(ImageUploadErrorCode.RATE_LIMIT)
    }
    if (code.indexOf('large') >= 0 || code.indexOf('size') >= 0) {
      throw new Error(ImageUploadErrorCode.TOO_LARGE)
    }
    if (code.indexOf('format') >= 0 || code.indexOf('image') >= 0) {
      throw new Error(ImageUploadErrorCode.BAD_IMAGE)
    }
    throw new Error(ImageUploadErrorCode.SERVER)
  }

  private static parse(body: string): SmmsResponse | null {
    try {
      return JSON.parse(body) as SmmsResponse
    } catch (_error) {
      return null
    }
  }
}
