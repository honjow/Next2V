import { http } from '@kit.NetworkKit'

/**
 * 通用 HTTP 客户端
 * - 超时控制（连接 10s / 读取 15s）
 * - 指数退避重试（最多 3 次）
 * - 请求后自动 destroy 防止内存泄漏
 * - 启用 HTTP 缓存
 */
export class HttpClient {
  private static instance: HttpClient
  private baseUrl: string = 'https://www.v2ex.com'

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
    retryCount: number = 3
  ): Promise<T> {
    let httpRequest = http.createHttp()
    const url = `${this.baseUrl}${endpoint}`
    const reqMethod = method || http.RequestMethod.GET

    try {
      const response = await httpRequest.request(url, {
        method: reqMethod,
        header: {
          'Content-Type': 'application/json',
          'Accept-Encoding': 'gzip'
        },
        connectTimeout: 10000,
        readTimeout: 15000,
        usingCache: true
      })

      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}: ${url}`)
      }

      return JSON.parse(response.result as string) as T
    } catch (error) {
      if (retryCount > 0) {
        // 指数退避: 1s → 2s → 4s
        const delay = 1000 * Math.pow(2, 3 - retryCount)
        await new Promise<void>(resolve => setTimeout(resolve, delay))
        return this.request<T>(endpoint, method, retryCount - 1)
      }
      throw new Error(`Network error: ${error.message}`)
    } finally {
      httpRequest.destroy()
    }
  }

  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, http.RequestMethod.GET)
  }
}
