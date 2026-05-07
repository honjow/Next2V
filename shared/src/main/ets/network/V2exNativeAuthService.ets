import { http } from '@kit.NetworkKit'
import util from '@ohos.util'
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

export interface NativeLoginChallenge {
  cookie: string
  usernameField: string
  passwordField: string
  captchaField: string
  captchaUrl: string
  once: string
  next: string
}

export class V2exNativeAuthService {
  private httpClient: HttpClient = HttpClient.getInstance()

  async prepareLogin(): Promise<NativeLoginChallenge> {
    const baseUrl = this.httpClient.getBaseUrl()
    const signinUrl = `${baseUrl}/signin`

    const getRes = await this.requestText(signinUrl, http.RequestMethod.GET, '')
    const form = V2exSigninParser.extractForm(getRes.text)
    if (!form) {
      throw new Error('解析登录页面失败，请改用网页登录')
    }

    return {
      cookie: V2exNativeAuthService.mergeCookieHeader('', getRes.setCookie),
      usernameField: form.usernameField,
      passwordField: form.passwordField,
      captchaField: form.captchaField,
      captchaUrl: form.captchaUrl,
      once: form.once,
      next: form.next
    }
  }

  async login(username: string, password: string): Promise<NativeLoginSnapshot> {
    const challenge = await this.prepareLogin()
    if (challenge.captchaField) {
      throw new Error('当前 V2EX 登录需要验证码，请使用网页登录')
    }
    return this.loginWithChallenge(challenge, username, password, '')
  }

  async loginWithChallenge(
    challenge: NativeLoginChallenge,
    username: string,
    password: string,
    captchaCode: string
  ): Promise<NativeLoginSnapshot> {
    const baseUrl = this.httpClient.getBaseUrl()
    const signinUrl = `${baseUrl}/signin`

    const pairs: FormPair[] = [
      { key: challenge.usernameField, value: username },
      { key: challenge.passwordField, value: password }
    ]
    if (challenge.captchaField) {
      if (!captchaCode.trim()) {
        throw new Error('请输入验证码')
      }
      pairs.push({ key: challenge.captchaField, value: captchaCode.trim() })
    }
    pairs.push({ key: 'once', value: challenge.once })
    pairs.push({ key: 'next', value: challenge.next })
    const formBody = V2exNativeAuthService.encodeFormPairs(pairs)

    const postRes = await this.requestText(signinUrl, http.RequestMethod.POST, challenge.cookie, formBody)
    const cookieAfterPost = V2exNativeAuthService.mergeCookieHeader(challenge.cookie, postRes.setCookie)
    const loginError = V2exSigninParser.extractProblemMessage(postRes.text)
    if (loginError) {
      throw new Error(`登录失败：${loginError}`)
    }

    const settingsHtml = await this.httpClient.getTextWithHeaders('/settings', { 'Cookie': cookieAfterPost })
    const signedInUser = V2exSessionParser.extractUsername(settingsHtml)
    if (!signedInUser) {
      throw new Error('登录失败：可能需要验证码/2FA，请改用网页登录')
    }

    return { cookie: cookieAfterPost, username: signedInUser }
  }

  async fetchCaptchaDataUrl(challenge: NativeLoginChallenge): Promise<string> {
    if (!challenge.captchaUrl) {
      return ''
    }
    const captchaUrl = V2exNativeAuthService.absoluteUrl(this.httpClient.getBaseUrl(), challenge.captchaUrl)
    let httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(captchaUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'image/avif,image/webp,image/png,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Encoding': 'gzip',
          'Cookie': challenge.cookie,
          'Referer': `${this.httpClient.getBaseUrl()}/signin`,
          'User-Agent': 'Mozilla/5.0'
        },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      })
      if (response.responseCode !== http.ResponseCode.OK) {
        throw new Error(`HTTP ${response.responseCode}`)
      }
      const bytes = new Uint8Array(response.result as ArrayBuffer)
      const base64 = new util.Base64Helper().encodeToStringSync(bytes)
      return `data:image/png;base64,${base64}`
    } finally {
      httpRequest.destroy()
    }
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

  private static absoluteUrl(baseUrl: string, path: string): string {
    if (path.indexOf('http://') === 0 || path.indexOf('https://') === 0) {
      return path
    }
    return `${baseUrl}${path}`
  }

  private static extractSetCookieHeader(headers: Object): string[] {
    try {
      const bag = headers as Record<string, Object>
      const value = bag['set-cookie'] || bag['Set-Cookie'] || ''
      if (typeof value === 'string') {
        return V2exNativeAuthService.splitSetCookieHeader(value)
      }
      if (Array.isArray(value)) {
        const lines: string[] = []
        const items = value.filter((s: Object) => typeof s === 'string') as string[]
        for (const item of items) {
          lines.push(...V2exNativeAuthService.splitSetCookieHeader(item))
        }
        return lines
      }
      return []
    } catch (e) {
      return []
    }
  }

  private static splitSetCookieHeader(value: string): string[] {
    const clean = (value || '').trim()
    if (!clean) {
      return []
    }
    return clean.split(/,(?=\s*[^;,=\s]+=[^;]*)/g)
      .map((line: string) => line.trim())
      .filter((line: string) => line.length > 0)
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
