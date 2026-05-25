import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AppStrings,
  AppTextField,
  AuthSessionSettings,
  AccountSessionCoordinator,
  AutoDailyCheckinService,
  AppActionButton,
  ConciseListRow,
  CookieJarSettings,
  GroupedListSection,
  HttpClient,
  NativeTwoFactorRequiredError,
  SecondaryListScaffold,
  ThemeConstants,
  TwoFactorChallengeService,
  V2exNativeAuthService,
  translateApiError,
} from 'shared'
import type { NativeLoginChallenge, NativeLoginSnapshot } from 'shared'
@Component
export struct V2exNativeLoginPage {
  @Consume('ns') stack: NavPathStack;

  @State private username: string = '';
  @State private password: string = '';
  @State private captchaCode: string = '';
  @State private captchaField: string = '';
  @State private captchaUrl: string = '';
  @State private errorMessage: string = '';
  @State private isLoading: boolean = false;
  @State private isChallengeLoading: boolean = false;

  private challenge: NativeLoginChallenge | null = null;
  private auth: V2exNativeAuthService = new V2exNativeAuthService();
  private api: ApiService = new ApiService();
  private http: HttpClient = HttpClient.getInstance();
  private isPageActive: boolean = false;
  private challengeRequestId: number = 0;
  private authRequestId: number = 0;

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
        title: AppStrings.text(AppStrings.R_NAV_WEB_LOGIN, 'Web Login'),
        showChevron: true,
        action: () => {
          this.clearSecretState()
          this.stack.pushPathByName('V2exWebLogin', null)
        },
      })
    }
  }

  @Builder CaptchaImageSlot() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.captchaUrl) {
        Image(this.captchaUrl).width('100%').height('100%').objectFit(ImageFit.Contain)
      } else if (this.isChallengeLoading) {
        LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
      }
    }
    .width('100%')
    // V2EX sign-in captcha is rendered at 320x80.
    .aspectRatio(4)
    .backgroundColor(this.captchaUrl ? Color.White : $r('sys.color.ohos_id_color_button_normal'))
    .borderRadius(ThemeConstants.RADIUS_MD)
    .clip(true)
    .onClick(() => {
      if (!this.isChallengeLoading) {
        this.loadChallenge()
      }
    })
  }

  @Builder LoginForm() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      AppTextField({
        text: $username,
        placeholder: $r('app.string.username_or_email_placeholder'),
        onTextChange: (value: string) => {
          this.username = value
        },
      }).width('100%')
      AppTextField({
        text: $password,
        placeholder: AppStrings.text(AppStrings.R_LOGIN_PASSWORD_PLACEHOLDER, 'Password'),
        inputType: InputType.Password,
        onTextChange: (value: string) => {
          this.password = value
        },
      }).width('100%')

      if (this.shouldShowCaptchaSection()) {
        Column({ space: ThemeConstants.SPACE_SM }) {
          this.CaptchaImageSlot()
          AppTextField({
            text: $captchaCode,
            placeholder: AppStrings.text(AppStrings.R_LOGIN_CAPTCHA_PLACEHOLDER, 'Captcha'),
            onTextChange: (value: string) => {
              this.captchaCode = value
            },
          }).width('100%')
        }.width('100%')
      }

      if (this.errorMessage) {
        Text(this.errorMessage).fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor(Color.Red)
      }
      AppActionButton({
        label: this.loginButtonText(),
        primary: true,
        isEnabled: !this.isLoading && !this.isChallengeLoading,
        action: () => {
          this.login()
        },
      })
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private loginButtonText(): string {
    if (this.isChallengeLoading) {
      return AppStrings.text(AppStrings.R_LOGIN_BUTTON_PREPARING, 'Preparing\u2026')
    }
    if (this.isLoading) {
      return AppStrings.text(AppStrings.R_LOGIN_BUTTON_LOGGING_IN, 'Signing in\u2026')
    }
    return AppStrings.text(AppStrings.R_LOGIN_BUTTON_LABEL, 'Sign in')
  }

  private loadChallenge(message: string = ''): void {
    const requestId = ++this.challengeRequestId
    this.isChallengeLoading = true
    this.errorMessage = message
    this.captchaCode = ''
    this.challenge = null
    this.auth
      .prepareLogin()
      .then((challenge: NativeLoginChallenge) => {
        if (!this.isPageActive || requestId !== this.challengeRequestId) {
          return ''
        }
        this.challenge = challenge
        this.captchaField = challenge.captchaField
        if (!challenge.captchaUrl) {
          this.captchaUrl = ''
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
        this.errorMessage = translateApiError(error)
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
    this.loadChallenge(
      AppStrings.text(
        $r('app.string.login_form_refetched'),
        'Login form refreshed. Please enter your password again.',
      ),
    )
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
      this.errorMessage = AppStrings.text(
        $r('app.string.login_username_password_required'),
        'Enter username and password',
      )
      return
    }
    if (!this.challenge) {
      this.errorMessage = AppStrings.text(
        AppStrings.R_LOGIN_FORM_NOT_LOADED,
        'Login form not loaded, please try again',
      )
      return
    }
    if (this.captchaUrl && !this.captchaField) {
      this.errorMessage = AppStrings.text(
        AppStrings.R_LOGIN_CAPTCHA_FORM_NOT_LOADED,
        'Captcha form not loaded, please refresh',
      )
      return
    }
    const requestId = ++this.authRequestId
    const challenge = this.challenge
    const captchaCode = this.captchaCode
    this.isLoading = true
    this.errorMessage = ''

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const baseUrl = this.http.getBaseUrl()

    this.auth
      .loginWithChallenge(challenge, cleanUsername, pwd, captchaCode)
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
          this.password = ''
          TwoFactorChallengeService.request(error.challenge.cookie, 'nativeLogin')
          this.errorMessage = AppStrings.text(
            AppStrings.R_TWO_FACTOR_REQUIRED,
            'V2EX requires two-factor verification',
          )
          return Promise.resolve()
        }
        this.errorMessage = translateApiError(error)
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
    requestId: number,
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
        validatedAt: Date.now(),
      })
      await AccountSessionCoordinator.registerCurrentSession(
        context,
        snapshot.username,
        avatar,
        'cookie',
      )
      AutoDailyCheckinService.tryCheckin(context, snapshot.cookie, 'native-login').catch(
        (error: Error) => {
          console.info('auto daily check-in native-login trigger failed: ' + error.message)
        },
      )
    } catch (error) {
      await this.clearPersistedLogin(context)
      const caught = error as Error
      throw caught
    }

    if (!this.isCurrentAuthRequest(requestId)) {
      return
    }
    this.password = ''
    promptAction.openToast({ message: $r('app.string.login_success') }).catch((error: Error) => {
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
    const restored = await AccountSessionCoordinator.restoreActiveAccount(context).catch(
      (_error: Error) => null,
    )
    if (restored) {
      console.info(
        'V2exNativeLoginPage: restored previous active account after login persist failure',
      )
      return
    }
    await Promise.all([
      CookieJarSettings.clearForBaseUrl(context, this.http.getBaseUrl()).catch(
        (clearError: Error) => {
          console.error('clear cookie after login persist failure: ' + clearError.message)
        },
      ),
      AuthSessionSettings.clear(context).catch((clearError: Error) => {
        console.error('clear auth session after login persist failure: ' + clearError.message)
      }),
    ])
  }

  private shouldShowCaptchaSection(): boolean {
    return this.isChallengeLoading || !!this.captchaField || !!this.captchaUrl
  }

  private shouldShowCaptchaField(): boolean {
    return !!this.captchaField || !!this.captchaUrl
  }
}
