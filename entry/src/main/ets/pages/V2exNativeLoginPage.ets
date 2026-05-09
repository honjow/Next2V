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

  aboutToAppear(): void {
    this.loadChallenge()
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
        action: () => { this.stack.pushPathByName('V2exWebLogin', null) }
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

      if (this.challenge?.captchaField) {
        AppTextField({
          text: $captchaCode,
          placeholder: '验证码',
          onTextChange: (value: string) => { this.captchaCode = value }
        })
          .width('100%')
      }

      if (this.twoFactorChallenge) {
        AppTextField({
          text: $twoFactorCode,
          placeholder: '两步验证码',
          onTextChange: (value: string) => { this.twoFactorCode = value }
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
      return this.twoFactorChallenge ? '验证中…' : '登录中…'
    }
    if (this.twoFactorChallenge) {
      return '完成两步验证'
    }
    return '登录'
  }

  private loadChallenge(message: string = ''): void {
    this.isChallengeLoading = true
    this.errorMessage = message
    this.captchaCode = ''
    this.twoFactorCode = ''
    this.twoFactorChallenge = null
    this.auth.prepareLogin()
      .then((challenge: NativeLoginChallenge) => {
        this.challenge = challenge
        if (!challenge.captchaUrl) {
          return ''
        }
        return this.auth.fetchCaptchaDataUrl(challenge)
      })
      .then((captchaUrl: string) => {
        this.captchaUrl = captchaUrl
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '登录表单加载失败'
      })
      .finally(() => {
        this.isChallengeLoading = false
      })
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
    this.isLoading = true
    this.errorMessage = ''

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()

    this.auth.loginWithChallenge(this.challenge, cleanUsername, pwd, this.captchaCode)
      .then((snapshot: NativeLoginSnapshot) => this.finishLogin(context, baseUrl, snapshot))
      .catch((error: Error) => {
        if (error instanceof NativeTwoFactorRequiredError) {
          this.twoFactorChallenge = error.challenge
          this.twoFactorCode = ''
          this.errorMessage = '请输入两步验证码'
          return
        }
        this.errorMessage = error.message || '登录失败'
        if (this.challenge?.captchaField) {
          this.loadChallenge(this.errorMessage)
        }
      })
      .finally(() => {
        this.isLoading = false
      })
  }

  private completeTwoFactor(): void {
    if (!this.twoFactorChallenge) {
      return
    }
    this.isLoading = true
    this.errorMessage = ''

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()
    this.auth.completeTwoFactor(this.twoFactorChallenge, this.twoFactorCode)
      .then((snapshot: NativeLoginSnapshot) => this.finishLogin(context, baseUrl, snapshot))
      .catch((error: Error) => {
        this.errorMessage = error.message || '两步验证失败'
      })
      .finally(() => {
        this.isLoading = false
      })
  }

  private finishLogin(
    context: common.UIAbilityContext,
    baseUrl: string,
    snapshot: NativeLoginSnapshot
  ): Promise<void> {
    return CookieJarSettings.saveForBaseUrl(context, baseUrl, snapshot.cookie)
      .then(() => {
        return this.api.getMember(snapshot.username)
          .then((profile) => {
            return AuthSessionSettings.save(context, {
              loginMode: 'cookie',
              username: snapshot.username,
              avatar: profile.avatar_normal || '',
              validatedAt: Date.now()
            })
          })
      })
      .then(() => {
        this.password = ''
        this.twoFactorCode = ''
        this.twoFactorChallenge = null
        promptAction.openToast({ message: '登录成功' }).catch((error: Error) => {
          console.error('openToast failed: ' + error.message)
        })
        this.stack.pop()
      })
  }
}
