import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AuthSessionSettings,
  CookieJarSettings,
  HttpClient,
  StorageKeys,
  ThemeConstants,
  V2exNativeAuthService
} from 'shared'

@Component
export struct V2exNativeLoginPage {
  @Consume('ns') stack: NavPathStack

  @State private username: string = ''
  @State private password: string = ''
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0

  private auth: V2exNativeAuthService = new V2exNativeAuthService()
  private api: ApiService = new ApiService()
  private http: HttpClient = HttpClient.getInstance()

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('账号密码登录（实验性）')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      Text('如果出现验证码/2FA 或表单字段变化，建议使用网页登录。')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))

      TextInput({ placeholder: '用户名或邮箱', text: this.username })
        .height(44)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(ThemeConstants.RADIUS_MD)
        .onChange((value: string) => { this.username = value })

      TextInput({ placeholder: '密码', text: this.password })
        .height(44)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .type(InputType.Password)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(ThemeConstants.RADIUS_MD)
        .onChange((value: string) => { this.password = value })

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button(this.isLoading ? '登录中…' : '登录')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .enabled(!this.isLoading)
          .onClick(() => { this.login() })

        Button('改用网页登录')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .enabled(!this.isLoading)
          .onClick(() => { this.stack.pop() })
      }
    }
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD,
      bottom: this.bottomH + ThemeConstants.SPACE_MD
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private login(): void {
    const cleanUsername = this.username.trim()
    const pwd = this.password
    if (!cleanUsername || !pwd) {
      this.errorMessage = '请输入用户名和密码'
      return
    }
    this.isLoading = true
    this.errorMessage = ''

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()

    this.auth.login(cleanUsername, pwd)
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
      })
      .finally(() => {
        this.isLoading = false
      })
  }
}
