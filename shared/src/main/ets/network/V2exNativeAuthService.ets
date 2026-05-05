import { http } from '@kit.NetworkKit'
import { HttpClient } from './HttpClient'
import { V2exSigninParser } from '../parser/V2exSigninParser'
import { V2exSessionParser } from '../parser/V2exSessionParser'

const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 15000

interface TextWithSetCookie {
  text: string
  setCookie: string[]
}

interface CookiePair {
  name: string
  value: string
}

interface FormPair {
  key: string
  value: string
}

export interface NativeLoginSnapshot {
  cookie: string
  username: string
}

export class V2exNativeAuthService {
  private httpClient: HttpClient = HttpClient.getInstance()

  async login(username: string, password: string): Promise<NativeLoginSnapshot> {
    const baseUrl = this.httpClient.getBaseUrl()
    const signinUrl = `${baseUrl}/signin`

    const getRes = await this.requestText(signinUrl, http.RequestMethod.GET, '')
    const form = V2exSigninParser.extractForm(getRes.text)
    if (!form) {
      throw new Error('解析登录页面失败，请改用网页登录')
    }

    const cookieAfterGet = V2exNativeAuthService.mergeCookieHeader('', getRes.setCookie)
    const postCookie = cookieAfterGet

    const pairs: FormPair[] = [
      { key: form.usernameField, value: username },
      { key: form.passwordField, value: password },
      { key: 'once', value: form.once },
      { key: 'next', value: form.next }
    ]
    const formBody = V2exNativeAuthService.encodeFormPairs(pairs)

    const postRes = await this.requestText(signinUrl, http.RequestMethod.POST, postCookie, formBody)
    const cookieAfterPost = V2exNativeAuthService.mergeCookieHeader(postCookie, postRes.setCookie)

    const settingsHtml = await this.httpClient.getTextWithHeaders('/settings', { 'Cookie': cookieAfterPost })
    const signedInUser = V2exSessionParser.extractUsername(settingsHtml)
    if (!signedInUser) {
      throw new Error('登录失败：可能需要验证码/2FA，请改用网页登录')
    }

    return { cookie: cookieAfterPost, username: signedInUser }
  }

  private async requestText(
    url: string,
    method: http.RequestMethod,
    cookieHeader: string,
    extraData: string = ''
  ): Promise<TextWithSetCookie> {
    let httpRequest = http.createHttp()
    let headerBag: Object | null = null
    httpRequest.on('headersReceive', (headers: Object) => {
      headerBag = headers
    })

    try {
      const reqHeaders: Record<string, string> = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip',
        'Content-Type': method === http.RequestMethod.POST ? 'application/x-www-form-urlencoded' : 'text/html; charset=utf-8',
        'User-Agent': 'Mozilla/5.0'
      }
      if (cookieHeader) {
        reqHeaders['Cookie'] = cookieHeader
      }
      if (method === http.RequestMethod.POST) {
        reqHeaders['Referer'] = url
      }

      const options: http.HttpRequestOptions = {
        method: method,
        header: reqHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false
      }
      if (method === http.RequestMethod.POST) {
        options.extraData = extraData
      }
      const response = await httpRequest.request(url, options)

      const text = (response.result as string) || ''
      const setCookie = V2exNativeAuthService.extractSetCookieHeader(headerBag || response.header)
      return { text, setCookie }
    } finally {
      httpRequest.destroy()
    }
  }

  private static extractSetCookieHeader(headers: Object): string[] {
    try {
      const bag = headers as Record<string, Object>
      const value = bag['set-cookie'] || bag['Set-Cookie'] || ''
      if (typeof value === 'string') {
        return value ? [value] : []
      }
      if (Array.isArray(value)) {
        return value.filter((s: Object) => typeof s === 'string') as string[]
      }
      return []
    } catch (e) {
      return []
    }
  }

  private static mergeCookieHeader(existingCookieHeader: string, setCookieLines: string[]): string {
    const jar = V2exNativeAuthService.parseCookieHeader(existingCookieHeader)
    for (const line of setCookieLines) {
      const pair = V2exNativeAuthService.extractCookiePair(line)
      if (!pair) {
        continue
      }
      jar[pair.name] = pair.value
    }
    return V2exNativeAuthService.cookieHeaderFromJar(jar)
  }

  private static extractCookiePair(setCookieLine: string): CookiePair | null {
    const part = setCookieLine.split(';')[0]?.trim() || ''
    const idx = part.indexOf('=')
    if (idx <= 0) {
      return null
    }
    const name = part.slice(0, idx).trim()
    const value = part.slice(idx + 1).trim()
    if (!name) {
      return null
    }
    return { name, value }
  }

  private static parseCookieHeader(cookieHeader: string): Record<string, string> {
    const jar: Record<string, string> = {}
    const parts = (cookieHeader || '').split(';').map(p => p.trim()).filter(p => p.length > 0)
    for (const part of parts) {
      const idx = part.indexOf('=')
      if (idx <= 0) {
        continue
      }
      const name = part.slice(0, idx).trim()
      const value = part.slice(idx + 1).trim()
      if (!name) {
        continue
      }
      jar[name] = value
    }
    return jar
  }

  private static cookieHeaderFromJar(jar: Record<string, string>): string {
    const keys = Object.keys(jar)
    if (keys.length === 0) {
      return ''
    }
    return keys.map(k => `${k}=${jar[k]}`).join('; ')
  }

  private static encodeFormPairs(formPairs: FormPair[]): string {
    if (formPairs.length === 0) {
      return ''
    }
    const encodedPairs: string[] = []
    for (const item of formPairs) {
      encodedPairs.push(`${encodeURIComponent(item.key)}=${encodeURIComponent(item.value)}`)
    }
    return encodedPairs.join('&')
  }
}
