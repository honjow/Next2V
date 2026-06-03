import { connection, http } from '@kit.NetworkKit'
import { rcp } from '@kit.RemoteCommunicationKit'
import { ApiConstants } from '../constants/ApiConstants'
import { NetworkProxySettings, type NetworkProxySettingsSnapshot } from '../settings/NetworkProxySettings'
import { Socks5HttpClient } from './Socks5HttpClient'

export interface NetworkProxyRequestOptions {
  method: http.RequestMethod
  header?: Record<string, string>
  // string for form/urlencoded bodies; ArrayBuffer for binary multipart (image upload). All three
  // transports handle both: NetworkKit/rcp accept ArrayBuffer natively, and Socks5HttpClient already
  // branches on the ArrayBuffer case in buildRequestBytes().
  extraData?: string | ArrayBuffer
  connectTimeout?: number
  readTimeout?: number
  usingCache?: boolean
  expectDataType?: http.HttpDataType
  onHeadersReceive?: (headers: Object) => void
}

export interface NetworkProxyResponse {
  responseCode: number
  result: string | ArrayBuffer
  header: Object
  effectiveUrl: string
}

export class NetworkProxyRequest {
  static async request(url: string, options: NetworkProxyRequestOptions): Promise<NetworkProxyResponse> {
    const settings = NetworkProxySettings.current()
    if (settings.mode === 'socks5') {
      return NetworkProxyRequest.requestViaSocks5Socket(url, options, settings)
    }
    if (settings.proxyScheme === 'https') {
      return NetworkProxyRequest.requestViaRcp(url, options, settings)
    }
    return NetworkProxyRequest.requestViaNetworkKit(url, options, settings)
  }

  static async testConnection(baseUrl: string): Promise<NetworkProxyResponse> {
    return NetworkProxyRequest.request(`${baseUrl}${ApiConstants.API_SITE_INFO}`, {
      method: http.RequestMethod.GET,
      header: { 'Accept': 'application/json', 'Accept-Encoding': 'gzip' },
      connectTimeout: 10000,
      readTimeout: 15000,
      usingCache: false,
    })
  }

  static networkKitProxyOption(settings: NetworkProxySettingsSnapshot): boolean | connection.HttpProxy | undefined {
    const normalized = NetworkProxySettings.normalize(settings)
    if (normalized.mode === 'off') {
      return false
    }
    if (normalized.mode === 'system') {
      return true
    }
    if (normalized.mode === 'http') {
      return NetworkProxySettings.buildHttpProxy(normalized)
    }
    return undefined
  }

  private static async requestViaSocks5Socket(
    url: string,
    options: NetworkProxyRequestOptions,
    settings: NetworkProxySettingsSnapshot,
  ): Promise<NetworkProxyResponse> {
    const validation = NetworkProxySettings.validate(settings)
    if (!validation.ok) {
      throw new Error(validation.message)
    }
    const normalized = NetworkProxySettings.normalize(settings)
    return Socks5HttpClient.request(url, options, normalized)
  }

  private static async requestViaNetworkKit(
    url: string,
    options: NetworkProxyRequestOptions,
    settings: NetworkProxySettingsSnapshot,
  ): Promise<NetworkProxyResponse> {
    let httpRequest = http.createHttp()
    if (options.onHeadersReceive) {
      httpRequest.on('headersReceive', options.onHeadersReceive)
    }
    try {
      const requestHeaders: Record<string, string> = options.header || {}
      const httpOptions: http.HttpRequestOptions = {
        method: options.method,
        header: requestHeaders,
        connectTimeout: options.connectTimeout,
        readTimeout: options.readTimeout,
        usingCache: options.usingCache,
        expectDataType: options.expectDataType,
      }
      if (options.extraData) {
        httpOptions.extraData = options.extraData
      }
      const proxy = NetworkProxyRequest.networkKitProxyOption(settings)
      if (proxy !== undefined) {
        httpOptions.usingProxy = proxy
      }
      const response = await httpRequest.request(url, httpOptions)
      return {
        responseCode: response.responseCode as number,
        result: response.result as string | ArrayBuffer,
        header: response.header,
        effectiveUrl: '',
      }
    } finally {
      httpRequest.destroy()
    }
  }

  private static async requestViaRcp(
    url: string,
    options: NetworkProxyRequestOptions,
    settings: NetworkProxySettingsSnapshot,
  ): Promise<NetworkProxyResponse> {
    const validation = NetworkProxySettings.validate(settings)
    if (!validation.ok) {
      throw new Error(validation.message)
    }
    let session: rcp.Session | null = null
    try {
      session = rcp.createSession({
        requestConfiguration: {
          proxy: NetworkProxyRequest.rcpProxy(settings),
          transfer: {
            timeout: {
              connectMs: options.connectTimeout || 10000,
              transferMs: options.readTimeout || 15000,
              inactivityMs: options.readTimeout || 15000,
            },
          },
        },
      })
      const request = new rcp.Request(
        url,
        NetworkProxyRequest.rcpMethod(options.method),
        NetworkProxyRequest.rcpHeaders(options.header || {}),
        options.extraData,
      )
      const response = await session.fetch(request)
      const headers = response.headers as Object
      if (options.onHeadersReceive) {
        options.onHeadersReceive(headers)
      }
      const wantsArrayBuffer = options.expectDataType === http.HttpDataType.ARRAY_BUFFER
      return {
        responseCode: response.statusCode,
        result: wantsArrayBuffer ? (response.body || new ArrayBuffer(0)) : (response.toString() || ''),
        header: headers,
        effectiveUrl: response.effectiveUrl ? response.effectiveUrl.toString() : '',
      }
    } finally {
      if (session) {
        session.close()
      }
    }
  }

  private static rcpProxy(settings: NetworkProxySettingsSnapshot): rcp.ProxyConfiguration {
    const normalized = NetworkProxySettings.normalize(settings)
    if (normalized.mode === 'system') {
      return 'system'
    }
    if (normalized.mode === 'http') {
      const proxy: rcp.WebProxy = { url: NetworkProxySettings.buildHttpUrl(normalized), createTunnel: 'always' }
      if (normalized.exclusionList.length > 0) {
        proxy.exclusions = normalized.exclusionList
      }
      return proxy
    }
    if (normalized.mode === 'socks5') {
      const proxy: rcp.WebProxy = { url: NetworkProxySettings.buildSocks5Url(normalized), createTunnel: 'always' }
      if (normalized.exclusionList.length > 0) {
        proxy.exclusions = normalized.exclusionList
      }
      return proxy
    }
    return 'no-proxy'
  }

  private static rcpMethod(method: http.RequestMethod): rcp.HttpMethod {
    if (method === http.RequestMethod.POST) {
      return 'POST'
    }
    if (method === http.RequestMethod.PUT) {
      return 'PUT'
    }
    if (method === http.RequestMethod.DELETE) {
      return 'DELETE'
    }
    if (method === http.RequestMethod.HEAD) {
      return 'HEAD'
    }
    if (method === http.RequestMethod.OPTIONS) {
      return 'OPTIONS'
    }
    return 'GET'
  }

  private static rcpHeaders(headers: Record<string, string>): rcp.RequestHeaders {
    const result: rcp.RequestHeaders = {}
    Object.keys(headers).forEach((key: string) => {
      result[key] = headers[key]
    })
    return result
  }
}
