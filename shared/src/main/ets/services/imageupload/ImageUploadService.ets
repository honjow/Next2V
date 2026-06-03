import { ImageUploadProvider, ImageUploadResult, ImageUploadErrorCode } from './ImageUploadProvider'
import { ImgbbImageProvider } from './ImgbbImageProvider'
import { SmmsImageProvider } from './SmmsImageProvider'
import { ImgurImageProvider } from './ImgurImageProvider'
import { ImageUploadSettings, ImageUploadProviderId } from '../../settings/ImageUploadSettings'
import { ImageBytesUtils } from '../../utils/ImageBytesUtils'

// sm.ms hard-caps a single file at 5 MB; ImgBB/Imgur are higher, so the global 7 MB picker cap applies.
const SMMS_MAX_BYTES: number = 5 * 1024 * 1024

/**
 * Single entry point the editor calls. Selects the provider from settings, enforces the per-provider size
 * cap, and returns the hosted image URL.
 */
export class ImageUploadService {
  static async uploadImage(bytes: Uint8Array, mimeType: string, fileName: string): Promise<ImageUploadResult> {
    const provider = ImageUploadSettings.current().provider
    if (bytes.length > ImageUploadService.maxBytesFor(provider)) {
      throw new Error(ImageUploadErrorCode.TOO_LARGE)
    }
    return ImageUploadService.providerFor(provider).uploadImage(bytes, mimeType, fileName)
  }

  static maxBytesFor(provider: ImageUploadProviderId): number {
    if (provider === 'smms') {
      return SMMS_MAX_BYTES
    }
    return ImageBytesUtils.MAX_IMAGE_BYTES
  }

  private static providerFor(provider: ImageUploadProviderId): ImageUploadProvider {
    if (provider === 'smms') {
      return new SmmsImageProvider()
    }
    if (provider === 'imgur') {
      return new ImgurImageProvider()
    }
    return new ImgbbImageProvider()
  }
}
