import { ImageUploadProvider, ImageUploadResult, ImageUploadErrorCode } from './ImageUploadProvider'
import { ImgurImageProvider } from './ImgurImageProvider'
import { ImageUploadSettings } from '../../settings/ImageUploadSettings'
import { ImageBytesUtils } from '../../utils/ImageBytesUtils'

/**
 * Single entry point the editor calls. Selects the provider from settings, enforces the size cap, and
 * returns the hosted image URL. (Content-hash dedup and the V2EX provider are deferred.)
 */
export class ImageUploadService {
  static async uploadImage(bytes: Uint8Array, mimeType: string, fileName: string): Promise<ImageUploadResult> {
    if (bytes.length > ImageBytesUtils.MAX_IMAGE_BYTES) {
      throw new Error(ImageUploadErrorCode.TOO_LARGE)
    }
    const provider = ImageUploadService.providerFor(ImageUploadSettings.current().provider)
    return provider.uploadImage(bytes, mimeType, fileName)
  }

  private static providerFor(providerId: string): ImageUploadProvider {
    if (providerId === 'imgur') {
      return new ImgurImageProvider()
    }
    // The V2EX provider is not built yet (deferred behind live endpoint verification + cost confirmation).
    throw new Error(ImageUploadErrorCode.UNSUPPORTED_PROVIDER)
  }
}
