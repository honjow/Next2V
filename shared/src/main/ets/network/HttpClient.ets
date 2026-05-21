import { http } from '@kit.NetworkKit'
import { ApiConstants } from '../constants/ApiConstants'
import { HttpJsonParseError, HttpRetryPolicy, HttpStatusError } from './HttpRetryPolicy'
import { NetworkProxyRequest } from './NetworkProxyRequest'

const MAX_RETRIES: number = 3
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 15000
const BACKOFF_BASE_MS: number = 1000

export interface TextResponseWithHeaders {
  statusCode: number
  text: string
  location: string
}

/**
 * 通用 HTTP 客户端
 * - 超时控制（连接 10s / 读取 15s）
 * - 指数退避重试（最多 3 次）
 * - 请求后自动 destroy 防止内存泄漏
 * - 启用 HTTP 缓存
 */
export class HttpClient {
  private static instance: HttpClient
  private baseUrl: string = ApiConstants.BASE_URL_COM

  static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient()
    }
    return HttpClient.instance
  }

  setBaseUrl(url: string): void {
    this.baseUrl = url
  }

  getBaseUrl(): string {
    return this.baseUrl
  }

  async request<T>(
    endpoint: string,
    method?: http.RequestMethod,
    retryCount: number = MAX_RETRIES,
    headers?: Record<string, string>,
    usingCache?: boolean
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`
    const reqMethod = method || http.RequestMethod.GET
    let requestHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept-Encoding': 'gzip'
    }
    if (headers) {
      Object.keys(headers).forEach((key: string) => {
        requestHeaders[key] = headers[key]
      })
    }

    try {
      const response = await NetworkProxyRequest.request(url, {
        method: reqMethod,
        header: requestHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: usingCache ?? !HttpClient.hasAuthHeader(requestHeaders)
      })

      if (response.responseCode !== http.ResponseCode.OK) {
        throw new HttpStatusError(response.responseCode as number, url)
      }

      try {
        return JSON.parse(response.result as string) as T
      } catch (error) {
        const e = error as Error
        throw new HttpJsonParseError(e.message || 'JSON parse failed')
      }
    } catch (error) {
      const e = error as Error
      if (retryCount > 0 && HttpRetryPolicy.shouldRetry(reqMethod, e)) {
        const delay = BACKOFF_BASE_MS * Math.pow(2, MAX_RETRIES - retryCount)
        await new Promise<void>(resolve => setTimeout(resolve, delay))
        return this.request<T>(endpoint, method, retryCount - 1, headers, usingCache)
      }
      throw new Error(HttpClient.formatRequestError(e))
    }
  }

  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, http.RequestMethod.GET)
  }

  async getWithHeaders<T>(endpoint: string, headers: Record<string, string>): Promise<T> {
    return this.request<T>(endpoint, http.RequestMethod.GET, MAX_RETRIES, headers)
  }

  async getNoCache<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, http.RequestMethod.GET, MAX_RETRIES, HttpClient.noCacheHeaders(), false)
  }

  async getNoCacheWithHeaders<T>(endpoint: string, headers: Record<string, string>): Promise<T> {
    const merged: Record<string, string> = HttpClient.noCacheHeaders()
    Object.keys(headers).forEach((key: string) => {
      merged[key] = headers[key]
    })
    return this.request<T>(endpoint, http.RequestMethod.GET, MAX_RETRIES, merged, false)
  }

  /** GET 请求获取纯文本（用于 HTML 抓取） */
  async getText(endpoint: string): Promise<string> {
    return this.requestText(endpoint, http.RequestMethod.GET)
  }

  /** GET 请求获取纯文本（附带自定义 headers，例如 Cookie） */
  async getTextWithHeaders(endpoint: string, headers: Record<string, string>): Promise<string> {
    return this.requestText(endpoint, http.RequestMethod.GET, MAX_RETRIES, headers)
  }

  /** GET 请求获取纯文本和响应头（用于 Cookie 私有页识别 /2fa redirect） */
  async getTextResponseWithHeaders(endpoint: string, headers: Record<string, string>): Promise<TextResponseWithHeaders> {
    return this.requestTextResponse(endpoint, http.RequestMethod.GET, MAX_RETRIES, headers)
  }

  /**
   * 纯文本请求，返回原始字符串（不执行 JSON.parse）
   */
  async requestText(
    endpoint: string,
    method?: http.RequestMethod,
    retryCount: number = MAX_RETRIES,
    headers?: Record<string, string>,
    usingCache?: boolean
  ): Promise<string> {
    const url = `${this.baseUrl}${endpoint}`
    const reqMethod = method || http.RequestMethod.GET
    let requestHeaders: Record<string, string> = {
      'Content-Type': 'text/html; charset=utf-8',
      'Accept-Encoding': 'gzip'
    }
    if (headers) {
      Object.keys(headers).forEach((key: string) => {
        requestHeaders[key] = headers[key]
      })
    }

    try {
      const response = await NetworkProxyRequest.request(url, {
        method: reqMethod,
        header: requestHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: usingCache ?? !HttpClient.hasAuthHeader(requestHeaders)
      })

      if (response.responseCode !== http.ResponseCode.OK) {
        throw new HttpStatusError(response.responseCode as number, url)
      }

      return response.result as string
    } catch (error) {
      const e = error as Error
      if (retryCount > 0 && HttpRetryPolicy.shouldRetry(reqMethod, e)) {
        const delay = BACKOFF_BASE_MS * Math.pow(2, MAX_RETRIES - retryCount)
        await new Promise<void>(resolve => setTimeout(resolve, delay))
        return this.requestText(endpoint, method, retryCount - 1, headers, usingCache)
      }
      throw new Error(HttpClient.formatRequestError(e))
    }
  }


  async requestTextResponse(
    endpoint: string,
    method?: http.RequestMethod,
    retryCount: number = MAX_RETRIES,
    headers?: Record<string, string>,
    usingCache?: boolean
  ): Promise<TextResponseWithHeaders> {
    const url = `${this.baseUrl}${endpoint}`
    const reqMethod = method || http.RequestMethod.GET
    let headerBag: Object | null = null
    let receivedLocation: string = ''
    let requestHeaders: Record<string, string> = {
      'Content-Type': 'text/html; charset=utf-8',
      'Accept-Encoding': 'gzip'
    }
    if (headers) {
      Object.keys(headers).forEach((key: string) => {
        requestHeaders[key] = headers[key]
      })
    }

    try {
      const response = await NetworkProxyRequest.request(url, {
        method: reqMethod,
        header: requestHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: usingCache ?? !HttpClient.hasAuthHeader(requestHeaders),
        onHeadersReceive: (received: Object) => {
          headerBag = received
          const location = HttpClient.extractSingleHeader(received, 'location')
          if (location) {
            receivedLocation = location
          }
        }
      })

      const statusCode = response.responseCode as number
      const responseHeaders = headerBag || response.header
      const location = HttpClient.extractSingleHeader(responseHeaders, 'location') || receivedLocation
      if (statusCode >= 300 && statusCode < 400) {
        return { statusCode, text: (response.result as string) || '', location }
      }
      if (statusCode < 200 || statusCode >= 400) {
        throw new HttpStatusError(statusCode, url)
      }
      return { statusCode, text: (response.result as string) || '', location }
    } catch (error) {
      const e = error as Error
      if (retryCount > 0 && HttpRetryPolicy.shouldRetry(reqMethod, e)) {
        const delay = BACKOFF_BASE_MS * Math.pow(2, MAX_RETRIES - retryCount)
        await new Promise<void>(resolve => setTimeout(resolve, delay))
        return this.requestTextResponse(endpoint, method, retryCount - 1, headers, usingCache)
      }
      throw new Error(HttpClient.formatRequestError(e))
    }
  }

  private static extractSingleHeader(headers: Object, name: string): string {
    try {
      const bag = headers as Record<string, Object>
      const lower = name.toLowerCase()
      const exact = bag[name] || bag[lower] || bag[name.toUpperCase()]
      if (typeof exact === 'string') {
        return exact.trim()
      }
      if (Array.isArray(exact)) {
        const values = exact.filter((s: Object) => typeof s === 'string') as string[]
        return values.length > 0 ? values[0].trim() : ''
      }
      const keys = Object.keys(bag)
      const matched = keys.find((key: string) => key.toLowerCase() === lower)
      if (!matched) {
        return ''
      }
      const value = bag[matched]
      if (typeof value === 'string') {
        return value.trim()
      }
      if (Array.isArray(value)) {
        const values = value.filter((s: Object) => typeof s === 'string') as string[]
        return values.length > 0 ? values[0].trim() : ''
      }
      return ''
    } catch (_e) {
      return ''
    }
  }

  private static hasAuthHeader(headers: Record<string, string>): boolean {
    const cookie = headers['Cookie'] || headers['cookie'] || ''
    const authorization = headers['Authorization'] || headers['authorization'] || ''
    return cookie.trim().length > 0 || authorization.trim().length > 0
  }

  private static formatRequestError(error: Error): string {
    if (error instanceof HttpStatusError || error instanceof HttpJsonParseError) {
      return error.message
    }
    return `Network error: ${error.message || 'unknown'}`
  }

  private static noCacheHeaders(): Record<string, string> {
    return {
      'Cache-Control': 'no-cache, no-store, max-age=0',
      'Pragma': 'no-cache'
    }
  }
}
