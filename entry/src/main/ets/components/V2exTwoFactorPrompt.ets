import { AppPrompt } from 'shared'
import { common } from '@kit.AbilityKit'
import {
  AccountSessionCoordinator,
  ApiService,
  ApiErrors,
  AppActionButton,
  AppModalScaffold,
  AppStrings,
  AppTextField,
  AuthSessionSettings,
  AutoDailyCheckinService,
  CookieJarSettings,
  connectLanguageState,
  HttpClient,
  LanguageState,
  NativeTwoFactorRequiredError,
  ThemeConstants,
  TwoFactorChallengeService,
  TwoFactorTrace,
  V2exNativeAuthService,
  translateApiError
} from 'shared'
import type { NativeLoginSnapshot } from 'shared'

@ComponentV2
export struct V2exTwoFactorPrompt {
  // `visible` is a one-way @Param mirroring the host's two-way sheet binding; the prompt closes itself
  // by reporting `onVisibleChange(false)` (the V2 replacement for the former two-way `@Link visible`).
  @Param visible: boolean = false
  @Event onVisibleChange?: (value: boolean) => void
  @Param cookie: string = ''
  @Param title: ResourceStr = $r('app.string.two_factor_title')
  @Event onSuccess?: () => void
  @Event onCancel?: () => void
  private language: LanguageState = connectLanguageState()

  @Local private code: string = ''
  @Local private errorMessage: string = ''
  @Local private isSubmitting: boolean = false

  private auth: V2exNativeAuthService = new V2exNativeAuthService()
  private api: ApiService = new ApiService()
  private http: HttpClient = HttpClient.getInstance()

  build() {
    AppModalScaffold({
      title: this.localeAwareResource(this.title),
      closeAction: () => { this.cancel() }
    }) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Text(this.localeAwareText($r('app.string.two_factor_description'), 'V2EX requires two-factor verification to continue accessing account content.'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')

          AppTextField({
            text: this.code,
            placeholder: this.localeAwareText($r('app.string.two_factor_code_placeholder'), 'Enter 6-digit code'),
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
            label: this.isSubmitting ? this.localeAwareText($r('app.string.two_factor_verifying'), 'Verifying\u2026') : this.localeAwareText($r('app.string.two_factor_verify_button'), 'Verify'),
            primary: true,
            isEnabled: !this.isSubmitting,
            action: () => { this.submit() }
          })

          AppActionButton({
            label: this.localeAwareText($r('app.string.two_factor_later'), 'Later'),
            primary: false,
            isEnabled: !this.isSubmitting,
            action: () => { this.cancel() }
          })
        }
        .width('100%')
      }
    }
  }

  private localeAwareResource(resource: ResourceStr): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return resource
    }
    return resource
  }

  private localeAwareText(resource: Resource, fallback: string): string {
    if (this.language.effectiveLocale.length >= 0) {
      return AppStrings.text(resource, fallback)
    }
    return AppStrings.text(resource, fallback)
  }

  private submit(): void {
    if (this.isSubmitting) {
      return
    }
    const cleanCookie = TwoFactorChallengeService.retryCookie(this.cookie).trim()
    const cleanCode = this.normalizeTwoFactorCode(this.code)
    if (this.code !== cleanCode) {
      this.code = cleanCode
    }
    if (!cleanCookie) {
      this.errorMessage = AppStrings.text($r('app.string.api_error_login_session_missing'), 'Missing login session, please sign in again')
      return
    }
    if (!cleanCode || cleanCode.length !== 6) {
      this.errorMessage = AppStrings.text($r('app.string.api_error_two_factor_code_required'), 'Please enter the two-factor code')
      return
    }

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()
    const activeCookieAtStart = CookieJarSettings.getCookieForBaseUrl(baseUrl)
    const trace = TwoFactorChallengeService.currentTrace()
    if (!trace || !TwoFactorChallengeService.matchesContext(trace)) {
      trace?.record('attempt_rejected_stale_session', {}, true)
      this.errorMessage = translateApiError(ApiErrors.loginStateUnconfirmed())
      return
    }
    trace.attempt += 1
    trace.stage = 'input'
    trace.record('attempt_started')
    this.isSubmitting = true
    this.errorMessage = ''

    this.auth.completeTwoFactorWithCookie(cleanCookie, cleanCode, trace)
      .then((snapshot: NativeLoginSnapshot) => this.persistSnapshot(context, baseUrl, snapshot, trace, activeCookieAtStart))
      .then(() => {
        this.code = ''
        this.errorMessage = ''
        this.onVisibleChange?.(false)
        AppPrompt.openToast({ message: $r('app.string.two_factor_completed') }).catch((_error: Error) => { })
        if (this.onSuccess) {
          this.onSuccess()
        }
      })
      .catch((error: Error) => {
        this.code = ''
        trace.record('attempt_failed', { retryableChallenge: error instanceof NativeTwoFactorRequiredError }, true)
        const retryCookie = error instanceof NativeTwoFactorRequiredError ?
          error.challenge.cookie : this.auth.getTwoFactorRetryCookie()
        TwoFactorChallengeService.updateRetry(trace, retryCookie)
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

  private normalizeTwoFactorCode(value: string): string {
    const raw = value || ''
    let result = ''
    for (let i = 0; i < raw.length; i += 1) {
      const ch = raw.charAt(i)
      const codeUnit = raw.charCodeAt(i)
      if (codeUnit >= 48 && codeUnit <= 57) {
        result += ch
      } else if (codeUnit >= 65296 && codeUnit <= 65305) {
        result += String.fromCharCode(codeUnit - 65248)
      }
    }
    return result
  }

  private async persistSnapshot(
    context: common.UIAbilityContext,
    baseUrl: string,
    snapshot: NativeLoginSnapshot,
    trace: TwoFactorTrace,
    activeCookieAtStart: string
  ): Promise<void> {
    trace.stage = 'persist'
    trace.record('persist_started')
    let avatar = ''
    try {
      const profile = await this.api.getMember(snapshot.username)
      avatar = profile.avatar_normal || profile.avatar_large || profile.avatar_mini || ''
    } catch (_error) {
      avatar = ''
    }
    // A completed request from a dismissed flow must not replace a newly selected account.
    if (!TwoFactorChallengeService.matchesContext(trace) || this.http.getBaseUrl() !== baseUrl ||
      CookieJarSettings.getCookieForBaseUrl(baseUrl) !== activeCookieAtStart) {
      trace.record('persist_rejected_stale_session', {}, true)
      throw ApiErrors.loginStateUnconfirmed()
    }
    try {
      await CookieJarSettings.saveForBaseUrl(context, baseUrl, snapshot.cookie)
    } finally {
      TwoFactorChallengeService.acceptPersistedSession(trace, snapshot.cookie)
    }
    await AuthSessionSettings.save(context, {
      loginMode: 'cookie',
      username: snapshot.username,
      avatar,
      validatedAt: Date.now()
    })
    await AccountSessionCoordinator.registerCurrentSession(context, snapshot.username, avatar, 'cookie')
    trace.record('persist_completed')
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
    this.onVisibleChange?.(false)
    if (this.onCancel) {
      this.onCancel()
    }
  }
}
