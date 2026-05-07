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
  SecondaryListScaffold,
  ThemeConstants,
  V2exNativeAuthService
} from 'shared'
import type { NativeLoginChallenge } from 'shared'

@Component
export struct V2exNativeLoginPage {
  @Consume('ns') stack: NavPathStack

  @State private username: string = ''
  @State private password: string = ''
  @State private captchaCode: string = ''
  @State private captchaUrl: string = ''
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false
  @State private isChallengeLoading: boolean = false

  private challenge: NativeLoginChallenge | null = null
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

      AppTextField({
        text: $password,
        placeholder: '密码',
        inputType: InputType.Password,
        onTextChange: (value: string) => { this.password = value }
      })

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
    this.isChallengeLoading = true
    this.errorMessage = message
    this.captchaCode = ''
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
      .then((snapshot) => {
        return CookieJarSettings.saveForBaseUrl(context, baseUrl, snapshot.cookie)
          .then(() => snapshot)
      })
      .then((snapshot) => {
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
        promptAction.openToast({ message: '登录成功' }).catch((error: Error) => {
          console.error('openToast failed: ' + error.message)
        })
        this.stack.pop()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '登录失败'
        if (this.challenge?.captchaField) {
          this.loadChallenge(this.errorMessage)
        }
      })
      .finally(() => {
        this.isLoading = false
      })
  }
}
