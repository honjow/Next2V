import { webview } from '@kit.ArkWeb'
import {
  AppStrings,
  CookieJarSettings,
  HttpClient,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants,
} from 'shared'

@Component
export struct AccountWebViewPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) authCookieConfigured: boolean = false
  @StorageLink(StorageKeys.ACCOUNT_WEB_VIEW_URL) targetUrl: string = ''

  private controller: webview.WebviewController = new webview.WebviewController()
  private http: HttpClient = HttpClient.getInstance()

  @State private isLoading: boolean = true
  @State private errorMessage: string = ''
  @State private hasInjectedCookie: boolean = false

  aboutToAppear(): void {
    if (!this.targetUrl) {
      this.errorMessage = AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'No page URL provided')
      return
    }
    this.loadTargetUrl()
  }

  build() {
    Column() {
      Column() {
        SecondaryListScaffold({ horizontalPadding: 0, bottomPadding: 0, listSpace: 0 }) {
          ListItem() {
            Web({ src: this.targetUrl, controller: this.controller })
              .darkMode(WebDarkMode.Off)
              .backgroundColor(Color.White)
              .javaScriptAccess(true)
              .domStorageAccess(true)
              .onlineImageAccess(true)
              .width('100%')
              .height('100%')
              .onPageBegin(() => {
                this.isLoading = true
                this.errorMessage = ''
              })
              .onPageEnd(() => {
                this.isLoading = false
              })
              .onErrorReceive((event) => {
                if (event?.request?.isMainFrame()) {
                  this.isLoading = false
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

      if (!this.authCookieConfigured) {
        this.LoggedOutBar()
      }
      if (this.errorMessage) {
        this.ErrorBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  LoggedOutBar() {
    Row() {
      Text(AppStrings.text(AppStrings.R_WEB_SESSION_EXPIRED_RELOGIN, 'Not logged in'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(Color.Red)
        .maxLines(1)
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

  @Builder
  ErrorBar() {
    Row() {
      Text(this.errorMessage)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(Color.Red)
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

  private loadTargetUrl(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.errorMessage = AppStrings.text(AppStrings.R_WEB_SESSION_EXPIRED_RELOGIN, 'Please log in first to view this page')
      return
    }

    if (!this.isV2exAllowedUrl(this.targetUrl)) {
      this.errorMessage = AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Unsupported URL')
      return
    }

    this.injectCookie(cookie, this.targetUrl)
      .then(() => {
        this.hasInjectedCookie = true
        try {
          this.controller.loadUrl(this.targetUrl)
        } catch (error) {
          const e = error as Error
          this.errorMessage = e.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to load page')
        }
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Failed to inject cookie')
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
    const cleanUrl = (url || '').trim()
    if (!cleanUrl) {
      return false
    }
    const normalizedUrl = cleanUrl.toLowerCase()
    return normalizedUrl.startsWith('https://www.v2ex.com') ||
      normalizedUrl.startsWith('https://v2ex.com') ||
      normalizedUrl.startsWith('https://www.v2ex.co') ||
      normalizedUrl.startsWith('https://v2ex.co')
  }
}
