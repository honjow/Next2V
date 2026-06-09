import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import {
  ApiService,
  ApiConstants,
  AppStrings,
  AuthSessionSettings,
  AccountSessionCoordinator,
  AutoDailyCheckinService,
  connectNavStack,
  connectWebLoginAction,
  CookieJarSettings,
  DiagnosticLogger,
  HttpClient,
  V2exWebView,
  V2exWebViewScaffold,
  V2exSessionParser,
  WebLoginActionState,
  translateApiError
} from 'shared'

interface PageEndEvent {
  url: string
}

interface ValidatedCookie {
  cookie: string
  username: string
}

@ComponentV2
export struct V2exWebLoginPage {
  // `ns` is the app-wide NavPathStack from NavStackHolder (same instance Index's HdsNavigation binds),
  // read directly instead of the former V1 @Consume('ns').
  private stack: NavPathStack = connectNavStack().stack

  private controller: webview.WebviewController = new webview.WebviewController()
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()

  @Local private errorMessage: string = ''
  @Local private pageMessage: string = AppStrings.text($r('app.string.web_login_opening'), 'Opening web login...')
  @Local private isSaving: boolean = false
  @Local private isSaved: boolean = false
  @Local private lastUrl: string = ''
  private autoSaveTimerId: number = 0
  private autoSaveAttempt: number = 0
  private isAutoSaving: boolean = false
  private isPageActive: boolean = false
  private saveRequestId: number = 0
  private loginStartCookie: string = ''
  // V2 mirror of WEB_LOGIN_ACTION (was @StorageLink+@Watch); reacts via @Monitor below.
  private webLoginActionState: WebLoginActionState = connectWebLoginAction()

  private get baseUrl(): string {
    return this.http.getBaseUrl()
  }

  private currentSigninUrl(): string {
    const cleanBase = (this.baseUrl || ApiConstants.BASE_URL_COM).trim().replace(/\/+$/, '')
    const hasProtocol = cleanBase.indexOf('http://') === 0 || cleanBase.indexOf('https://') === 0
    let normalizedBase = ApiConstants.BASE_URL_COM
    if (hasProtocol) {
      normalizedBase = cleanBase
    }
    return `${normalizedBase}/signin`
  }

  aboutToAppear(): void {
    this.isPageActive = true
  }

  aboutToDisappear(): void {
    this.isPageActive = false
    this.saveRequestId++
    this.cancelAutoSave()
    this.isSaving = false
    this.isAutoSaving = false
  }

  build() {
    V2exWebViewScaffold({
      isStatusVisible: this.isSaving || !!this.errorMessage || !!this.pageMessage,
      isStatusError: !!this.errorMessage,
      statusText: this.statusText(),
      statusMaxLines: 1
    }) {
      V2exWebView({
        controller: this.controller,
        onControllerAttached: () => {
          this.loadSigninPage()
        },
        onPageBegin: (event?: PageEndEvent) => {
          this.pageMessage = event?.url ? AppStrings.format(AppStrings.text($r('app.string.web_login_loading_url'), 'Loading {0}'), [event.url]) : AppStrings.text($r('app.string.web_login_loading_page'), 'Loading web login...')
          if (event && event.url) {
            this.lastUrl = event.url
          }
          DiagnosticLogger.info('webview', 'web_login_page_begin', {
            url: event && event.url ? event.url : this.currentSigninUrl()
          })
          this.scheduleAutoSave()
        },
        onPageEnd: (event?: PageEndEvent) => {
          this.pageMessage = ''
          if (event && event.url) {
            this.lastUrl = event.url
          }
          DiagnosticLogger.info('webview', 'web_login_page_end', {
            url: event && event.url ? event.url : this.lastUrl
          })
          this.scheduleAutoSave()
        },
        onLoadFinished: (event?: PageEndEvent) => {
          if (event && event.url) {
            this.lastUrl = event.url
          }
          this.scheduleAutoSave()
        },
        onErrorReceive: (event) => {
          if (event?.request?.isMainFrame()) {
            this.pageMessage = event.error.getErrorInfo() || AppStrings.text($r('app.string.web_login_load_failed'), 'Web login failed to load')
            DiagnosticLogger.warn('webview', 'web_login_load_error', {
              url: this.lastUrl || this.currentSigninUrl(),
              isMainFrame: true,
              errorInfo: this.pageMessage
            })
          }
        }
      })
    }
  }

