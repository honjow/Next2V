/**
 * Pluggable image-upload backend. The MVP ships `ImgurImageProvider`; a `V2exImageProvider` is planned
 * once the (paid, currently undocumented) V2EX `/i` upload endpoint is verified with a live capture.
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
  static readonly NO_CLIENT_ID: string = 'IMG_ERR_NO_CLIENT_ID'
  static readonly TOO_LARGE: string = 'IMG_ERR_TOO_LARGE'
  static readonly BAD_IMAGE: string = 'IMG_ERR_BAD_IMAGE'
  static readonly FORBIDDEN: string = 'IMG_ERR_FORBIDDEN'
  static readonly RATE_LIMIT: string = 'IMG_ERR_RATE_LIMIT'
  static readonly SERVER: string = 'IMG_ERR_SERVER'
  static readonly NETWORK: string = 'IMG_ERR_NETWORK'
  static readonly UNSUPPORTED_PROVIDER: string = 'IMG_ERR_UNSUPPORTED_PROVIDER'
}
