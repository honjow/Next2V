import { fileIo } from '@kit.CoreFileKit'

// Hard cap on the binary image size, kept well under Imgur's received-body limit: base64 inflates the
// body ~+33% (plus percent-encoding of +,/,=), so a 7 MB binary stays under ~10 MB encoded. Also bounds
// the device memory the editor holds during an upload.
const MAX_IMAGE_BYTES: number = 7 * 1024 * 1024
// Mirrors ImageUploadErrorCode.TOO_LARGE. Thrown here so the cap gates the ArrayBuffer allocation (we
// never read a multi-GB file into memory); the editor maps this message to the same "too large" toast.
const TOO_LARGE_CODE: string = 'IMG_ERR_TOO_LARGE'

export interface ImageBytes {
  bytes: Uint8Array
  mimeType: string
  byteLength: number
}

export class ImageBytesUtils {
  static readonly MAX_IMAGE_BYTES: number = MAX_IMAGE_BYTES

  /**
   * The picker returns a file:// / content uri, not a sandbox path, so readTextSync(path) fails on it.
   * Open the uri to a fd and read the raw bytes (mirrors BackupFilePickerCoordinator.readText but keeps
   * binary — no TextDecoder).
   */
  static readImageBytes(uri: string): ImageBytes {
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const size = fileIo.statSync(file.fd).size
      if (size > MAX_IMAGE_BYTES) {
        // Gate before allocating so a pathologically large pick can't OOM the device.
        throw new Error(TOO_LARGE_CODE)
      }
      const buffer = new ArrayBuffer(size)
      const bytesRead = fileIo.readSync(file.fd, buffer)
      const bytes = new Uint8Array(buffer, 0, bytesRead)
      return { bytes: bytes, mimeType: ImageBytesUtils.sniffMime(bytes), byteLength: bytesRead }
    } finally {
      if (file) {
        fileIo.closeSync(file)
      }
    }
  }

  /** Detect the image MIME from magic bytes; defaults to image/jpeg when unknown. */
  static sniffMime(bytes: Uint8Array): string {
    if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) {
      return 'image/png'
    }
    if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
      return 'image/jpeg'
    }
    if (bytes.length >= 6 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) {
      return 'image/gif'
    }
    if (
      bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46
      && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
    ) {
      return 'image/webp'
    }
    return 'image/jpeg'
  }

  static extensionFor(mimeType: string): string {
    if (mimeType === 'image/png') {
      return 'png'
    }
    if (mimeType === 'image/gif') {
      return 'gif'
    }
    if (mimeType === 'image/webp') {
      return 'webp'
    }
    return 'jpg'
  }
}
