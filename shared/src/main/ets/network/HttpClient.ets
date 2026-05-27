import { http } from '@kit.NetworkKit'
import { ApiConstants } from '../constants/ApiConstants'
import { HttpJsonParseError, HttpRetryPolicy, HttpStatusError } from './HttpRetryPolicy'
import { NetworkProxyRequest } from './NetworkProxyRequest'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

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
 * General-purpose HTTP client
 * - Timeout control (connect 10s / read 15s)
 * - Exponential backoff retry (max 3 attempts)
 * - Auto-destroy after request to prevent memory leaks
 * - Enable HTTP caching
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
    // Base URL is a request/web origin preference. CookieJarSettings separately
    // resolves whether auth belongs to the shared V2EX first-party scope or an
    // exact custom-host scope; callers still refresh configured state and restore
    // WebCookieManager after changing the selected origin.
    const cleanUrl = (url || ApiConstants.BASE_URL_COM).trim()
    this.baseUrl = cleanUrl.endsWith('/') ? cleanUrl.slice(0, cleanUrl.length - 1) : cleanUrl
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
      DiagnosticLogger.exception('network', 'http_json_request_exception', e, {
        method: HttpClient.methodLabel(reqMethod),
        url: url,
        endpoint: endpoint,
        retryCount: retryCount,
        willRetry: retryCount > 0 && HttpRetryPolicy.shouldRetry(reqMethod, e)
      })
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

  /** GET request for plain text (for HTML scraping) */
  async getText(endpoint: string): Promise<string> {
    return this.requestText(endpoint, http.RequestMethod.GET)
  }

  /** GET request for plain text with custom headers (e.g. Cookie) */
  async getTextWithHeaders(endpoint: string, headers: Record<string, string>): Promise<string> {
    return this.requestText(endpoint, http.RequestMethod.GET, MAX_RETRIES, headers)
  }

  /** GET request for plain text and response headers (for Cookie private-page detection / 2FA redirect) */
  async getTextResponseWithHeaders(endpoint: string, headers: Record<string, string>): Promise<TextResponseWithHeaders> {
    return this.requestTextResponse(endpoint, http.RequestMethod.GET, MAX_RETRIES, headers)
  }

  /**
   * Plain text request, returns raw string (no JSON.parse)
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
      DiagnosticLogger.exception('network', 'http_text_request_exception', e, {
        method: HttpClient.methodLabel(reqMethod),
        url: url,
        endpoint: endpoint,
        retryCount: retryCount,
        willRetry: retryCount > 0 && HttpRetryPolicy.shouldRetry(reqMethod, e)
      })
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
      if (statusCode >= 400) {
        DiagnosticLogger.warn('network', 'http_text_response_error_status', {
          method: HttpClient.methodLabel(reqMethod),
          url: url,
          endpoint: endpoint,
          statusCode: statusCode,
          location: location,
          hasCookie: HttpClient.hasAuthHeader(requestHeaders),
          usingCache: usingCache ?? !HttpClient.hasAuthHeader(requestHeaders)
        })
      } else {
        DiagnosticLogger.info('network', 'http_text_response_status', {
          method: HttpClient.methodLabel(reqMethod),
          url: url,
          endpoint: endpoint,
          statusCode: statusCode,
          location: location,
          hasCookie: HttpClient.hasAuthHeader(requestHeaders),
          usingCache: usingCache ?? !HttpClient.hasAuthHeader(requestHeaders)
        })
      }
      if (statusCode >= 300 && statusCode < 400) {
        return { statusCode, text: (response.result as string) || '', location }
      }
      if (statusCode < 200 || statusCode >= 400) {
        throw new HttpStatusError(statusCode, url)
      }
      return { statusCode, text: (response.result as string) || '', location }
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('network', 'http_text_response_request_exception', e, {
        method: HttpClient.methodLabel(reqMethod),
        url: url,
        endpoint: endpoint,
        retryCount: retryCount,
        willRetry: retryCount > 0 && HttpRetryPolicy.shouldRetry(reqMethod, e)
      })
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

  private static methodLabel(method: http.RequestMethod): string {
    if (method === http.RequestMethod.POST) {
      return 'POST'
    }
    if (method === http.RequestMethod.PUT) {
      return 'PUT'
    }
    if (method === http.RequestMethod.DELETE) {
      return 'DELETE'
    }
    return 'GET'
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
