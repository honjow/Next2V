import { http } from '@kit.NetworkKit'
import util from '@ohos.util'
import { ApiConstants } from '../constants/ApiConstants'
import { V2exCookieHeaders } from './V2exCookieHeaders'
import { TwoFactorTrace } from '../diagnostics/TwoFactorTrace'
import { HttpStatusError } from './HttpRetryPolicy'
import { NetworkProxySettings } from '../settings/NetworkProxySettings'
import { HttpClient } from './HttpClient'
import { NetworkProxyRequest } from './NetworkProxyRequest'
import { V2exSigninParser } from '../parser/V2exSigninParser'
import { V2exSessionParser } from '../parser/V2exSessionParser'
import { ApiErrors } from './ApiError'
import { V2exDomainUtils } from '../utils/V2exDomainUtils'

const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 15000
const DEBUG_SKIP_LOGIN_2FA: boolean = false
const BROWSER_USER_AGENT: string = 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36'

interface TextWithSetCookie {
  text: string
  setCookie: string[]
  statusCode: number
  location: string
}

interface FormPair {
  key: string
  value: string
}

interface AuthTransportError extends Error {
  code?: number
}

export interface NativeLoginSnapshot {
  cookie: string
  username: string
}

export interface NativeLoginChallenge {
  baseUrl: string
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

  constructor(challenge: NativeTwoFactorChallenge, message: string = 'Two-factor authentication required') {
    super(message)
    this.name = 'NativeTwoFactorRequiredError'
    this.challenge = challenge
  }
}

export class V2exNativeAuthService {
  private httpClient: HttpClient = HttpClient.getInstance()
  private retryCookie: string = ''

  getTwoFactorRetryCookie(): string { return this.retryCookie }
  private static readonly TWO_FACTOR_PATH: string = '/2fa'
  private static readonly SETTINGS_PATH: string = '/settings'
  private static readonly TWO_FACTOR_VERIFY_PATH: string = '/balance'

  async prepareLogin(): Promise<NativeLoginChallenge> {
    const baseUrl = V2exNativeAuthService.authBaseUrlFor(this.httpClient.getBaseUrl())
    const signinUrl = `${baseUrl}/signin`

    const getRes = await this.requestText(signinUrl, http.RequestMethod.GET, '')
    if (V2exNativeAuthService.isLocationPath(getRes.location, '/signin/cooldown')) {
      throw ApiErrors.loginRestricted('')
    }
    const restriction = V2exSigninParser.extractLoginRestriction(getRes.text)
    if (restriction) {
      throw ApiErrors.loginRestricted(restriction.restrictedIp)
    }

    const form = V2exSigninParser.extractForm(getRes.text)
    if (!form) {
      throw ApiErrors.parseLoginPageFailed()
    }

    return {
      baseUrl: baseUrl,
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
      throw ApiErrors.loginCaptchaRequired()
    }
    return this.loginWithChallenge(challenge, username, password, '')
  }

  async loginWithChallenge(
    challenge: NativeLoginChallenge,
    username: string,
    password: string,
    captchaCode: string
  ): Promise<NativeLoginSnapshot> {
    const baseUrl = challenge.baseUrl || this.httpClient.getBaseUrl()
    const signinUrl = `${baseUrl}/signin`

    const pairs: FormPair[] = [
      { key: challenge.usernameField, value: username },
      { key: challenge.passwordField, value: password }
    ]
    if (challenge.captchaField) {
      if (!captchaCode.trim()) {
        throw ApiErrors.captchaRequired()
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

    const postRestriction = V2exSigninParser.extractLoginRestriction(postRes.text)
    if (postRestriction) {
      throw ApiErrors.loginRestricted(postRestriction.restrictedIp)
    }

    const loginError = V2exSigninParser.extractProblemMessage(postRes.text)
    if (V2exNativeAuthService.isSigninResponse(postRes) || loginError) {
      throw ApiErrors.loginFailedDetail(V2exNativeAuthService.loginInputErrorMessage(challenge, loginError))
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
        throw ApiErrors.loginRedirectUnsupported(postRes.location)
      }
      const settingsRestriction = V2exSigninParser.extractLoginRestriction(settingsRes.text)
      if (settingsRestriction) {
        throw ApiErrors.loginRestricted(settingsRestriction.restrictedIp)
      }

      const settingsProblem = V2exSigninParser.extractProblemMessage(settingsRes.text)
      if (V2exNativeAuthService.isSigninResponse(settingsRes) || settingsProblem) {
        throw ApiErrors.loginFailedDetail(V2exNativeAuthService.loginInputErrorMessage(challenge, settingsProblem))
      }
      throw ApiErrors.loginStateUnconfirmed()
    }

    return { cookie: cookieAfterPost, username: signedInUser }
  }

  async completeTwoFactorWithCookie(cookie: string, code: string, trace: TwoFactorTrace = new TwoFactorTrace()): Promise<NativeLoginSnapshot> {
    const cleanCookie = (cookie || '').trim()
    if (!cleanCookie) {
      throw ApiErrors.loginSessionMissing()
    }
    const cleanCode = V2exNativeAuthService.normalizeTwoFactorCode(code)
    if (cleanCode.length !== 6) { throw ApiErrors.twoFactorCodeRequired() }
    const authBaseUrl = V2exNativeAuthService.authBaseUrlFor(this.httpClient.getBaseUrl())
    this.retryCookie = cleanCookie
    trace.stage = 'fetch_form'
    const twoFactorUrl = `${authBaseUrl}${V2exNativeAuthService.TWO_FACTOR_PATH}`
    const getRes = await this.requestText(twoFactorUrl, http.RequestMethod.GET, cleanCookie, '', trace)
    const cookieAfterGet = V2exNativeAuthService.mergeCookieHeader(cleanCookie, getRes.setCookie)
    const challenge = V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterGet, getRes.text)
    if (!challenge) {
      trace.record('challenge_form_absent')
      // A previous POST may have succeeded before verification/persistence failed.
      // Recover only through the same gated-page and identity checks; never send a blind POST.
      return this.verifyTwoFactorSession(cookieAfterGet, trace)
    }
    return this.completeTwoFactor(challenge, cleanCode, trace)
  }

