import { http } from '@kit.NetworkKit'
import { NetworkProxyRequest, NetworkProxyResponse } from './NetworkProxyRequest'

export interface ImageUploadHttpResult {
  responseCode: number
  body: string
}

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
}
