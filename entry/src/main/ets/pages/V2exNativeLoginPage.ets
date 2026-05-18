import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AppTextField,
  AuthSessionSettings,
  AutoDailyCheckinService,
  AppActionButton,
  ConciseListRow,
  CookieJarSettings,
  GroupedListSection,
  HttpClient,
  NativeTwoFactorRequiredError,
  SecondaryListScaffold,
  ThemeConstants,
  V2exNativeAuthService
} from 'shared'
import type { NativeLoginChallenge, NativeLoginSnapshot } from 'shared'

@Component
export struct V2exNativeLoginPage {
  @Consume('ns') stack: NavPathStack

  @State private username: string = ''
  @State private password: string = ''
  @State private captchaCode: string = ''
  @State private captchaField: string = ''
  @State private captchaUrl: string = ''
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false
  @State private isChallengeLoading: boolean = false

  private challenge: NativeLoginChallenge | null = null
  private auth: V2exNativeAuthService = new V2exNativeAuthService()
  private api: ApiService = new ApiService()
  private http: HttpClient = HttpClient.getInstance()
  private isPageActive: boolean = false
  private challengeRequestId: number = 0
  private authRequestId: number = 0

  aboutToAppear(): void {
    this.isPageActive = true
    this.clearSecretState()
    this.loadChallenge()
  }

