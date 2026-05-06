import { http } from '@kit.NetworkKit'
import type { Sov2exHit, Sov2exSearchOptions, Sov2exSearchResponse } from './NetworkTypes'

const SOV2EX_SEARCH_URL: string = 'https://www.sov2ex.com/api/search'
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 15000

export class Sov2exService {
  async search(options: Sov2exSearchOptions): Promise<Sov2exSearchResponse> {
    const q = (options.q ?? '').trim()
    if (!q) {
      return { took: 0, timed_out: false, total: 0, hits: [] }
    }

    const params: string[] = [
      `q=${encodeURIComponent(q)}`,
      `from=${options.from ?? 0}`,
      `size=${options.size ?? 20}`,
      `sort=${encodeURIComponent(options.sort ?? 'created')}`,
      `order=${encodeURIComponent(options.order ?? '0')}`
    ]
    if (options.username) {
      params.push(`username=${encodeURIComponent(options.username.trim())}`)
    }
    if (options.node) {
      params.push(`node=${encodeURIComponent(options.node.trim())}`)
    }
    if (options.gte && options.gte > 0) {
      params.push(`gte=${options.gte}`)
    }
    if (options.lte && options.lte > 0) {
      params.push(`lte=${options.lte}`)
    }

    const request = http.createHttp()
    try {
      const response = await request.request(`${SOV2EX_SEARCH_URL}?${params.join('&')}`, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip'
        },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: true
      })
      if (response.responseCode !== http.ResponseCode.OK) {
        throw new Error(`SOV2EX HTTP ${response.responseCode}`)
      }
      return Sov2exService.normalizeResponse(JSON.parse(response.result as string) as Sov2exSearchResponse)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'SOV2EX 搜索失败')
    } finally {
      request.destroy()
    }
  }

  private static normalizeResponse(response: Sov2exSearchResponse): Sov2exSearchResponse {
    const hits = response.hits || []
    for (const hit of hits) {
      Sov2exService.normalizeHit(hit)
    }
    response.hits = hits
    return response
  }

  private static normalizeHit(hit: Sov2exHit): void {
    const raw = hit.highlight as Object
    if (!raw || !hit.highlight) {
      return
    }
    const value = Reflect.get(raw, 'reply_list.content') as string[] | undefined
    if (value) {
      hit.highlight.replyListContent = value
    }
  }
}
