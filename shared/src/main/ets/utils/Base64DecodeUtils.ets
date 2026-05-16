export interface Base64DecodeResult {
  original: string
  decoded: string
}

// Minimum 12 chars: long enough for common contact snippets after encoding
// (for example short emails / WeChat IDs) while filtering incidental words.
const BASE64_MIN_TOKEN_LENGTH: number = 12
// Bound candidate size so scanning cannot create huge inline badges/dialog content.
const BASE64_MAX_TOKEN_LENGTH: number = 512

export class Base64DecodeUtils {
  static readonly MIN_TOKEN_LENGTH: number = BASE64_MIN_TOKEN_LENGTH
  static readonly MAX_TOKEN_LENGTH: number = BASE64_MAX_TOKEN_LENGTH

  static tryDecodeToken(token: string): Base64DecodeResult | null {
    const original = (token || '').trim()
    // Use 12 chars as the lower bound: enough for common V2EX contact snippets
    // such as base64 email/wechat IDs, while excluding short incidental words.
    if (original.length < BASE64_MIN_TOKEN_LENGTH || original.length > BASE64_MAX_TOKEN_LENGTH) {
      return null
    }
    if (!/^[A-Za-z0-9+/_=\-]+$/.test(original)) {
      return null
    }
    const hasUrlSafe = original.indexOf('-') >= 0 || original.indexOf('_') >= 0
    const hasStandard = original.indexOf('+') >= 0 || original.indexOf('/') >= 0
    if (hasUrlSafe && hasStandard) {
      return null
    }
    const withoutPadding = original.replace(/=+$/g, '')
    if (withoutPadding.indexOf('=') >= 0) {
      return null
    }
    const remainder = withoutPadding.length % 4
    if (remainder === 1) {
      return null
    }
    let normalized = withoutPadding.replace(/-/g, '+').replace(/_/g, '/')
    if (remainder > 0) {
      normalized += '===='.slice(remainder)
    }
    const bytes = Base64DecodeUtils.decodeBase64Bytes(normalized)
    if (bytes.length === 0) {
      return null
    }
    const decoded = Base64DecodeUtils.decodeUtf8(bytes)
    if (!decoded) {
      return null
    }
    const trimmed = decoded.trim()
    if (trimmed.length < 3 || trimmed === original) {
      return null
    }
    if (!Base64DecodeUtils.isReadableText(trimmed)) {
      return null
    }
    return { original: original, decoded: trimmed }
  }

  static findDecodableTokens(text: string): Base64DecodeResult[] {
    const results: Base64DecodeResult[] = []
    const re = /[A-Za-z0-9+/_=\-]+/g
    let match: RegExpExecArray | null = re.exec(text || '')
    while (match) {
      const decoded = Base64DecodeUtils.tryDecodeToken(match[0])
      if (decoded) {
        results.push(decoded)
      }
      match = re.exec(text || '')
    }
    return results
  }

  private static decodeBase64Bytes(value: string): number[] {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    const bytes: number[] = []
    let buffer = 0
    let bits = 0
    for (let i = 0; i < value.length; i++) {
      const ch = value.charAt(i)
      if (ch === '=') {
        break
      }
      const index = alphabet.indexOf(ch)
      if (index < 0) {
        return []
      }
      buffer = (buffer << 6) | index
      bits += 6
      if (bits >= 8) {
        bits -= 8
        bytes.push((buffer >> bits) & 0xff)
      }
    }
    return bytes
  }

  private static decodeUtf8(bytes: number[]): string {
    let result = ''
    for (let i = 0; i < bytes.length;) {
      const b0 = bytes[i]
      if (b0 <= 0x7f) {
        if (b0 === 0) {
          return ''
        }
        result += String.fromCharCode(b0)
        i += 1
      } else if (b0 >= 0xc2 && b0 <= 0xdf) {
        if (i + 1 >= bytes.length || !Base64DecodeUtils.isContinuation(bytes[i + 1])) {
          return ''
        }
        const cp = ((b0 & 0x1f) << 6) | (bytes[i + 1] & 0x3f)
        result += String.fromCharCode(cp)
        i += 2
      } else if (b0 >= 0xe0 && b0 <= 0xef) {
        if (i + 2 >= bytes.length || !Base64DecodeUtils.isContinuation(bytes[i + 1]) || !Base64DecodeUtils.isContinuation(bytes[i + 2])) {
          return ''
        }
        if (b0 === 0xe0 && bytes[i + 1] < 0xa0) {
          return ''
        }
        if (b0 === 0xed && bytes[i + 1] >= 0xa0) {
          return ''
        }
        const cp = ((b0 & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f)
        result += String.fromCharCode(cp)
        i += 3
      } else if (b0 >= 0xf0 && b0 <= 0xf4) {
        if (i + 3 >= bytes.length || !Base64DecodeUtils.isContinuation(bytes[i + 1]) || !Base64DecodeUtils.isContinuation(bytes[i + 2]) || !Base64DecodeUtils.isContinuation(bytes[i + 3])) {
          return ''
        }
        if (b0 === 0xf0 && bytes[i + 1] < 0x90) {
          return ''
        }
        if (b0 === 0xf4 && bytes[i + 1] >= 0x90) {
          return ''
        }
        const cp = ((b0 & 0x07) << 18) | ((bytes[i + 1] & 0x3f) << 12) | ((bytes[i + 2] & 0x3f) << 6) | (bytes[i + 3] & 0x3f)
        const offset = cp - 0x10000
        result += String.fromCharCode(0xd800 + (offset >> 10), 0xdc00 + (offset & 0x3ff))
        i += 4
      } else {
        return ''
      }
    }
    return result
  }

  private static isContinuation(byteValue: number): boolean {
    return byteValue >= 0x80 && byteValue <= 0xbf
  }

  private static isReadableText(value: string): boolean {
    let readable = 0
    let total = 0
    let lettersOrDigits = 0
    let hexLike = 0
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i)
      if (code >= 0xd800 && code <= 0xdbff && i + 1 < value.length) {
        i += 1
      }
      total += 1
      const ch = value.charAt(i)
      const isControl = code < 0x20 && ch !== '\n' && ch !== '\r' && ch !== '\t'
      if (!isControl && code !== 0x7f) {
        readable += 1
      }
      if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || code > 0x7f) {
        lettersOrDigits += 1
      }
      if ((ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F') || (ch >= '0' && ch <= '9')) {
        hexLike += 1
      }
    }
    if (total === 0) {
      return false
    }
    if (readable / total < 0.85 || lettersOrDigits < 2) {
      return false
    }
    // Common hashes decode to binary or hex-ish blobs; avoid exposing those as contact text.
    if (value.length >= 24 && hexLike / value.length > 0.9) {
      return false
    }
    return true
  }
}
