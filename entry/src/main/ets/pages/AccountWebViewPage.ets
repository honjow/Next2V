import { webview } from '@kit.ArkWeb'
import {
  AppStrings,
  CookieJarSettings,
  HttpClient,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants,
  V2exUrlRouter,
} from 'shared'

@Component
export struct AccountWebViewPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink(StorageKeys.ACCOUNT_WEB_VIEW_URL) targetUrl: string = ''
  @StorageLink(StorageKeys.ACCOUNT_WEB_VIEW_ACTION) @Watch('onAccountWebViewAction') accountWebViewAction: string = ''

  private controller: webview.WebviewController = new webview.WebviewController()
  private http: HttpClient = HttpClient.getInstance()

  @State private isLoading: boolean = true
  @State private errorMessage: string = ''
  @State private pageMessage: string = AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…')
  @State private hasInjectedCookie: boolean = false
  @State private hasLoadRequested: boolean = false

  aboutToAppear(): void {
    if (!this.targetUrl) {
      this.errorMessage = AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'No page URL provided')
      this.pageMessage = ''
      this.isLoading = false
    }
  }

  build() {
    Column() {
      Column() {
        SecondaryListScaffold({ horizontalPadding: 0, bottomPadding: 0, listSpace: 0 }) {
          ListItem() {
            Web({ src: '', controller: this.controller })
              .darkMode(WebDarkMode.Off)
              .backgroundColor(Color.White)
              .javaScriptAccess(true)
              .domStorageAccess(true)
              .onlineImageAccess(true)
              .width('100%')
              .height('100%')
              .onControllerAttached(() => {
                this.loadTargetUrl()
              })
              .onPageBegin(() => {
                this.isLoading = true
                this.errorMessage = ''
                this.pageMessage = AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…')
              })
              .onPageEnd(() => {
                this.isLoading = false
                this.pageMessage = ''
              })
              .onErrorReceive((event) => {
                if (event?.request?.isMainFrame()) {
                  this.isLoading = false
                  this.pageMessage = ''
                  this.errorMessage = event.error.getErrorInfo() ||
                    AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to load page')
                }
              })
          }
          .height('100%')
          .clip(false)
        }
      }
      .width('100%')
      .layoutWeight(1)

      this.StatusBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  StatusBar() {
    if (this.isLoading || this.errorMessage || this.pageMessage) {
      Row() {
        Text(this.statusText())
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(this.errorMessage ? Color.Red : $r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_MD,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS
      })
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    }
  }

  private statusText(): string {
    if (this.errorMessage) {
      return this.errorMessage
    }
    return this.pageMessage
  }

  onAccountWebViewAction(_propName: string): void {
    const action = this.accountWebViewAction.split(':').pop() || ''
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
    this.pageMessage = AppStrings.format(AppStrings.text(AppStrings.R_WEB_LOGIN_OPENING_URL, 'Opening {0}'), [normalizedTargetUrl])
    this.injectCookie(cookie, this.webBaseUrl())
      .then(() => {
        this.hasInjectedCookie = true
        try {
          this.controller.loadUrl(normalizedTargetUrl)
        } catch (error) {
          const e = error as Error
          this.errorMessage = e.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to load page')
          this.pageMessage = ''
          this.isLoading = false
        }
      })
      .catch((error: Error) => {
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
      } catch (_error) {
        try {
          await webview.WebCookieManager.saveCookieAsync()
        } catch (_e) {
        }
      }
    } catch (error) {
      const e = error as Error
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