  aboutToDisappear(): void {
    this.isPageActive = false
    this.clearSecretState()
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        ListItem() {
          this.LoginForm()
        }

        ListItem() {
          this.WebLoginForm()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder WebLoginForm() {
    GroupedListSection() {
      ConciseListRow({
        title: '网页登录',
        showChevron: true,
        action: () => {
          this.clearSecretState()
          this.stack.pushPathByName('V2exWebLogin', null)
        }
      })
    }
  }

  @Builder LoginForm() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      AppTextField({
        text: $username,
        placeholder: '用户名或邮箱',
        onTextChange: (value: string) => { this.username = value }
      })
        .width('100%')

      AppTextField({
        text: $password,
        placeholder: '密码',
        inputType: InputType.Password,
        onTextChange: (value: string) => { this.password = value }
      })
        .width('100%')

      if (this.captchaUrl) {
        Image(this.captchaUrl)
          .width('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.White)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .margin(ThemeConstants.SPACE_SM)
          .onClick(() => { this.loadChallenge() })
      }

      if (this.shouldShowCaptchaField()) {
        AppTextField({
          text: $captchaCode,
          placeholder: '验证码',
          onTextChange: (value: string) => { this.captchaCode = value }
        })
          .width('100%')
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }

      AppActionButton({
        label: this.loginButtonText(),
        primary: true,
        isEnabled: !this.isLoading && !this.isChallengeLoading,
        action: () => { this.login() }
      })
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private loginButtonText(): string {
    if (this.isChallengeLoading) {
      return '准备中…'
    }
    if (this.isLoading) {
      return '登录中…'
    }
    return '登录'
  }

  private loadChallenge(message: string = ''): void {
    const requestId = ++this.challengeRequestId
    this.isChallengeLoading = true
    this.errorMessage = message
    this.captchaCode = ''
    this.challenge = null
    this.captchaField = ''
    this.captchaUrl = ''
    this.auth.prepareLogin()
      .then((challenge: NativeLoginChallenge) => {
        if (!this.isPageActive || requestId !== this.challengeRequestId) {
          return ''
        }
        this.challenge = challenge
        this.captchaField = challenge.captchaField
        if (!challenge.captchaUrl) {
          return ''
        }
        return this.auth.fetchCaptchaDataUrl(challenge)
      })
      .then((captchaUrl: string) => {
        if (!this.isPageActive || requestId !== this.challengeRequestId) {
          return
        }
        this.captchaUrl = captchaUrl
      })
      .catch((error: Error) => {
        if (!this.isPageActive || requestId !== this.challengeRequestId) {
          return
        }
        this.errorMessage = error.message || '登录表单加载失败'
      })
      .finally(() => {
        if (!this.isPageActive || requestId !== this.challengeRequestId) {
          return
        }
        this.isChallengeLoading = false
      })
  }

  private restartLoginChallenge(): void {
    this.clearSecretState()
    this.loadChallenge('已重新获取登录表单，请重新输入密码')
  }

  private clearSecretState(): void {
    this.challengeRequestId++
    this.authRequestId++
    this.password = ''
    this.captchaCode = ''
    this.captchaField = ''
    this.captchaUrl = ''
    this.isLoading = false
    this.isChallengeLoading = false
    this.challenge = null
  }

  private isCurrentAuthRequest(requestId: number): boolean {
    return this.isPageActive && requestId === this.authRequestId
  }

  private login(): void {
    const cleanUsername = this.username.trim()
    const pwd = this.password
    if (!cleanUsername || !pwd) {
      this.errorMessage = '请输入用户名和密码'
      return
    }
    if (!this.challenge) {
      this.errorMessage = '登录表单未加载完成，请稍后重试'
      return
    }
    if (this.captchaUrl && !this.captchaField) {
      this.errorMessage = '登录验证码表单未加载完成，请重新获取验证码'
      return
    }
    const requestId = ++this.authRequestId
    const challenge = this.challenge
    const captchaCode = this.captchaCode
    this.isLoading = true
    this.errorMessage = ''

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()

    this.auth.loginWithChallenge(challenge, cleanUsername, pwd, captchaCode)
      .then((snapshot: NativeLoginSnapshot) => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return
        }
        return this.finishLogin(context, baseUrl, snapshot, requestId)
      })
      .catch((error: Error) => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return Promise.resolve()
        }
        if (error instanceof NativeTwoFactorRequiredError) {
          return this.finishLogin(context, baseUrl, { cookie: error.challenge.cookie, username: cleanUsername }, requestId)
        }
        this.errorMessage = error.message || '登录失败'
        if (this.captchaField) {
          this.loadChallenge(this.errorMessage)
        }
        return Promise.resolve()
      })
      .finally(() => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return
        }
        this.isLoading = false
      })
  }


  private async finishLogin(
    context: common.UIAbilityContext,
    baseUrl: string,
    snapshot: NativeLoginSnapshot,
    requestId: number
  ): Promise<void> {
    if (!this.isCurrentAuthRequest(requestId)) {
      return
    }

    let avatar = ''
    try {
      const profile = await this.api.getMember(snapshot.username)
      avatar = profile.avatar_normal || profile.avatar_large || profile.avatar_mini || ''
    } catch (_error) {
      avatar = ''
    }
    if (!this.isCurrentAuthRequest(requestId)) {
      return
    }

    try {
      await CookieJarSettings.saveForBaseUrl(context, baseUrl, snapshot.cookie)
      await AuthSessionSettings.save(context, {
        loginMode: 'cookie',
        username: snapshot.username,
        avatar,
        validatedAt: Date.now()
      })
      AutoDailyCheckinService.tryCheckin(context, snapshot.cookie, 'native-login').catch((error: Error) => {
        console.info('auto daily check-in native-login trigger failed: ' + error.message)
      })
    } catch (error) {
      await this.clearPersistedLogin(context)
      const caught = error as Error
      throw caught
    }

    if (!this.isCurrentAuthRequest(requestId)) {
      return
    }
    this.password = ''
    promptAction.openToast({ message: '登录成功' }).catch((error: Error) => {
      console.error('openToast failed: ' + error.message)
    })
    try {
      this.stack.pop()
    } catch (error) {
      const caught = error as Error
      console.error('pop login page failed: ' + caught.message)
    }
  }

  private async clearPersistedLogin(context: common.UIAbilityContext): Promise<void> {
    await Promise.all([
      CookieJarSettings.clearForBaseUrl(context, this.http.getBaseUrl()).catch((clearError: Error) => {
        console.error('clear cookie after login persist failure: ' + clearError.message)
      }),
      AuthSessionSettings.clear(context).catch((clearError: Error) => {
        console.error('clear auth session after login persist failure: ' + clearError.message)
      })
    ])
  }

  private shouldShowCaptchaField(): boolean {
    return !!this.captchaField || !!this.captchaUrl
  }
}
