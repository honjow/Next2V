import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import {
  ApiService,
  AuthSessionSettings,
  CookieJarSettings,
  HttpClient,
  StorageKeys,
  ThemeConstants,
  V2exSessionParser
} from 'shared'

const DEFAULT_V2EX_BASE_URL: string = 'https://www.v2ex.com'

interface PageEndEvent {
  url: string
}

interface ValidatedCookie {
  cookie: string
  username: string
}

@Component
export struct V2exWebLoginPage {
  @Consume('ns') stack: NavPathStack

  private controller: webview.WebviewController = new webview.WebviewController()
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()

  @State private errorMessage: string = ''
  @State private pageMessage: string = '正在打开网页登录...'
  @State private isSaving: boolean = false
  @State private isSaved: boolean = false
  @State private lastUrl: string = ''
  @StorageLink(StorageKeys.WEB_LOGIN_ACTION) @Watch('onWebLoginAction') webLoginAction: string = ''

  private get baseUrl(): string {
    return this.http.getBaseUrl()
  }

  private currentSigninUrl(): string {
    const cleanBase = (this.baseUrl || DEFAULT_V2EX_BASE_URL).trim().replace(/\/+$/, '')
    const hasProtocol = cleanBase.indexOf('http://') === 0 || cleanBase.indexOf('https://') === 0
    let normalizedBase = DEFAULT_V2EX_BASE_URL
    if (hasProtocol) {
      normalizedBase = cleanBase
    }
    return `${normalizedBase}/signin`
  }

  build() {
    Column() {
      Web({ src: '', controller: this.controller })
        .darkMode(WebDarkMode.Auto)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onlineImageAccess(true)
        .width('100%')
        .layoutWeight(1)
        .onControllerAttached(() => {
          this.loadSigninPage()
        })
        .onPageBegin((event?: PageEndEvent) => {
          this.pageMessage = event?.url ? `正在加载 ${event.url}` : '正在加载网页登录...'
        })
        .onPageEnd((event?: PageEndEvent) => {
          this.pageMessage = ''
          if (event && event.url) {
            this.lastUrl = event.url
            this.tryAutoSave(event.url)
          }
        })
        .onErrorReceive((event) => {
          if (event?.request?.isMainFrame()) {
            this.pageMessage = event.error.getErrorInfo() || '网页登录加载失败'
          }
        })

      this.StatusBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  StatusBar() {
    if (this.isSaving || this.errorMessage || this.pageMessage) {
      Row() {
        Text(this.statusText())
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(this.errorMessage ? Color.Red : $r('sys.color.font_secondary'))
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
  }

  private statusText(): string {
    if (this.isSaving) {
      return '正在保存登录状态…'
    }
    if (this.errorMessage) {
      return this.errorMessage
    }
    return this.pageMessage
  }

  onWebLoginAction(_propName: string): void {
    const action = this.webLoginAction.split(':').pop() || ''
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
      const e = error as Error
      this.errorMessage = e.message || '重新加载失败'
    }
  }

  private loadSigninPage(): void {
    const url = this.currentSigninUrl()
    this.pageMessage = `正在打开 ${url}`
    try {
      this.controller.loadUrl(url)
    } catch (error) {
      const e = error as Error
      this.errorMessage = `${e.message || '网页登录加载失败'}: ${url}`
    }
  }

  private tryAutoSave(url: string): void {
    const cleanUrl = (url || '').trim()
    if (this.isSaving || this.isSaved || !cleanUrl || cleanUrl.indexOf('/signin') >= 0) {
      return
    }
    this.saveLogin(true)
  }

  private saveLogin(silent: boolean): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.baseUrl
    this.isSaving = true
    if (!silent) {
      this.errorMessage = ''
    }
    this.fetchWebLoginCookie()
      .then(async (cookie: string) => {
        const cleanCookie = cookie?.trim() || ''
        if (!cleanCookie) {
          throw new Error('未获取到登录 Cookie，请确认已完成登录')
        }
        const html = await this.http.getTextWithHeaders('/settings', { 'Cookie': cleanCookie })
        const username = V2exSessionParser.extractUsername(html)
        if (!username) {
          throw new Error('Cookie 登录态无效，请确认已完成登录')
        }
        const validated: ValidatedCookie = { cookie: cleanCookie, username }
        return validated
      })
      .then(async (validated: ValidatedCookie) => {
        const username = validated.username
        await CookieJarSettings.saveForBaseUrl(context, baseUrl, validated.cookie)
        let avatar = ''
        try {
          const profile = await this.api.getMember(username)
          avatar = profile.avatar_normal || profile.avatar_large || profile.avatar_mini || ''
        } catch (_error) {
          avatar = ''
        }
        await AuthSessionSettings.save(context, { loginMode: 'cookie', username, avatar, validatedAt: Date.now() })
      })
      .then(() => {
        this.isSaved = true
        promptAction.openToast({ message: '登录已保存' }).catch((error: Error) => {
          console.error('openToast failed: ' + error.message)
        })
        this.stack.pop()
      })
      .catch((error: Error) => {
        if (!silent) {
          this.errorMessage = error.message || '保存登录失败'
        }
      })
      .finally(() => {
        this.isSaving = false
      })
  }

  private async fetchWebLoginCookie(): Promise<string> {
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (_error) {
      try {
        await webview.WebCookieManager.saveCookieAsync()
      } catch (_e) {
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
      } catch (_error) {
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
}
