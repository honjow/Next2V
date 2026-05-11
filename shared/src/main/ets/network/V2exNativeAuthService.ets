import { http } from '@kit.NetworkKit'
import util from '@ohos.util'
import { HttpClient } from './HttpClient'
import { V2exSigninParser } from '../parser/V2exSigninParser'
import { V2exSessionParser } from '../parser/V2exSessionParser'

const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 15000
const DEBUG_SKIP_LOGIN_2FA: boolean = false

interface TextWithSetCookie {
  text: string
  setCookie: string[]
  statusCode: number
  location: string
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

export interface NativeTwoFactorChallenge {
  cookie: string
  action: string
  codeField: string
  hiddenFields: Record<string, string>
}

export class NativeTwoFactorRequiredError extends Error {
  challenge: NativeTwoFactorChallenge

  constructor(challenge: NativeTwoFactorChallenge, message: string = '需要两步验证码') {
    super(message)
    this.name = 'NativeTwoFactorRequiredError'
    this.challenge = challenge
  }
}

export class V2exNativeAuthService {
  private httpClient: HttpClient = HttpClient.getInstance()
  private static readonly TWO_FACTOR_PATH: string = '/2fa'
  private static readonly SETTINGS_PATH: string = '/settings'

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
    if (V2exNativeAuthService.isLocationPath(postRes.location, V2exNativeAuthService.TWO_FACTOR_PATH)) {
      if (DEBUG_SKIP_LOGIN_2FA) {
        return { cookie: cookieAfterPost, username: username }
      }
      throw new NativeTwoFactorRequiredError(V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterPost))
    }

    const loginError = V2exSigninParser.extractProblemMessage(postRes.text)
    if (V2exNativeAuthService.isLocationPath(postRes.location, '/signin') || loginError) {
      throw new Error(`登录失败：${loginError || '用户名、密码或验证码不正确'}`)
    }
    if (DEBUG_SKIP_LOGIN_2FA) {
      return { cookie: cookieAfterPost, username: username }
    }