  private statusText(): string {
    if (this.isSaving) {
      return AppStrings.text($r('app.string.web_login_saving'), 'Saving login state...')
    }
    if (this.errorMessage) {
      return this.errorMessage
    }
    return this.pageMessage
  }

  @Monitor('webLoginActionState.command')
  onWebLoginAction(): void {
    const action = this.webLoginActionState.command.split(':').pop() || ''
    if (action === 'save') {
      this.saveLogin(false)
    } else if (action === 'reload') {
      this.reloadPage()
    }
  }

  private reloadPage(): void {
    if (!this.lastUrl) {
      this.loadSigninPage()
      return
    }
    try {
      this.controller.refresh()
    } catch (error) {
      DiagnosticLogger.exception('webview', 'web_login_reload_exception', error as Error, { url: this.lastUrl })
      this.errorMessage = translateApiError(error)
    }
  }

  private loadSigninPage(): void {
    const url = this.currentSigninUrl()
    this.pageMessage = AppStrings.format(AppStrings.text($r('app.string.web_login_opening_url'), 'Opening {0}'), [url])
    this.loginStartCookie = CookieJarSettings.getCurrentCookie()
    CookieJarSettings.clearWebCookiesForBaseUrl(this.baseUrl)
      .then(() => {
        if (!this.isPageActive) {
          return
        }
        this.controller.loadUrl(url)
      })
      .catch((error: Error) => {
        DiagnosticLogger.exception('webview', 'web_login_load_signin_exception', error, { url: url })
        this.errorMessage = `${translateApiError(error)}: ${url}`
      })
  }

  private scheduleAutoSave(delay: number = 900): void {
    if (!this.isPageActive || this.isSaving || this.isAutoSaving || this.isSaved) {
      return
    }
    this.cancelAutoSave()
    this.autoSaveTimerId = setTimeout(() => {
      this.autoSaveTimerId = 0
      if (!this.isPageActive || this.isSaved) {
        return
      }
      this.autoSaveAttempt += 1
      this.saveLogin(true, this.autoSaveAttempt)
    }, delay)
  }

  private cancelAutoSave(): void {
    if (this.autoSaveTimerId) {
      clearTimeout(this.autoSaveTimerId)
      this.autoSaveTimerId = 0
    }
  }

