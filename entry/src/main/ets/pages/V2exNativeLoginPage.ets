import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AppTextField,
  AuthSessionSettings,
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
import type { NativeLoginChallenge, NativeLoginSnapshot, NativeTwoFactorChallenge } from 'shared'

@Component
export struct V2exNativeLoginPage {
  @Consume('ns') stack: NavPathStack

  @State private username: string = ''
  @State private password: string = ''
  @State private captchaCode: string = ''
  @State private captchaField: string = ''
  @State private captchaUrl: string = ''
  @State private twoFactorCode: string = ''
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false
  @State private isChallengeLoading: boolean = false

  private challenge: NativeLoginChallenge | null = null
  private twoFactorChallenge: NativeTwoFactorChallenge | null = null
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

      if (this.twoFactorChallenge) {
        Text('请输入当前一次性验证码；如果验证码已过期，可以重新开始登录。')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        AppTextField({
          text: $twoFactorCode,
          placeholder: '两步验证码',
          onTextChange: (value: string) => { this.twoFactorCode = value }
        })
          .width('100%')
        AppActionButton({
          label: '重新开始登录',
          primary: false,
          isEnabled: !this.isLoading && !this.isChallengeLoading,
          action: () => { this.restartLoginChallenge() }
        })
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
      return this.twoFactorChallenge ? '验证中…' : '登录中…'
    }
    if (this.twoFactorChallenge) {
      return '完成两步验证'
    }
    return '登录'
  }

  private loadChallenge(message: string = ''): void {
    const requestId = ++this.challengeRequestId
    this.isChallengeLoading = true
    this.errorMessage = message
    this.captchaCode = ''
    this.twoFactorCode = ''
    this.twoFactorChallenge = null
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
    this.twoFactorCode = ''
    this.isLoading = false
    this.isChallengeLoading = false
    this.challenge = null
    this.twoFactorChallenge = null
  }

  private isCurrentAuthRequest(requestId: number): boolean {
    return this.isPageActive && requestId === this.authRequestId
  }

  private login(): void {
    if (this.twoFactorChallenge) {
      this.completeTwoFactor()
      return
    }
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
          return
        }
        if (error instanceof NativeTwoFactorRequiredError) {
          this.twoFactorChallenge = error.challenge
          this.twoFactorCode = ''
          this.errorMessage = '请输入两步验证码'
          return
        }
        this.errorMessage = error.message || '登录失败'
        if (this.captchaField) {
          this.loadChallenge(this.errorMessage)
        }
      })
      .finally(() => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return
        }
        this.isLoading = false
      })
  }

  private completeTwoFactor(): void {
    if (!this.twoFactorChallenge) {
      return
    }
    const requestId = ++this.authRequestId
    const twoFactorChallenge = this.twoFactorChallenge
    const twoFactorCode = this.twoFactorCode
    this.isLoading = true
    this.errorMessage = ''

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()
    this.auth.completeTwoFactor(twoFactorChallenge, twoFactorCode)
      .then((snapshot: NativeLoginSnapshot) => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return
        }
        return this.finishLogin(context, baseUrl, snapshot, requestId)
      })
      .catch((error: Error) => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return
        }
        if (error instanceof NativeTwoFactorRequiredError) {
          this.twoFactorChallenge = error.challenge
        }
        this.twoFactorCode = ''
        this.errorMessage = error.message || '两步验证失败'
      })
      .finally(() => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return
        }
        this.isLoading = false
      })
  }

  private finishLogin(
    context: common.UIAbilityContext,
    baseUrl: string,
    snapshot: NativeLoginSnapshot,
    requestId: number
  ): Promise<void> {
    if (!this.isCurrentAuthRequest(requestId)) {
      return Promise.resolve()
    }
    return CookieJarSettings.saveForBaseUrl(context, baseUrl, snapshot.cookie)
      .then(() => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return Promise.resolve()
        }
        return this.api.getMember(snapshot.username)
          .then((profile) => {
            if (!this.isCurrentAuthRequest(requestId)) {
              return Promise.resolve()
            }
            return AuthSessionSettings.save(context, {
              loginMode: 'cookie',
              username: snapshot.username,
              avatar: profile.avatar_normal || '',
              validatedAt: Date.now()
            })
          })
      })
      .then(() => {
        if (!this.isCurrentAuthRequest(requestId)) {
          return
        }
        this.password = ''
        this.twoFactorCode = ''
        this.twoFactorChallenge = null
        promptAction.openToast({ message: '登录成功' }).catch((error: Error) => {
          console.error('openToast failed: ' + error.message)
        })
        this.stack.pop()
      })
  }

  private shouldShowCaptchaField(): boolean {
    return !!this.captchaField || !!this.captchaUrl
  }
}