    const postTwoFactor = V2exSigninParser.extractTwoFactorForm(postRes.text)
    if (postTwoFactor) {
      if (DEBUG_SKIP_LOGIN_2FA) {
        return { cookie: cookieAfterPost, username: username }
      }
      throw new NativeTwoFactorRequiredError(V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterPost, postTwoFactor.hiddenFields))
    }

    const settingsRes = await this.requestText(`${baseUrl}${V2exNativeAuthService.SETTINGS_PATH}`, http.RequestMethod.GET, cookieAfterPost)
    const signedInUser = V2exSessionParser.extractUsername(settingsRes.text)
    if (!signedInUser) {
      if (V2exNativeAuthService.isLocationPath(settingsRes.location, V2exNativeAuthService.TWO_FACTOR_PATH)) {
        if (DEBUG_SKIP_LOGIN_2FA) {
          return { cookie: cookieAfterPost, username: username }
        }
        throw new NativeTwoFactorRequiredError(V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterPost))
      }
      const settingsTwoFactor = V2exSigninParser.extractTwoFactorForm(settingsRes.text)
      if (settingsTwoFactor) {
        if (DEBUG_SKIP_LOGIN_2FA) {
          return { cookie: cookieAfterPost, username: username }
        }
        throw new NativeTwoFactorRequiredError(V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterPost, settingsTwoFactor.hiddenFields))
      }
      if (postRes.location && !V2exNativeAuthService.isLocationPath(postRes.location, '/') &&
        !V2exNativeAuthService.isLocationPath(postRes.location, V2exNativeAuthService.SETTINGS_PATH)) {
        throw new Error(`登录失败：不支持的跳转 ${postRes.location}`)
      }
      throw new Error('登录失败：无法通过私有页面验证会话，请改用网页登录')
    }

    return { cookie: cookieAfterPost, username: signedInUser }
  }

  async completeTwoFactorWithCookie(cookie: string, code: string): Promise<NativeLoginSnapshot> {
    const cleanCookie = (cookie || '').trim()
    if (!cleanCookie) {
      throw new Error('缺少登录会话，请重新登录')
    }
    const twoFactorUrl = `${this.httpClient.getBaseUrl()}${V2exNativeAuthService.TWO_FACTOR_PATH}`
    const getRes = await this.requestText(twoFactorUrl, http.RequestMethod.GET, cleanCookie)
    const cookieAfterGet = V2exNativeAuthService.mergeCookieHeader(cleanCookie, getRes.setCookie)
    const challenge = V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterGet, getRes.text) ||
      V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterGet)
    return this.completeTwoFactor(challenge, code)
  }

  async completeTwoFactor(challenge: NativeTwoFactorChallenge, code: string): Promise<NativeLoginSnapshot> {
    const cleanCode = code.trim()
    if (!cleanCode) {
      throw new Error('请输入两步验证码')
    }
    const pairs = V2exNativeAuthService.twoFactorFormPairs(challenge, cleanCode)

    const actionUrl = V2exNativeAuthService.absoluteUrl(
      this.httpClient.getBaseUrl(),
      challenge.action || V2exNativeAuthService.TWO_FACTOR_PATH
    )
    const postRes = await this.requestText(
      actionUrl,
      http.RequestMethod.POST,
      challenge.cookie,
      V2exNativeAuthService.encodeFormPairs(pairs)
    )
    const cookieAfterPost = V2exNativeAuthService.mergeCookieHeader(challenge.cookie, postRes.setCookie)
    if (V2exNativeAuthService.isLocationPath(postRes.location, V2exNativeAuthService.TWO_FACTOR_PATH)) {
      throw new NativeTwoFactorRequiredError(
        V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterPost, challenge.hiddenFields),
        '两步验证失败，请检查验证码后重试'
      )
    }

    const loginError = V2exSigninParser.extractProblemMessage(postRes.text)
    if (loginError) {
      const nextChallenge = V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterPost, postRes.text)
      if (nextChallenge) {
        throw new NativeTwoFactorRequiredError(nextChallenge, `两步验证失败：${loginError}`)
      }
      throw new Error(`两步验证失败：${loginError}`)
    }

    const settingsRes = await this.requestText(`${this.httpClient.getBaseUrl()}${V2exNativeAuthService.SETTINGS_PATH}`, http.RequestMethod.GET, cookieAfterPost)
    const signedInUser = V2exSessionParser.extractUsername(settingsRes.text)
    if (!signedInUser) {
      if (V2exNativeAuthService.isLocationPath(settingsRes.location, V2exNativeAuthService.TWO_FACTOR_PATH)) {
        throw new NativeTwoFactorRequiredError(
          V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterPost, challenge.hiddenFields),
          '两步验证失败，请检查验证码后重试'
        )
      }
      const nextChallenge = V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterPost, postRes.text) ||
        V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterPost, settingsRes.text)
      if (nextChallenge) {
        throw new NativeTwoFactorRequiredError(nextChallenge, '两步验证失败，请检查验证码后重试')
      }
      throw new Error('两步验证失败，请检查验证码或改用网页登录')
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
    const receivedSetCookieLines: string[] = []
    let receivedLocation: string = ''
    httpRequest.on('headersReceive', (headers: Object) => {
      headerBag = headers
      receivedSetCookieLines.push(...V2exNativeAuthService.extractSetCookieHeader(headers))
      const location = V2exNativeAuthService.extractSingleHeader(headers, 'location')
      if (location) {
        receivedLocation = location
      }
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
      const headers = headerBag || response.header
      const finalSetCookie = V2exNativeAuthService.extractSetCookieHeader(headers)
      const setCookie = V2exNativeAuthService.uniqueCookieLines(receivedSetCookieLines.concat(finalSetCookie))
      const location = V2exNativeAuthService.extractSingleHeader(headers, 'location') || receivedLocation
      return { text, setCookie, statusCode: response.responseCode as number, location }
    } finally {
      httpRequest.destroy()
    }
  }

  private static absoluteUrl(baseUrl: string, path: string): string {
    if (path.indexOf('http://') === 0 || path.indexOf('https://') === 0) {
      return path
    }
    if (path.indexOf('/') !== 0) {
      return `${baseUrl}/${path}`
    }
    return `${baseUrl}${path}`
  }

  private static twoFactorChallengeFromHtml(cookie: string, html: string): NativeTwoFactorChallenge | null {
    const twoFactor = V2exSigninParser.extractTwoFactorForm(html)
    if (!twoFactor) {
      return null
    }
    return {
      cookie,
      action: twoFactor.action || V2exNativeAuthService.TWO_FACTOR_PATH,
      codeField: twoFactor.codeField,
      hiddenFields: twoFactor.hiddenFields
    }
  }

  private static fixedTwoFactorChallenge(cookie: string, hiddenFields: Record<string, string> = {}): NativeTwoFactorChallenge {
    return {
      cookie,
      action: V2exNativeAuthService.TWO_FACTOR_PATH,
      codeField: 'code',
      hiddenFields
    }
  }

  private static twoFactorFormPairs(challenge: NativeTwoFactorChallenge, cleanCode: string): FormPair[] {
    const pairs: FormPair[] = []
    const hiddenFields = challenge.hiddenFields
    const keys = Object.keys(hiddenFields)
    for (const key of keys) {
      if (!key || key === challenge.codeField) {
        continue
      }
      pairs.push({ key, value: hiddenFields[key] })
    }
    pairs.push({ key: challenge.codeField || 'code', value: cleanCode })
    return pairs
  }

  private static isLocationPath(location: string, path: string): boolean {
    if (!location || !path) {
      return false
    }
    const normalized = V2exNativeAuthService.locationPath(location)
    return normalized === path || normalized.indexOf(`${path}?`) === 0
  }

  private static locationPath(location: string): string {
    const trimmed = location.trim()
    if (!trimmed) {
      return ''
    }
    const schemeIdx = trimmed.indexOf('://')
    if (schemeIdx >= 0) {
      const pathStart = trimmed.indexOf('/', schemeIdx + 3)
      return pathStart >= 0 ? trimmed.slice(pathStart) : '/'
    }
    if (trimmed.indexOf('/') !== 0) {
      return `/${trimmed}`
    }
    return trimmed
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
    } catch (e) {
      return ''
    }
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

  private static uniqueCookieLines(lines: string[]): string[] {
    const seen: Record<string, boolean> = {}
    const result: string[] = []
    for (const line of lines) {
      const clean = (line || '').trim()
      if (!clean || seen[clean]) {
        continue
      }
      seen[clean] = true
      result.push(clean)
    }
    return result
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