  private saveLogin(silent: boolean, autoAttempt: number = 0): void {
    if (!this.isPageActive || this.isSaved || this.isSaving || this.isAutoSaving) {
      return
    }
    const requestId = ++this.saveRequestId
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.baseUrl
    if (silent) {
      this.isAutoSaving = true
    } else {
      this.isSaving = true
    }
    if (!silent) {
      this.errorMessage = ''
    }
    this.validateWebLoginCookie(silent)
      .then(async (validated: ValidatedCookie) => {
        if (!this.isCurrentSaveRequest(requestId)) {
          return
        }
        const username = validated.username
        let avatar = ''
        try {
          const profile = await this.api.getMember(username)
          avatar = profile.avatar_normal || profile.avatar_large || profile.avatar_mini || ''
        } catch (error) {
          DiagnosticLogger.exception('auth', 'web_login_avatar_fetch_exception', error as Error, { username: username })
          avatar = ''
        }
        if (!this.isCurrentSaveRequest(requestId)) {
          await this.clearPersistedLogin(context)
          return
        }
        await CookieJarSettings.saveForBaseUrl(context, baseUrl, validated.cookie)
        if (!this.isCurrentSaveRequest(requestId)) {
          await this.clearPersistedLogin(context)
          return
        }
        await AuthSessionSettings.save(context, { loginMode: 'cookie', username, avatar, validatedAt: Date.now() })
        await AccountSessionCoordinator.registerCurrentSession(context, username, avatar, 'cookie')
        AutoDailyCheckinService.tryCheckin(context, validated.cookie, 'web-login').catch((error: Error) => {
          DiagnosticLogger.exception('auto_daily_checkin', 'web_login_auto_checkin_exception', error)
          console.info('auto daily check-in web-login trigger failed: ' + error.message)
        })
        if (!this.isCurrentSaveRequest(requestId)) {
          await this.clearPersistedLogin(context)
        }
      })
      .then(() => {
        if (!this.isCurrentSaveRequest(requestId)) {
          return
        }
        this.isSaved = true
        this.cancelAutoSave()
        promptAction.openToast({ message: $r('app.string.login_saved') }).catch((error: Error) => {
          DiagnosticLogger.exception('ui_lifecycle', 'web_login_saved_toast_exception', error)
          console.error('openToast failed: ' + error.message)
        })
        this.stack.pop()
      })
      .catch((error: Error) => {
        DiagnosticLogger.exception('auth', 'web_login_save_exception', error, {
          silent: silent,
          autoAttempt: autoAttempt,
          lastUrl: this.lastUrl
        })
        if (!this.isPageActive || requestId !== this.saveRequestId) {
          return
        }
        if (!silent) {
          this.errorMessage = translateApiError(error)
        } else if (!this.isSaved && autoAttempt > 0 && autoAttempt < 12) {
          setTimeout(() => {
            if (this.isPageActive && !this.isSaved && requestId === this.saveRequestId) {
              this.saveLogin(true, autoAttempt + 1)
            }
          }, 1200)
        }
      })
      .finally(() => {
        if (!this.isPageActive || requestId !== this.saveRequestId) {
          return
        }
        if (silent) {
          this.isAutoSaving = false
        } else {
          this.isSaving = false
        }
      })
  }

  private async validateWebLoginCookie(silent: boolean): Promise<ValidatedCookie> {
    const cookie = await this.fetchWebLoginCookie()
    const cleanCookie = cookie?.trim() || ''
    if (!cleanCookie) {
      throw new Error(AppStrings.text($r('app.string.login_cookie_missing'), 'Login cookie was not obtained. Please confirm login is complete.'))
    }
    if (silent && !this.hasLikelyAuthCookie(cleanCookie)) {
      throw new Error(AppStrings.text($r('app.string.web_login_not_complete'), 'Web login not yet complete'))
    }
    if (silent && this.sameCookieHeader(cleanCookie, this.loginStartCookie)) {
      throw new Error(AppStrings.text($r('app.string.web_login_not_complete'), 'Web login not yet complete'))
    }
    const html = await this.http.getTextWithHeaders('/settings', { 'Cookie': cleanCookie })
    const username = V2exSessionParser.extractUsername(html)
    if (!username) {
      throw new Error(AppStrings.text($r('app.string.login_cookie_invalid'), 'Cookie login state is invalid. Please confirm login is complete.'))
    }
    return { cookie: cleanCookie, username }
  }

  private isCurrentSaveRequest(requestId: number): boolean {
    return this.isPageActive && requestId === this.saveRequestId
  }

