import { http } from '@kit.NetworkKit'

export class HttpStatusError extends Error {
  statusCode: number

  constructor(statusCode: number, url: string, message: string = '') {
    super(message || `HTTP ${statusCode}: ${url}`)
    this.name = 'HttpStatusError'
    this.statusCode = statusCode
  }
}

export class HttpJsonParseError extends Error {
  constructor(message: string) {
    super(message || 'JSON parse failed')
    this.name = 'HttpJsonParseError'
  }
}

export class HttpRetryPolicy {
  static shouldRetry(method: http.RequestMethod, error: Error): boolean {
    if (method !== http.RequestMethod.GET) {
      return false
    }
    if (error instanceof HttpJsonParseError) {
      return false
    }
    if (error instanceof HttpStatusError) {
      return HttpRetryPolicy.isRetryableStatus(error.statusCode)
    }
    return true
  }

  static isRetryableStatus(statusCode: number): boolean {
    return statusCode === 408 || (statusCode >= 500 && statusCode < 600)
  }
}
