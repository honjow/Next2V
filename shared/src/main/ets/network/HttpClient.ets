import { http } from '@kit.NetworkKit'
import { ApiConstants } from '../constants/ApiConstants'

const MAX_RETRIES: number = 3
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 15000
const BACKOFF_BASE_MS: number = 1000

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
    headers?: Record<string, string>
  ): Promise<T> {
    let httpRequest = http.createHttp()
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
      const response = await httpRequest.request(url, {
        method: reqMethod,
        header: requestHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: true
      })

      if (response.responseCode !== http.ResponseCode.OK) {
        throw new Error(`HTTP ${response.responseCode}: ${url}`)
      }

      return JSON.parse(response.result as string) as T
    } catch (error) {
      if (retryCount > 0) {
        const delay = BACKOFF_BASE_MS * Math.pow(2, MAX_RETRIES - retryCount)
        await new Promise<void>(resolve => setTimeout(resolve, delay))
        return this.request<T>(endpoint, method, retryCount - 1, headers)
      }
      throw new Error(`Network error: ${error.message}`)
    } finally {
      httpRequest.destroy()
    }
  }

  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, http.RequestMethod.GET)
  }

  async getWithHeaders<T>(endpoint: string, headers: Record<string, string>): Promise<T> {
    return this.request<T>(endpoint, http.RequestMethod.GET, MAX_RETRIES, headers)
  }

  /** GET 请求获取纯文本（用于 HTML 抓取） */
  async getText(endpoint: string): Promise<string> {
    return this.requestText(endpoint, http.RequestMethod.GET)
  }

  /** GET 请求获取纯文本（附带自定义 headers，例如 Cookie） */
  async getTextWithHeaders(endpoint: string, headers: Record<string, string>): Promise<string> {
    return this.requestText(endpoint, http.RequestMethod.GET, MAX_RETRIES, headers)
  }

  /**
   * 纯文本请求，返回原始字符串（不执行 JSON.parse）
   */
  async requestText(
    endpoint: string,
    method?: http.RequestMethod,
    retryCount: number = MAX_RETRIES,
    headers?: Record<string, string>
  ): Promise<string> {
    let httpRequest = http.createHttp()
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
      const response = await httpRequest.request(url, {
        method: reqMethod,
        header: requestHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: true
      })

      if (response.responseCode !== http.ResponseCode.OK) {
        throw new Error(`HTTP ${response.responseCode}: ${url}`)
      }

      return response.result as string
    } catch (error) {
      if (retryCount > 0) {
        const delay = BACKOFF_BASE_MS * Math.pow(2, MAX_RETRIES - retryCount)
        await new Promise<void>(resolve => setTimeout(resolve, delay))
        return this.requestText(endpoint, method, retryCount - 1)
      }
      throw new Error(`Network error: ${error.message}`)
    } finally {
      httpRequest.destroy()
    }
  }
}