  async completeTwoFactor(challenge: NativeTwoFactorChallenge, code: string, trace: TwoFactorTrace = new TwoFactorTrace()): Promise<NativeLoginSnapshot> {
    const cleanCode = V2exNativeAuthService.normalizeTwoFactorCode(code)
    if (!cleanCode || cleanCode.length !== 6) {
      throw ApiErrors.twoFactorCodeRequired()
    }
    this.retryCookie = challenge.cookie
    trace.stage = 'submit'
    trace.record('form_ready', { challengeFieldPresent: !!challenge.hiddenFields['once'], sessionPresent: !!challenge.cookie })
    const pairs = V2exNativeAuthService.twoFactorFormPairs(challenge, cleanCode)

    const authBaseUrl = V2exNativeAuthService.authBaseUrlFor(this.httpClient.getBaseUrl())
    const actionUrl = V2exNativeAuthService.authActionUrl(
      authBaseUrl,
      challenge.action || V2exNativeAuthService.TWO_FACTOR_PATH
    )
    const postRes = await this.requestText(
      actionUrl,
      http.RequestMethod.POST,
      challenge.cookie,
      V2exNativeAuthService.encodeFormPairs(pairs),
      trace
    )
    const cookieAfterPost = V2exNativeAuthService.mergeCookieHeader(challenge.cookie, postRes.setCookie)
    const postChallenge = V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterPost, postRes.text)
    const loginError = V2exSigninParser.extractProblemMessage(postRes.text)
    if (V2exNativeAuthService.isLocationPath(postRes.location, V2exNativeAuthService.TWO_FACTOR_PATH)) {
      throw new NativeTwoFactorRequiredError(
        V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterPost, challenge.hiddenFields),
        'Two-factor failed, please check the code'
      )
    }

    if (loginError) {
      if (postChallenge) {
        throw new NativeTwoFactorRequiredError(postChallenge, `Two-factor failed: ${loginError}`)
      }
      throw ApiErrors.twoFactorFailedDetail(loginError)
    }
    if (postChallenge) {
      throw new NativeTwoFactorRequiredError(postChallenge)
    }
    if (V2exNativeAuthService.isSigninResponse(postRes)) {
      throw ApiErrors.loginSessionMissing()
    }

    return this.verifyTwoFactorSession(cookieAfterPost, trace, challenge.hiddenFields)
  }

  private async verifyTwoFactorSession(
    cookie: string,
    trace: TwoFactorTrace,
    hiddenFields: Record<string, string> = {}
  ): Promise<NativeLoginSnapshot> {
    const authBaseUrl = V2exNativeAuthService.authBaseUrlFor(this.httpClient.getBaseUrl())
    trace.stage = 'verify_gate'
    const verifyRes = await this.requestText(`${authBaseUrl}${V2exNativeAuthService.TWO_FACTOR_VERIFY_PATH}`, http.RequestMethod.GET, cookie, '', trace)
    const cookieAfterVerify = V2exNativeAuthService.mergeCookieHeader(cookie, verifyRes.setCookie)
    const verifyChallenge = V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterVerify, verifyRes.text)
    if (V2exNativeAuthService.isLocationPath(verifyRes.location, V2exNativeAuthService.TWO_FACTOR_PATH) || verifyChallenge) {
      throw new NativeTwoFactorRequiredError(
        verifyChallenge || V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterVerify, hiddenFields),
        'Two-factor failed, please check the code'
      )
    }
    const gatedUser = V2exSessionParser.extractUsername(verifyRes.text)
    if (verifyRes.statusCode !== 200 || !gatedUser || V2exNativeAuthService.isSigninResponse(verifyRes)) {
      trace.record('gate_unconfirmed', {}, true)
      throw ApiErrors.twoFactorFailed()
    }

    trace.stage = 'verify_identity'
    const settingsRes = await this.requestText(`${authBaseUrl}${V2exNativeAuthService.SETTINGS_PATH}`, http.RequestMethod.GET, cookieAfterVerify, '', trace)
    const cookieAfterSettings = V2exNativeAuthService.mergeCookieHeader(cookieAfterVerify, settingsRes.setCookie)
    const signedInUser = V2exSessionParser.extractUsername(settingsRes.text)
    const settingsChallenge = V2exNativeAuthService.twoFactorChallengeFromHtml(cookieAfterSettings, settingsRes.text)
    if (settingsChallenge || V2exNativeAuthService.isLocationPath(settingsRes.location, V2exNativeAuthService.TWO_FACTOR_PATH)) {
      throw new NativeTwoFactorRequiredError(settingsChallenge || V2exNativeAuthService.fixedTwoFactorChallenge(cookieAfterSettings))
    }
    if (settingsRes.statusCode !== 200 || V2exNativeAuthService.isSigninResponse(settingsRes)) {
      throw ApiErrors.twoFactorFailed()
    }
    if (!signedInUser || signedInUser !== gatedUser) {
      trace.record('identity_unconfirmed', {}, true)
      throw ApiErrors.twoFactorFailed()
    }
    trace.record('remote_verified', { identityPresent: true })
    return { cookie: cookieAfterSettings, username: signedInUser }
  }

  async fetchCaptchaDataUrl(challenge: NativeLoginChallenge): Promise<string> {
    if (!challenge.captchaUrl) {
      return ''
    }
    const baseUrl = challenge.baseUrl || this.httpClient.getBaseUrl()
    const captchaUrl = V2exNativeAuthService.absoluteUrl(baseUrl, challenge.captchaUrl)
    try {
      const response = await NetworkProxyRequest.request(captchaUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'image/avif,image/webp,image/png,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Encoding': 'gzip',
          'Cookie': challenge.cookie,
          'Referer': `${baseUrl}/signin`,
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
    } catch (error) {
      throw error as Error
    }
  }

  private async requestText(
    url: string,
    method: http.RequestMethod,
    cookieHeader: string,
    extraData: string = '',
    trace?: TwoFactorTrace
  ): Promise<TextWithSetCookie> {
    let headerBag: Object | null = null
    const startedAt = Date.now()
    trace?.record('request_started', {
      method: method === http.RequestMethod.POST ? 'POST' : 'GET', route: TwoFactorTrace.route(url),
      host: V2exDomainUtils.hostForBaseUrl(url).replace(/^.*@/, ''), transportMode: NetworkProxySettings.current().mode,
      protocolVersion: 'once-code-v1',
    })
    const receivedSetCookieLines: string[] = []
    let receivedLocation: string = ''

    try {
      const reqHeaders: Record<string, string> = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip',
        'Content-Type': method === http.RequestMethod.POST ? 'application/x-www-form-urlencoded' : 'text/html; charset=utf-8',
        'User-Agent': BROWSER_USER_AGENT
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
      const response = await NetworkProxyRequest.request(url, {
        method: method,
        header: reqHeaders,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
        extraData: method === http.RequestMethod.POST ? extraData : '',
        onHeadersReceive: (headers: Object) => {
          headerBag = headers
          receivedSetCookieLines.push(...V2exCookieHeaders.extract(headers))
          const location = V2exNativeAuthService.extractSingleHeader(headers, 'location')
          if (location) { receivedLocation = location }
        },
      })

      const text = (response.result as string) || ''
      const headers = headerBag || response.header
      const setCookie = receivedSetCookieLines.concat(V2exCookieHeaders.extract(response.header))
      const location = V2exNativeAuthService.extractSingleHeader(headers, 'location') || receivedLocation
      if (trace) {
        this.retryCookie = V2exCookieHeaders.merge(cookieHeader, setCookie)
        const form = V2exSigninParser.extractTwoFactorForm(text)
        const serverDate = Date.parse(V2exNativeAuthService.extractSingleHeader(response.header, 'date'))
        trace.record('response_received', {
          statusCode: response.responseCode, elapsedMs: Date.now() - startedAt,
          route: TwoFactorTrace.route(url), redirectRoute: TwoFactorTrace.route(location),
          effectiveRoute: TwoFactorTrace.route(response.effectiveUrl),
          responseUpdates: setCookie.length, sessionChanged: this.retryCookie !== cookieHeader,
          sessionPresent: !!this.retryCookie, formPresent: !!form, challengeFieldPresent: !!form?.hiddenFields['once'],
          identityPresent: !!V2exSessionParser.extractUsername(text),
          signinPresent: V2exNativeAuthService.isLocationPath(location, '/signin') || V2exSigninParser.hasSigninForm(text),
          problemKind: TwoFactorTrace.problemKind(V2exSigninParser.extractProblemMessage(text)),
          responseLength: text.length, serverTimePresent: Number.isFinite(serverDate),
          serverClockDeltaMs: Number.isFinite(serverDate) ? serverDate - Date.now() : 0,
        })
        if (response.responseCode < 200 || response.responseCode >= 400) {
          throw new HttpStatusError(response.responseCode, url)
        }
      }
      return { text, setCookie, statusCode: response.responseCode as number, location }
    } catch (error) {
      const transportError = error as AuthTransportError
      trace?.record('request_failed', {
        elapsedMs: Date.now() - startedAt, httpFailure: error instanceof HttpStatusError,
        transportErrorCode: typeof transportError.code === 'number' ? transportError.code : 0,
      }, true)
      throw error as Error
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

  private static authBaseUrlFor(baseUrl: string): string {
    const cleanBaseUrl = (baseUrl || ApiConstants.BASE_URL_COM).trim()
    const host = V2exDomainUtils.hostForBaseUrl(cleanBaseUrl)
    if (V2exDomainUtils.isV2exOwnedHost(host)) {
      return ApiConstants.BASE_URL_COM
    }
    return cleanBaseUrl.endsWith('/') ? cleanBaseUrl.slice(0, cleanBaseUrl.length - 1) : cleanBaseUrl
  }

  private static authActionUrl(baseUrl: string, action: string): string {
    const cleanAction = (action || V2exNativeAuthService.TWO_FACTOR_PATH).trim()
    if (cleanAction.indexOf('http://') === 0 || cleanAction.indexOf('https://') === 0) {
      const host = V2exDomainUtils.hostForBaseUrl(cleanAction)
      if (!V2exDomainUtils.isV2exOwnedHost(host)) {
        return `${baseUrl}${V2exNativeAuthService.TWO_FACTOR_PATH}`
      }
      return `${baseUrl}${V2exNativeAuthService.locationPath(cleanAction)}`
    }
    return V2exNativeAuthService.absoluteUrl(baseUrl, cleanAction)
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
    // Submit the page's anti-CSRF field, but never replay unrelated submit/button inputs.
    const pairs: FormPair[] = [{ key: challenge.codeField || 'code', value: cleanCode }]
    const once = challenge.hiddenFields['once']
    if (once) { pairs.push({ key: 'once', value: once }) }
    return pairs
  }

  private static normalizeTwoFactorCode(value: string): string {
    const raw = value || ''
    let result = ''
    for (let i = 0; i < raw.length; i += 1) {
      const ch = raw.charAt(i)
      const codeUnit = raw.charCodeAt(i)
      if (codeUnit >= 48 && codeUnit <= 57) {
        result += ch
      } else if (codeUnit >= 65296 && codeUnit <= 65305) {
        result += String.fromCharCode(codeUnit - 65248)
      }
    }
    return result
  }

  private static isLocationPath(location: string, path: string): boolean {
    if (!location || !path) {
      return false
    }
    const normalized = V2exNativeAuthService.locationPath(location)
    return normalized === path || normalized.indexOf(`${path}?`) === 0
  }

  private static isSigninResponse(res: TextWithSetCookie): boolean {
    return V2exNativeAuthService.isLocationPath(res.location, '/signin') || V2exSigninParser.hasSigninForm(res.text)
  }

  private static loginInputErrorMessage(challenge: NativeLoginChallenge, problemMessage: string): string {
    const problem = (problemMessage || '').trim()
    if (problem) {
      if (problem.indexOf('验证码') >= 0 || problem.toLowerCase().indexOf('captcha') >= 0) {
        return 'The captcha is incorrect. Please try again.'
      }
      if (problem.indexOf('密码') >= 0 || problem.toLowerCase().indexOf('password') >= 0 ||
        problem.toLowerCase().indexOf('username') >= 0 || problem.indexOf('用户名') >= 0) {
        return 'The username or password is incorrect. Please check and try again.'
      }
      return problem
    }
    return challenge.captchaField ? 'The username, password, or captcha is incorrect. Please check and try again.' : 'The username or password is incorrect. Please check and try again.'
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

  private static mergeCookieHeader(existingCookieHeader: string, setCookieLines: string[]): string {
    return V2exCookieHeaders.merge(existingCookieHeader, setCookieLines)
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
