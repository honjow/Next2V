import { http } from '@kit.NetworkKit'
import { HttpClient } from './HttpClient'
import { ApiConstants } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { HtmlEntityUtils } from '../utils/HtmlEntityUtils'
import type { V2exNode, V2exReply, V2exTopic } from './NetworkTypes'

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
    const res = await this.get<V2exNode>(`${ApiConstants.API_V2_NODE}/${encodeURIComponent(cleanName)}`, token)
    if (res.data) {
      ApiV2Service.normalizeNode(res.data)
    }
    return res
  }

  async getNodeTopics(token: string, nodeName: string, page: number = 1): Promise<ApiV2Response<V2exTopic[]>> {
    const cleanName = nodeName.trim()
    if (!cleanName) {
      throw new Error('节点名称不能为空')
    }
    const cleanPage = page > 0 ? page : 1
    const res = await this.get<V2exTopic[]>(
      `${ApiConstants.API_V2_NODE}/${encodeURIComponent(cleanName)}/topics?p=${cleanPage}`,
      token
    )
    if (res.data) {
      res.data = ApiV2Service.normalizeTopics(res.data)
    }
    return res
  }

  async getTopic(token: string, topicId: number): Promise<ApiV2Response<V2exTopic>> {
    if (topicId <= 0) {
      throw new Error('无效的主题 ID')
    }
    const res = await this.get<V2exTopic>(`${ApiConstants.API_V2_TOPIC}/${topicId}`, token)
    if (res.data) {
      ApiV2Service.normalizeTopic(res.data)
    }
    return res
  }

  async getTopicReplies(token: string, topicId: number, page: number = 1): Promise<ApiV2Response<V2exReply[]>> {
    if (topicId <= 0) {
      throw new Error('无效的主题 ID')
    }
    const cleanPage = page > 0 ? page : 1
    const res = await this.get<Object>(`${ApiConstants.API_V2_TOPIC}/${topicId}/replies?p=${cleanPage}`, token)
    const replies = ApiV2Service.normalizeReplies(ApiV2Service.unwrapList<V2exReply>(res.data))
    return { data: replies, headers: res.headers, rateLimit: res.rateLimit, statusCode: res.statusCode }
  }

  async deleteNotification(token: string, notificationId: number): Promise<ApiV2Response<Object>> {
    if (notificationId <= 0) {
      throw new Error('无效的通知 ID')
    }
    return this.delete<Object>(`${ApiConstants.API_V2_NOTIFICATIONS}/${notificationId}`, token)
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
      ApiV2Service.saveRateLimitSnapshot(rateLimit)

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

  private static unwrapList<T>(data: Object | null): T[] {
    if (!data) {
      return []
    }
    if (Array.isArray(data)) {
      return data as T[]
    }
    try {
      const bag = data as Record<string, Object>
      const candidates: string[] = ['result', 'items', 'replies', 'data']
      for (const key of candidates) {
        const v = bag[key]
        if (Array.isArray(v)) {
          return v as T[]
        }
      }
    } catch (e) {
      // ignore
    }
    return []
  }

  private static normalizeTopics(topics: V2exTopic[]): V2exTopic[] {
    return (topics || []).map((topic: V2exTopic) => ApiV2Service.normalizeTopic(topic))
  }

  private static normalizeTopic(topic: V2exTopic): V2exTopic {
    if (!topic) {
      return topic
    }
    topic.title = HtmlEntityUtils.decode(topic.title)
    topic.content = HtmlEntityUtils.decode(topic.content)
    if (topic.node) {
      ApiV2Service.normalizeNode(topic.node)
    }
    if (topic.member) {
      topic.member.tagline = HtmlEntityUtils.decode(topic.member.tagline)
    }
    return topic
  }

  private static normalizeReplies(replies: V2exReply[]): V2exReply[] {
    return (replies || []).map((reply: V2exReply) => ApiV2Service.normalizeReply(reply))
  }

  private static normalizeReply(reply: V2exReply): V2exReply {
    if (!reply) {
      return reply
    }
    reply.content = HtmlEntityUtils.decode(reply.content)
    if (reply.member) {
      reply.member.tagline = HtmlEntityUtils.decode(reply.member.tagline)
    }
    return reply
  }

  private static normalizeNode(node: V2exNode): V2exNode {
    if (!node) {
      return node
    }
    node.title = HtmlEntityUtils.decode(node.title)
    node.title_alternative = HtmlEntityUtils.decode(node.title_alternative)
    node.header = HtmlEntityUtils.decode(node.header || '')
    node.footer = HtmlEntityUtils.decode(node.footer || '')
    return node
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

  private static saveRateLimitSnapshot(rateLimit: ApiV2RateLimit | null): void {
    if (!rateLimit) {
      return
    }
    try {
      AppStorage.setOrCreate<number>(StorageKeys.API_RATE_LIMIT_LIMIT, rateLimit.limit)
      AppStorage.setOrCreate<number>(StorageKeys.API_RATE_LIMIT_REMAINING, rateLimit.remaining)
      AppStorage.setOrCreate<number>(StorageKeys.API_RATE_LIMIT_RESET, rateLimit.reset)
      AppStorage.setOrCreate<number>(StorageKeys.API_RATE_LIMIT_UPDATED_AT, Math.floor(Date.now() / 1000))
    } catch (e) {
      // ignore
    }
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
