import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import { AuthSessionSettings, CookieJarSettings, HttpClient, ThemeConstants } from 'shared'

interface PageEndEvent {
  url: string
}

@Component
export struct V2exWebLoginPage {
  @Consume('ns') stack: NavPathStack

  private controller: webview.WebviewController = new webview.WebviewController()
  private http: HttpClient = HttpClient.getInstance()

  @State private errorMessage: string = ''
  @State private isSaving: boolean = false
  @State private lastUrl: string = ''

  private get baseUrl(): string {
    return this.http.getBaseUrl()
  }

  private get signinUrl(): string {
    return `${this.baseUrl}/signin`
  }

  build() {
    Column() {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text('使用 V2EX 官方网页登录')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('登录完成后，点击“保存登录”即可返回。')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        if (this.lastUrl) {
          Text(this.lastUrl)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(Color.Red)
            .margin({ top: ThemeConstants.SPACE_XS })
        }
        Row({ space: ThemeConstants.SPACE_SM }) {
          Button(this.isSaving ? '保存中…' : '保存登录')
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .height(40)
            .enabled(!this.isSaving)
            .onClick(() => { this.saveLogin() })
          Button('重新加载')
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .height(40)
            .enabled(!this.isSaving)
            .onClick(() => { this.controller.refresh() })
        }
      }
      .padding(ThemeConstants.SPACE_LG)
      .width('100%')

      Web({ src: this.signinUrl, controller: this.controller })
        .darkMode(WebDarkMode.Auto)
        .width('100%')
        .layoutWeight(1)
        .onPageEnd((event?: PageEndEvent) => {
          if (event && event.url) {
            this.lastUrl = event.url
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private saveLogin(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.baseUrl
    this.isSaving = true
    this.errorMessage = ''
    webview.WebCookieManager.fetchCookie(baseUrl)
      .then((cookie: string) => {
        if (!cookie || cookie.trim().length === 0) {
          throw new Error('未获取到登录 Cookie，请确认已完成登录')
        }
        return CookieJarSettings.saveForBaseUrl(context, baseUrl, cookie)
      })
      .then(() => {
        return AuthSessionSettings.save(context, { loginMode: 'cookie', username: '', avatar: '', validatedAt: Date.now() })
      })
      .then(() => {
        promptAction.openToast({ message: '登录已保存' }).catch((error: Error) => {
          console.error('openToast failed: ' + error.message)
        })
        this.stack.pop()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '保存登录失败'
      })
      .finally(() => {
        this.isSaving = false
      })
  }
}
