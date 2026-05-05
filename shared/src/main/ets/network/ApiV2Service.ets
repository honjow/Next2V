import { http } from '@kit.NetworkKit'
import { HttpClient } from './HttpClient'
import { ApiConstants } from '../constants/ApiConstants'
import type { V2exNode, V2exTopic } from './NetworkTypes'

const MAX_RETRIES: number = 3
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 15000
const BACKOFF_BASE_MS: number = 1000

export interface ApiV2RateLimit {
  limit: number
  remaining: number
  reset: number
}

export interface ApiV2Response<T> {
  data: T | null
  headers: Record<string, Object>
  rateLimit: ApiV2RateLimit | null
  statusCode: number
}

/**
 * V2EX API v2 调用层（Token 认证）
 * - 仅做基础请求封装：GET/POST/DELETE
 * - 额外返回响应 headers（用于 rate-limit 等信息展示）
 */
export class ApiV2Service {
  private httpClient: HttpClient = HttpClient.getInstance()

  async getNode(token: string, nodeName: string): Promise<ApiV2Response<V2exNode>> {
    const cleanName = nodeName.trim()
    if (!cleanName) {
      throw new Error('节点名称不能为空')
    }
    return this.get<V2exNode>(`${ApiConstants.API_V2_NODE}/${encodeURIComponent(cleanName)}`, token)
  }

  async getNodeTopics(token: string, nodeName: string, page: number = 1): Promise<ApiV2Response<V2exTopic[]>> {
    const cleanName = nodeName.trim()
    if (!cleanName) {
      throw new Error('节点名称不能为空')
    }
    const cleanPage = page > 0 ? page : 1
    return this.get<V2exTopic[]>(
      `${ApiConstants.API_V2_NODE}/${encodeURIComponent(cleanName)}/topics?p=${cleanPage}`,
      token
    )
  }

  async get<T>(endpoint: string, token: string): Promise<ApiV2Response<T>> {
    return this.request<T>(endpoint, http.RequestMethod.GET, token)
  }

  async post<T>(endpoint: string, token: string, body?: Object | string): Promise<ApiV2Response<T>> {
    const extraData = ApiV2Service.stringifyBody(body)
    return this.request<T>(endpoint, http.RequestMethod.POST, token, extraData)
  }

  async delete<T>(endpoint: string, token: string): Promise<ApiV2Response<T>> {
    return this.request<T>(endpoint, http.RequestMethod.DELETE, token)
  }

  async request<T>(
    endpoint: string,
    method: http.RequestMethod,
    token: string,
    extraData: string = '',
    retryCount: number = MAX_RETRIES
  ): Promise<ApiV2Response<T>> {
    let httpRequest = http.createHttp()
    let headerBag: Object | null = null
    httpRequest.on('headersReceive', (headers: Object) => {
      headerBag = headers
    })

    const url = `${this.httpClient.getBaseUrl()}${endpoint}`
    const trimmedToken = token.trim()
    if (!trimmedToken) {
      throw new Error('缺少 Token，请先配置 Personal Access Token')
    }

    const requestHeaders: Record<string, string> = {
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'Authorization': `Bearer ${trimmedToken}`,
      'Content-Type': 'application/json'
    }

    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: requestHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.STRING
      }
      if (method === http.RequestMethod.POST && extraData) {
        options.extraData = extraData
      }

      const response = await httpRequest.request(url, options)
      const statusCode = response.responseCode as number
      const headers = ApiV2Service.normalizeHeaders(headerBag || response.header)
      const rateLimit = ApiV2Service.parseRateLimit(headers)

      if (statusCode < 200 || statusCode >= 300) {
        const apiMessage = ApiV2Service.extractApiMessage((response.result as string) || '')
        throw new Error(apiMessage || `HTTP ${statusCode}: ${endpoint}`)
      }

      const data = ApiV2Service.parseJsonOrNull<T>((response.result as string) || '')
      return { data, headers, rateLimit, statusCode }
    } catch (error) {
      if (retryCount > 0) {
        const delay = BACKOFF_BASE_MS * Math.pow(2, MAX_RETRIES - retryCount)
        await new Promise<void>(resolve => setTimeout(resolve, delay))
        return this.request<T>(endpoint, method, token, extraData, retryCount - 1)
      }
      const e = error as Error
      throw new Error(e.message || 'Network error')
    } finally {
      httpRequest.destroy()
    }
  }

  private static stringifyBody(body?: Object | string): string {
    if (!body) {
      return ''
    }
    if (typeof body === 'string') {
      return body
    }
    try {
      return JSON.stringify(body)
    } catch (e) {
      return ''
    }
  }

  private static parseJsonOrNull<T>(text: string): T | null {
    if (!text) {
      return null
    }
    try {
      return JSON.parse(text) as T
    } catch (e) {
      return null
    }
  }

  private static extractApiMessage(text: string): string {
    if (!text) {
      return ''
    }
    try {
      const obj = JSON.parse(text) as Record<string, Object>
      const message = obj['message']
      if (typeof message === 'string') {
        return message
      }
      return ''
    } catch (e) {
      return ''
    }
  }

  private static normalizeHeaders(headers: Object): Record<string, Object> {
    try {
      return headers as Record<string, Object>
    } catch (e) {
      return {} as Record<string, Object>
    }
  }

  private static parseRateLimit(headers: Record<string, Object>): ApiV2RateLimit | null {
    const limit = ApiV2Service.parseIntHeader(headers, 'x-rate-limit-limit')
    const remaining = ApiV2Service.parseIntHeader(headers, 'x-rate-limit-remaining')
    const reset = ApiV2Service.parseIntHeader(headers, 'x-rate-limit-reset')
    if (limit <= 0 && remaining <= 0 && reset <= 0) {
      return null
    }
    return { limit, remaining, reset }
  }

  private static parseIntHeader(headers: Record<string, Object>, keyLowerCase: string): number {
    const text = ApiV2Service.getHeaderValue(headers, keyLowerCase)
    if (!text) {
      return 0
    }
    const v = parseInt(text, 10)
    return Number.isNaN(v) ? 0 : v
  }

  private static getHeaderValue(headers: Record<string, Object>, keyLowerCase: string): string {
    const keys = Object.keys(headers)
    for (const key of keys) {
      if (key.toLowerCase() !== keyLowerCase) {
        continue
      }
      const v = headers[key]
      if (typeof v === 'string') {
        return v
      }
      if (Array.isArray(v) && v.length > 0 && typeof v[0] === 'string') {
        return v[0] as string
      }
      return ''
    }
    return ''
  }
}
