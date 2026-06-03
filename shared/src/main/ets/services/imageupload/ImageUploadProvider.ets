/**
 * Pluggable image-upload backend. Implementations: `ImgbbImageProvider` (base64 form), `SmmsImageProvider`
 * (binary multipart), `ImgurImageProvider` (legacy anonymous Client-ID, kept for users who registered one
 * before Imgur closed new app registration). Selected by `ImageUploadSettings.provider`.
 */
export interface ImageUploadProvider {
  uploadImage(bytes: Uint8Array, mimeType: string, fileName: string): Promise<ImageUploadResult>
}

export class ImageUploadResult {
  url: string = ''
  deleteHash: string = ''
}

/**
 * Stable error codes thrown (as `new Error(code)`) by providers/service, mapped to localized Chinese
 * messages at the editor call site. Using codes (not localized strings) keeps the service layer free of
 * i18n and lets the UI own the wording.
 */
export class ImageUploadErrorCode {
  // Active provider has no credential configured (Imgur Client-ID / ImgBB API key / sm.ms token).
  static readonly NO_CREDENTIAL: string = 'IMG_ERR_NO_CREDENTIAL'
  static readonly TOO_LARGE: string = 'IMG_ERR_TOO_LARGE'
  static readonly BAD_IMAGE: string = 'IMG_ERR_BAD_IMAGE'
  static readonly FORBIDDEN: string = 'IMG_ERR_FORBIDDEN'
  static readonly RATE_LIMIT: string = 'IMG_ERR_RATE_LIMIT'
  static readonly SERVER: string = 'IMG_ERR_SERVER'
  static readonly NETWORK: string = 'IMG_ERR_NETWORK'
  static readonly UNSUPPORTED_PROVIDER: string = 'IMG_ERR_UNSUPPORTED_PROVIDER'
}
