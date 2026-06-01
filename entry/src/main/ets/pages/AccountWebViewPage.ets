import { webview } from '@kit.ArkWeb'
import {
  AppStrings,
  CookieJarSettings,
  DiagnosticLogger,
  HttpClient,
  V2exWebView,
  V2exWebViewScaffold,
  V2exUrlRouter,
  connectNavStack,
  connectAccountWebViewAction,
  connectAccountWebViewUrl,
  publishAccountWebViewUrl,
  AccountWebViewActionState,
} from 'shared'

interface PageEndEvent {
  url: string
}

@ComponentV2
export struct AccountWebViewPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private ns: NavPathStack = connectNavStack().stack
  // The target URL is an input the opener (AccountDetailPage) publishes into the AccountWebViewUrlState
  // mirror before navigating; it is logic-only (never read in build()), so it is read imperatively on
  // appear from the mirror and the normalised value is re-published through publishAccountWebViewUrl.
  private targetUrl: string = ''
  // V2 mirror of the one-directional ACCOUNT_WEB_VIEW_ACTION reload bus (Index dual-writes).
  // Reacted to via @Monitor below; never read in build().
  @Local private actionState: AccountWebViewActionState = connectAccountWebViewAction()

  private controller: webview.WebviewController = new webview.WebviewController()
  private http: HttpClient = HttpClient.getInstance()

  @Local private isLoading: boolean = true
  @Local private errorMessage: string = ''
  @Local private pageMessage: string = AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…')
  @Local private hasInjectedCookie: boolean = false
  @Local private hasLoadRequested: boolean = false

  aboutToAppear(): void {
    this.targetUrl = connectAccountWebViewUrl().url
    if (!this.targetUrl) {
      this.errorMessage = AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'No page URL provided')
      this.pageMessage = ''
      this.isLoading = false
    }
  }

  build() {
    V2exWebViewScaffold({
      isStatusVisible: this.isLoading || !!this.errorMessage || !!this.pageMessage,
      isStatusError: !!this.errorMessage,
      statusText: this.statusText(),
      statusMaxLines: 2
    }) {
      V2exWebView({
        controller: this.controller,
        onControllerAttached: () => {
          this.loadTargetUrl()
        },
        onPageBegin: (event?: PageEndEvent) => {
          this.isLoading = true
          this.errorMessage = ''
          this.pageMessage = AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…')
          DiagnosticLogger.info('webview', 'account_webview_page_begin', {
            url: event && event.url ? event.url : this.targetUrl,
            hasCookie: this.hasInjectedCookie
          })
        },
        onPageEnd: (event?: PageEndEvent) => {
          this.isLoading = false
          this.pageMessage = ''
          DiagnosticLogger.info('webview', 'account_webview_page_end', {
            url: event && event.url ? event.url : this.targetUrl,
            hasCookie: this.hasInjectedCookie
          })
        },
        onErrorReceive: (event) => {
          if (event?.request?.isMainFrame()) {
            this.isLoading = false
            this.pageMessage = ''
            this.errorMessage = event.error.getErrorInfo() ||
              AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to load page')
            DiagnosticLogger.warn('webview', 'account_webview_load_error', {
              url: this.targetUrl,
              isMainFrame: true,
              errorInfo: this.errorMessage,
              hasCookie: this.hasInjectedCookie
            })
          }
        }
      })
    }
  }

  private statusText(): string {
    if (this.errorMessage) {
      return this.errorMessage
    }
    return this.pageMessage
  }

  @Monitor('actionState.command')
  onAccountWebViewAction(): void {
    const action = (this.actionState.command || '').split(':').pop() || ''
    if (action === 'reload') {
      this.reloadPage()
    }
  }

  private reloadPage(): void {
    this.errorMessage = ''
    this.pageMessage = AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…')
    this.isLoading = true
    if (!this.hasInjectedCookie) {
      this.hasLoadRequested = false
      this.loadTargetUrl()
      return
    }
    try {
      this.controller.refresh()
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('webview', 'account_webview_reload_exception', e, { url: this.targetUrl })
      this.isLoading = false
      this.pageMessage = ''
      this.errorMessage = e.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to refresh page')
    }
  }

  private loadTargetUrl(): void {
    if (this.hasLoadRequested) {
      return
    }
    this.hasLoadRequested = true
    this.isLoading = true
    this.errorMessage = ''
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.errorMessage = AppStrings.text(AppStrings.R_API_ERROR_WEB_SESSION_EXPIRED, 'Please log in first to view this page')
      this.pageMessage = ''
      this.isLoading = false
      return
    }

    const normalizedTargetUrl = this.normalizeFirstPartyTargetUrl(this.targetUrl)
    if (!normalizedTargetUrl || !this.isV2exAllowedUrl(normalizedTargetUrl)) {
      this.errorMessage = AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Unsupported URL')
      this.pageMessage = ''
      this.isLoading = false
      return
    }

    this.targetUrl = normalizedTargetUrl
    // Write back the normalised URL to the V1 AppStorage key (still read by Index) — previously
    // done implicitly by the @StorageLink two-way binding.
    publishAccountWebViewUrl(normalizedTargetUrl)
    this.pageMessage = AppStrings.format(AppStrings.text(AppStrings.R_WEB_LOGIN_OPENING_URL, 'Opening {0}'), [normalizedTargetUrl])
    this.injectCookie(cookie, this.webBaseUrl())
      .then(() => {
        this.hasInjectedCookie = true
        try {
          this.controller.loadUrl(normalizedTargetUrl)
        } catch (error) {
          const e = error as Error
          DiagnosticLogger.exception('webview', 'account_webview_load_url_exception', e, { url: normalizedTargetUrl })
          this.errorMessage = e.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to load page')
          this.pageMessage = ''
          this.isLoading = false
        }
      })
      .catch((error: Error) => {
        DiagnosticLogger.exception('webview', 'account_webview_inject_cookie_exception', error, { url: normalizedTargetUrl, baseUrl: this.webBaseUrl() })
        this.errorMessage = error.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to inject cookie')
        this.pageMessage = ''
        this.isLoading = false
      })
  }

  private async injectCookie(cookie: string, baseUrl: string): Promise<void> {
    try {
      await webview.WebCookieManager.configCookie(
        baseUrl,
        `${cookie}; Path=/`,
        false,
        true
      )
      try {
        webview.WebCookieManager.saveCookieSync()
      } catch (error) {
        DiagnosticLogger.exception('webview', 'account_webview_save_cookie_sync_exception', error as Error, { baseUrl: baseUrl })
        try {
          await webview.WebCookieManager.saveCookieAsync()
        } catch (e) {
          DiagnosticLogger.exception('webview', 'account_webview_save_cookie_async_exception', e as Error, { baseUrl: baseUrl })
        }
      }
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('webview', 'account_webview_config_cookie_exception', e, { baseUrl: baseUrl })
      throw new Error('Failed to inject cookie: ' + (e.message || 'unknown'))
    }
  }

  private webBaseUrl(): string {
    return this.http.getBaseUrl()
  }

  private isV2exAllowedUrl(url: string): boolean {
    return V2exUrlRouter.isFirstPartySiteUrl(url)
  }

  private normalizeFirstPartyTargetUrl(url: string): string {
    return V2exUrlRouter.withSelectedBaseUrl(url, this.webBaseUrl())
  }
}