  private async clearPersistedLogin(context: common.UIAbilityContext): Promise<void> {
    const restored = await AccountSessionCoordinator.restoreActiveAccount(context).catch((error: Error) => {
      DiagnosticLogger.exception('auth', 'web_login_restore_active_after_failure_exception', error)
      return null
    })
    if (restored) {
      console.info('V2exWebLoginPage: restored previous active account after web login persist failure')
      return
    }
    await Promise.all([
      CookieJarSettings.clearForBaseUrl(context, this.baseUrl).catch((clearError: Error) => {
        DiagnosticLogger.exception('auth', 'web_login_clear_cookie_after_failure_exception', clearError)
        console.error('clear cookie after web login persist failure: ' + clearError.message)
      }),
      AuthSessionSettings.clear(context).catch((clearError: Error) => {
        DiagnosticLogger.exception('auth', 'web_login_clear_auth_after_failure_exception', clearError)
        console.error('clear auth session after web login persist failure: ' + clearError.message)
      })
    ])
  }

  private async fetchWebLoginCookie(): Promise<string> {
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (error) {
      DiagnosticLogger.exception('webview', 'web_login_save_cookie_sync_exception', error as Error)
      try {
        await webview.WebCookieManager.saveCookieAsync()
      } catch (e) {
        DiagnosticLogger.exception('webview', 'web_login_save_cookie_async_exception', e as Error)
      }
    }

    const urls: string[] = []
    this.pushUniqueUrl(urls, this.baseUrl)
    this.pushUniqueUrl(urls, this.currentSigninUrl())
    this.pushUniqueUrl(urls, this.lastUrl)

    const merged: Map<string, string> = new Map()
    for (const url of urls) {
      try {
        const cookie = await webview.WebCookieManager.fetchCookie(url)
        this.mergeCookieHeader(merged, cookie || '')
      } catch (error) {
        DiagnosticLogger.exception('webview', 'web_login_fetch_cookie_exception', error as Error, { url: url })
      }
    }
    const parts: string[] = []
    merged.forEach((value: string, name: string) => {
      parts.push(`${name}=${value}`)
    })
    return parts.join('; ')
  }

  private pushUniqueUrl(urls: string[], url: string): void {
    const cleanUrl = (url || '').trim()
    if (!cleanUrl || cleanUrl.indexOf('http') !== 0 || urls.indexOf(cleanUrl) >= 0) {
      return
    }
    urls.push(cleanUrl)
  }

  private mergeCookieHeader(target: Map<string, string>, cookieHeader: string): void {
    const parts = cookieHeader.split(';').map((part: string) => part.trim()).filter((part: string) => part.length > 0)
    for (const part of parts) {
      const idx = part.indexOf('=')
      if (idx <= 0) {
        continue
      }
      const name = part.slice(0, idx).trim()
      const value = part.slice(idx + 1).trim()
      if (!name || !value) {
        continue
      }
      target.set(name, value)
    }
  }

  private hasLikelyAuthCookie(cookieHeader: string): boolean {
    const names: string[] = []
    const parts = cookieHeader.split(';').map((part: string) => part.trim()).filter((part: string) => part.length > 0)
    for (const part of parts) {
      const idx = part.indexOf('=')
      if (idx <= 0) {
        continue
      }
      names.push(part.slice(0, idx).trim().toUpperCase())
    }
    return names.indexOf('A2') >= 0 ||
      names.indexOf('PB3_SESSION') >= 0 ||
      names.indexOf('PB3_AUTH') >= 0 ||
      names.indexOf('V2EX_SESSION') >= 0
  }

  private sameCookieHeader(a: string, b: string): boolean {
    return this.normalizedCookieHeader(a) === this.normalizedCookieHeader(b)
  }

  private normalizedCookieHeader(cookieHeader: string): string {
    const pairs: string[] = []
    const parts = cookieHeader.split(';').map((part: string) => part.trim()).filter((part: string) => part.length > 0)
    for (const part of parts) {
      const idx = part.indexOf('=')
      if (idx <= 0) {
        continue
      }
      const name = part.slice(0, idx).trim()
      const value = part.slice(idx + 1).trim()
      if (!name || !value) {
        continue
      }
      pairs.push(`${name}=${value}`)
    }
    return pairs.sort().join(';')
  }
}
