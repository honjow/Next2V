import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import {
  ApiService,
  AuthSessionSettings,
  CookieJarSettings,
  HttpClient,
  SecondaryListScaffold,
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
  private autoSaveTimerId: number = 0
  private autoSaveAttempt: number = 0
  private isAutoSaving: boolean = false
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
                this.loadSigninPage()
              })
              .onPageBegin((event?: PageEndEvent) => {
                this.pageMessage = event?.url ? `正在加载 ${event.url}` : '正在加载网页登录...'
                if (event && event.url) {
                  this.lastUrl = event.url
                }
                this.scheduleAutoSave()
              })
              .onPageEnd((event?: PageEndEvent) => {
                this.pageMessage = ''
                if (event && event.url) {
                  this.lastUrl = event.url
                }
                this.scheduleAutoSave()
              })
              .onLoadFinished((event?: PageEndEvent) => {
                if (event && event.url) {
                  this.lastUrl = event.url
                }
                this.scheduleAutoSave()
              })
              .onErrorReceive((event) => {
                if (event?.request?.isMainFrame()) {
                  this.pageMessage = event.error.getErrorInfo() || '网页登录加载失败'
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

  private scheduleAutoSave(delay: number = 900): void {
    if (this.isSaving || this.isAutoSaving || this.isSaved) {
      return
    }
    if (this.autoSaveTimerId) {
      clearTimeout(this.autoSaveTimerId)
      this.autoSaveTimerId = 0
    }
    this.autoSaveTimerId = setTimeout(() => {
      this.autoSaveTimerId = 0
      this.autoSaveAttempt += 1
      this.saveLogin(true, this.autoSaveAttempt)
    }, delay)
  }

  private saveLogin(silent: boolean, autoAttempt: number = 0): void {
    if (this.isSaved || this.isSaving || this.isAutoSaving) {
      return
    }
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
    this.fetchWebLoginCookie()
      .then(async (cookie: string) => {
        const cleanCookie = cookie?.trim() || ''
        if (!cleanCookie) {
          throw new Error('未获取到登录 Cookie，请确认已完成登录')
        }
        if (silent && !this.hasLikelyAuthCookie(cleanCookie)) {
          throw new Error('网页登录尚未完成')
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
        } else if (!this.isSaved && autoAttempt > 0 && autoAttempt < 12) {
          setTimeout(() => {
            if (!this.isSaved) {
              this.saveLogin(true, autoAttempt + 1)
            }
          }, 1200)
        }
      })
      .finally(() => {
        if (silent) {
          this.isAutoSaving = false
        } else {
          this.isSaving = false
        }
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
}
