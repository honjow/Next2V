import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { NetworkProxyRequest, NetworkProxyResponse } from './NetworkProxyRequest'

export interface ImageUploadHttpResult {
  responseCode: number
  body: string
}

// Fixed multipart boundary. A long unlikely literal avoids the (astronomically rare) collision with the
// image bytes without needing Math.random/Date.now (both banned in this codebase).
const MULTIPART_BOUNDARY: string = '----V2NextImageBoundary7MA4YWxkTrZu0gW'

/**
 * Raw POST primitive for image uploads. Sends an `application/x-www-form-urlencoded` body so it rides
 * the existing string-body proxy stack (NetworkKit / rcp / SOCKS5) unchanged — no binary multipart part
 * is required for the MVP (the image is carried as a base64 form field). A real binary
 * `multipart/form-data` path is a later optimization.
 *
 * The URL is used verbatim (absolute, e.g. `https://api.imgur.com/3/image`) — it does NOT go through the
 * configurable V2EX base URL.
 */
export class ImageUploadClient {
  static async postForm(
    url: string,
    headers: Record<string, string>,
    fields: Record<string, string>,
  ): Promise<ImageUploadHttpResult> {
    const body = ImageUploadClient.encodeForm(fields)
    const header: Record<string, string> = {}
    Object.keys(headers).forEach((key: string) => {
      header[key] = headers[key]
    })
    header['Content-Type'] = 'application/x-www-form-urlencoded'
    const response: NetworkProxyResponse = await NetworkProxyRequest.request(url, {
      method: http.RequestMethod.POST,
      header: header,
      extraData: body,
      connectTimeout: 15000,
      readTimeout: 60000,
      usingCache: false,
    })
    const result = typeof response.result === 'string' ? response.result : ''
    return { responseCode: response.responseCode, body: result }
  }

  private static encodeForm(fields: Record<string, string>): string {
    const parts: string[] = []
    Object.keys(fields).forEach((key: string) => {
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(fields[key])}`)
    })
    return parts.join('&')
  }

  /**
   * `multipart/form-data` POST with a single binary file part (the image) — for hosts like sm.ms that do
   * not accept a base64 form field. The body is built as a binary ArrayBuffer (ASCII preamble/epilogue +
   * raw image bytes) so it survives the proxy stack unchanged (string-encoding would corrupt the bytes).
   */
  static async postMultipart(
    url: string,
    headers: Record<string, string>,
    fileField: string,
    fileName: string,
    mimeType: string,
    bytes: Uint8Array,
  ): Promise<ImageUploadHttpResult> {
    const encoder = new util.TextEncoder()
    const preamble = `--${MULTIPART_BOUNDARY}\r\nContent-Disposition: form-data; name="${fileField}"; filename="${fileName}"\r\nContent-Type: ${mimeType}\r\n\r\n`
    const epilogue = `\r\n--${MULTIPART_BOUNDARY}--\r\n`
    const head = encoder.encodeInto(preamble)
    const tail = encoder.encodeInto(epilogue)
    const body = new Uint8Array(head.length + bytes.length + tail.length)
    body.set(head, 0)
    body.set(bytes, head.length)
    body.set(tail, head.length + bytes.length)
    const header: Record<string, string> = {}
    Object.keys(headers).forEach((key: string) => {
      header[key] = headers[key]
    })
    header['Content-Type'] = `multipart/form-data; boundary=${MULTIPART_BOUNDARY}`
    // Set Content-Length explicitly (matches the body exactly). The SOCKS5 path derives it in
    // buildRequestBytes and won't double it; NetworkKit/rcp use this rather than relying on auto-derivation
    // for a binary ArrayBuffer body.
    header['Content-Length'] = `${body.length}`
    const response: NetworkProxyResponse = await NetworkProxyRequest.request(url, {
      method: http.RequestMethod.POST,
      header: header,
      extraData: body.buffer as ArrayBuffer,
      connectTimeout: 15000,
      readTimeout: 60000,
      usingCache: false,
    })
    const result = typeof response.result === 'string' ? response.result : ''
    return { responseCode: response.responseCode, body: result }
  }
}
