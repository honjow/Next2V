import { webview } from '@kit.ArkWeb'
import {
  AppStrings,
  CookieJarSettings,
  DiagnosticLogger,
  HttpClient,
  V2exWebView,
  V2exWebViewScaffold,
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
  private ns: NavPathStack = connectNavStack().stack;
  // The target URL is an input the opener (AccountDetailPage) publishes into the AccountWebViewUrlState
  // mirror before navigating; it is logic-only (never read in build()), so it is read imperatively on
  // appear from the mirror and the normalised value is re-published through publishAccountWebViewUrl.
  private targetUrl: string = '';
  // V2 mirror of the one-directional ACCOUNT_WEB_VIEW_ACTION reload bus (Index dual-writes).
  // Reacted to via @Monitor below; never read in build().
  @Local private actionState: AccountWebViewActionState = connectAccountWebViewAction();

  private controller: webview.WebviewController = new webview.WebviewController();
  private http: HttpClient = HttpClient.getInstance();

  @Local private isLoading: boolean = true;
  @Local private errorMessage: string = '';
  @Local private pageMessage: string = AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…');
  @Local private hasInjectedCookie: boolean = false;
  @Local private hasLoadRequested: boolean = false;

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
      statusMaxLines: 2,
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
            hasCookie: this.hasInjectedCookie,
          })
        },
        onPageEnd: (event?: PageEndEvent) => {
          this.isLoading = false
          this.pageMessage = ''
          DiagnosticLogger.info('webview', 'account_webview_page_end', {
            url: event && event.url ? event.url : this.targetUrl,
            hasCookie: this.hasInjectedCookie,
          })
        },
        onErrorReceive: (event) => {
          if (event?.request?.isMainFrame()) {
            this.isLoading = false
            this.pageMessage = ''
            this.errorMessage =
              event.error.getErrorInfo() ||
              AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to load page')
            DiagnosticLogger.warn('webview', 'account_webview_load_error', {
              url: this.targetUrl,
              isMainFrame: true,
              errorInfo: this.errorMessage,
              hasCookie: this.hasInjectedCookie,
            })
          }
        },
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
      DiagnosticLogger.exception('webview', 'account_webview_reload_exception', e, {
        url: this.targetUrl,
      })
      this.isLoading = false
      this.pageMessage = ''
      this.errorMessage =
        e.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to refresh page')
    }
  }

  private loadTargetUrl(): void {
    if (this.hasLoadRequested) {
      return
    }
    this.hasLoadRequested = true
    this.isLoading = true
    this.errorMessage = ''

    // General in-app WebView: resolve a relative path (e.g. the dict node's "/d/" link) against the V2EX
    // base, then accept any http(s) URL — first-party OR external. The V2EX session cookie is injected
    // ONLY for the V2EX origin (never leaked to third-party sites). This serves account pages, topic
    // "open in app", and node-description links alike.
    const origin = this.webBaseUrl().replace(/\/+$/, '')
    let target = (this.targetUrl || '').trim()
    if (target.startsWith('/')) {
      target = origin + target
    }
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      this.errorMessage = AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Unsupported URL')
      this.pageMessage = ''
      this.isLoading = false
      return
    }

    this.targetUrl = target
    publishAccountWebViewUrl(target)
    this.pageMessage = AppStrings.format(
      AppStrings.text(AppStrings.R_WEB_LOGIN_OPENING_URL, 'Opening {0}'),
      [target],
    )

    const isV2exOrigin = origin.length > 0 && target.startsWith(origin)
    const cookie = isV2exOrigin ? CookieJarSettings.getCurrentCookie() : ''
    if (isV2exOrigin && cookie) {
      this.injectCookie(cookie, this.webBaseUrl())
        .then(() => {
          this.hasInjectedCookie = true
          this.safeLoadUrl(target)
        })
        .catch((error: Error) => {
          DiagnosticLogger.exception('webview', 'account_webview_inject_cookie_exception', error, {
            url: target,
            baseUrl: this.webBaseUrl(),
          })
          // Cookie injection failed — still show the page (logged-out) rather than a hard error.
          this.safeLoadUrl(target)
        })
      return
    }
    // External site, or first-party without a session: load directly (no cookie).
    this.safeLoadUrl(target)
  }

  private safeLoadUrl(url: string): void {
    try {
      this.controller.loadUrl(url)
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('webview', 'account_webview_load_url_exception', e, { url: url })
      this.errorMessage =
        e.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to load page')
      this.pageMessage = ''
      this.isLoading = false
    }
  }

  private async injectCookie(cookie: string, baseUrl: string): Promise<void> {
    try {
      await webview.WebCookieManager.configCookie(baseUrl, `${cookie}; Path=/`, false, true)
      try {
        webview.WebCookieManager.saveCookieSync()
      } catch (error) {
        DiagnosticLogger.exception(
          'webview',
          'account_webview_save_cookie_sync_exception',
          error as Error,
          { baseUrl: baseUrl },
        )
        try {
          await webview.WebCookieManager.saveCookieAsync()
        } catch (e) {
          DiagnosticLogger.exception(
            'webview',
            'account_webview_save_cookie_async_exception',
            e as Error,
            { baseUrl: baseUrl },
          )
        }
      }
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('webview', 'account_webview_config_cookie_exception', e, {
        baseUrl: baseUrl,
      })
      throw new Error('Failed to inject cookie: ' + (e.message || 'unknown'))
    }
  }

  private webBaseUrl(): string {
    return this.http.getBaseUrl()
  }
}
