import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AppActionButton,
  AppModalScaffold,
  AppTextField,
  AuthSessionSettings,
  AutoDailyCheckinService,
  CookieJarSettings,
  HttpClient,
  NativeTwoFactorRequiredError,
  ThemeConstants,
  V2exNativeAuthService
} from 'shared'
import type { NativeLoginSnapshot } from 'shared'

@Component
export struct V2exTwoFactorPrompt {
  @Link visible: boolean
  @Prop cookie: string = ''
  @Prop title: string = '两步验证'
  onSuccess?: () => void
  onCancel?: () => void

  @State private code: string = ''
  @State private errorMessage: string = ''
  @State private isSubmitting: boolean = false

  private auth: V2exNativeAuthService = new V2exNativeAuthService()
  private api: ApiService = new ApiService()
  private http: HttpClient = HttpClient.getInstance()

  build() {
    AppModalScaffold({
      title: this.title,
      closeAction: () => { this.cancel() }
    }) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Text('V2EX 需要完成两步验证后才能继续访问账号内容。')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')

          AppTextField({
            text: $code,
            placeholder: '输入 6 位验证码',
            inputType: InputType.Number,
            onTextChange: (value: string) => { this.code = value }
          })
            .width('100%')

          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(Color.Red)
              .width('100%')
          }

          AppActionButton({
            label: this.isSubmitting ? '验证中…' : '完成验证',
            primary: true,
            isEnabled: !this.isSubmitting,
            action: () => { this.submit() }
          })

          AppActionButton({
            label: '稍后再说',
            primary: false,
            isEnabled: !this.isSubmitting,
            action: () => { this.cancel() }
          })
        }
        .width('100%')
      }
    }
  }

  private submit(): void {
    if (this.isSubmitting) {
      return
    }
    const cleanCookie = (this.cookie || '').trim()
    const cleanCode = this.code.trim()
    if (!cleanCookie) {
      this.errorMessage = '缺少登录会话，请重新登录'
      return
    }
    if (!cleanCode) {
      this.errorMessage = '请输入两步验证码'
      return
    }

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()
    this.isSubmitting = true
    this.errorMessage = ''

    this.auth.completeTwoFactorWithCookie(cleanCookie, cleanCode)
      .then((snapshot: NativeLoginSnapshot) => this.persistSnapshot(context, baseUrl, snapshot))
      .then(() => {
        this.code = ''
        this.errorMessage = ''
        this.visible = false
        promptAction.openToast({ message: '两步验证已完成' }).catch((_error: Error) => { })
        if (this.onSuccess) {
          this.onSuccess()
        }
      })
      .catch((error: Error) => {
        this.code = ''
        if (error instanceof NativeTwoFactorRequiredError) {
          this.errorMessage = error.message || '两步验证失败，请检查验证码后重试'
          return
        }
        this.errorMessage = error.message || '两步验证失败，请稍后重试'
      })
      .finally(() => {
        this.isSubmitting = false
      })
  }

  private async persistSnapshot(
    context: common.UIAbilityContext,
    baseUrl: string,
    snapshot: NativeLoginSnapshot
  ): Promise<void> {
    let avatar = ''
    try {
      const profile = await this.api.getMember(snapshot.username)
      avatar = profile.avatar_normal || profile.avatar_large || profile.avatar_mini || ''
    } catch (_error) {
      avatar = ''
    }
    await CookieJarSettings.saveForBaseUrl(context, baseUrl, snapshot.cookie)
    await AuthSessionSettings.save(context, {
      loginMode: 'cookie',
      username: snapshot.username,
      avatar,
      validatedAt: Date.now()
    })
    AutoDailyCheckinService.tryCheckin(context, snapshot.cookie, 'two-factor-login').catch((error: Error) => {
      console.info('auto daily check-in two-factor-login trigger failed: ' + error.message)
    })
  }

  private cancel(): void {
    if (this.isSubmitting) {
      return
    }
    this.code = ''
    this.errorMessage = ''
    this.visible = false
    if (this.onCancel) {
      this.onCancel()
    }
  }
}
