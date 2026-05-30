import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AccountSessionCoordinator,
  ApiService,
  AppActionButton,
  AppModalScaffold,
  AppStrings,
  AppTextField,
  AuthSessionSettings,
  AutoDailyCheckinService,
  CookieJarSettings,
  HttpClient,
  NativeTwoFactorRequiredError,
  ThemeConstants,
  V2exNativeAuthService,
  translateApiError
} from 'shared'
import type { NativeLoginSnapshot } from 'shared'

@Component
export struct V2exTwoFactorPrompt {
  @Link visible: boolean
  @Prop cookie: string = ''
  @Prop title: string = AppStrings.text(AppStrings.R_TWO_FACTOR_TITLE, 'Two-Factor Verification')
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
          Text(AppStrings.text(AppStrings.R_TWO_FACTOR_DESCRIPTION, 'V2EX requires two-factor verification to continue accessing account content.'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')

          AppTextField({
            text: this.code,
            placeholder: AppStrings.text(AppStrings.R_TWO_FACTOR_CODE_PLACEHOLDER, 'Enter 6-digit code'),
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
            label: this.isSubmitting ? AppStrings.text(AppStrings.R_TWO_FACTOR_VERIFYING, 'Verifying\u2026') : AppStrings.text(AppStrings.R_TWO_FACTOR_VERIFY_BUTTON, 'Verify'),
            primary: true,
            isEnabled: !this.isSubmitting,
            action: () => { this.submit() }
          })

          AppActionButton({
            label: AppStrings.text(AppStrings.R_TWO_FACTOR_LATER, 'Later'),
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
      this.errorMessage = AppStrings.text($r('app.string.api_error_login_session_missing'), 'Missing login session, please sign in again')
      return
    }
    if (!cleanCode) {
      this.errorMessage = AppStrings.text($r('app.string.api_error_two_factor_code_required'), 'Please enter the two-factor code')
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
        promptAction.openToast({ message: $r('app.string.two_factor_completed') }).catch((_error: Error) => { })
        if (this.onSuccess) {
          this.onSuccess()
        }
      })
      .catch((error: Error) => {
        this.code = ''
        if (error instanceof NativeTwoFactorRequiredError) {
          this.errorMessage = error.message || AppStrings.text($r('app.string.api_error_two_factor_failed'), 'Two-factor failed')
          return
        }
        this.errorMessage = translateApiError(error)
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
    await AccountSessionCoordinator.registerCurrentSession(context, snapshot.username, avatar, 'cookie')
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
