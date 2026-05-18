import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AccountDetailHeaderCard,
  AccountRateLimitSummary,
  AccountSignedInCard,
  AccountTokenSummary
} from '../components/AccountDashboardComponents'
import { V2exTwoFactorPrompt } from '../components/V2exTwoFactorPrompt'
import {
  LocalContentStats,
  SavedNode,
  SavedTopic,
  towFASheetOptions,
  V2exAuthenticatedMember,
  V2exBalance,
  V2exDailyMission,
  V2exTokenInfo,
  ViewedTopic
} from 'shared'
import {
  ApiService,
  AuthSessionSettings,
  AuthSettings,
  ConciseListRow,
  CookieJarSettings,
  GroupedListSection,
  HttpClient,
  ListDivider as SharedListDivider,
  NotificationSettings,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  StorageKeys,
  ThemeConstants,
  UserProfileParams,
  V2exCookieTwoFactorRequiredError,
  V2exSessionParser,
  V2exSigninParser
} from 'shared'
import { AccountLocalContentCoordinator } from '../model/AccountLocalContentCoordinator'
import { AccountPageCoordinator } from '../model/AccountPageCoordinator'

@Component
export struct AccountDashboardPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink(StorageKeys.AUTH_TOKEN_CONFIGURED) authTokenConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) authCookieConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_USERNAME) storedUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) sessionUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_AVATAR) sessionAvatar: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_VALIDATED_AT) sessionValidatedAt: number = 0
  @StorageLink(StorageKeys.AUTH_SESSION_UPDATED_AT) @Watch('onAuthSessionUpdated') authSessionUpdatedAt: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_LIMIT) apiRateLimitLimit: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_REMAINING) apiRateLimitRemaining: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_RESET) apiRateLimitReset: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_UPDATED_AT) apiRateLimitUpdatedAt: number = 0
  @StorageLink(StorageKeys.LOCAL_DATA_UPDATED_AT) @Watch('onLocalDataUpdated') localDataUpdatedAt: number = 0
  @StorageLink(StorageKeys.LOCAL_SAVED_TOPIC_COUNT) savedTopicCount: number = 0
  @StorageLink(StorageKeys.LOCAL_SAVED_NODE_COUNT) savedNodeCount: number = 0
  @StorageLink(StorageKeys.LOCAL_VIEWED_TOPIC_COUNT) viewedTopicCount: number = 0
  @State private authToken: string = ''
  @State private authProfile: V2exAuthenticatedMember | null = null
  @State private tokenInfo: V2exTokenInfo | null = null
  @State private tokenInfoError: string = ''
  @State private authError: string = ''
  @State private sessionError: string = ''
  @State private isSessionValidating: boolean = false
  @State private isAuthLoading: boolean = false
  @State private savedTopics: SavedTopic[] = []
  @State private savedNodes: SavedNode[] = []
  @State private viewedTopics: ViewedTopic[] = []
  @State private accountBalance: V2exBalance | null = null
  @State private dailyMission: V2exDailyMission | null = null
  @State private accountMetaError: string = ''
  @State private isAccountMetaLoading: boolean = false
  @State private isDailyRedeeming: boolean = false
  @State private twoFactorVisible: boolean = false
  @State private twoFactorCookie: string = ''
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()
  private localStatsRequestId: number = 0
  showDetail: boolean = false
  @Prop @Watch('onRefreshKeyChanged') refreshKey: number = 0

  aboutToAppear(): void {
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
    this.refreshLocalData()
  }

  onLocalDataUpdated(_propName: string): void {
    this.refreshLocalData()
  }

  onRefreshKeyChanged(_propName: string): void {
    this.refreshLocalData()
  }

  onAuthSessionUpdated(_propName: string): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.accountBalance = null
      this.dailyMission = null
      this.accountMetaError = ''
      return
    }
    this.sessionError = ''
    this.loadAccountMeta(true)
  }

  build() {
    if (this.showDetail) {
      this.AccountDetailPage()
    } else {
      Column() {
        SecondaryListScaffold({
          bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + ThemeConstants.SPACE_MD
        }) {
          ListItem() {
            this.SectionHeader(AccountPageCoordinator.SECTION_ACCOUNT)
          }

          ListItem() {
            this.AuthSection()
          }

          if (this.hasCookieAccount()) {
            ListItem() {
              this.SectionHeader(AccountPageCoordinator.SECTION_ACCOUNT_CONTENT)
            }
            .margin({ top: ThemeConstants.SPACE_MD })

            ListItem() {
              this.AccountContentSection()
            }
          }

          ListItem() {
            this.SectionHeader(AccountPageCoordinator.SECTION_LOCAL_CONTENT)
          }
          .margin({ top: ThemeConstants.SPACE_MD })

          ListItem() {
            this.LocalContentSection()
          }

          ListItem() {
            this.SectionHeader(AccountPageCoordinator.SECTION_MORE)
          }
          .margin({ top: ThemeConstants.SPACE_MD })

          ListItem() {
            this.StorageSection()
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .bindSheet($$this.twoFactorVisible, this.TwoFactorSheet(), towFASheetOptions(SheetSize.MEDIUM, () => {
        this.twoFactorVisible = false
      }))
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
        if (isVisible) {
          this.refreshLocalData()
        }
      })
    }
  }

  @Builder
  AccountDetailPage() {
    Column() {
      SecondaryListScaffold({ bottomPadding: ThemeConstants.SPACE_MD }) {
        ListItem() {
          AccountDetailHeaderCard({
            avatarUrl: this.currentAvatar(),
            username: this.currentUsername(),
            balance: this.accountBalance,
            fallbackText: this.accountMetaText(),
            sessionError: this.sessionError,
            accountMetaError: this.accountMetaError,
            dailyMissionMessage: this.dailyMission ? this.dailyMission.message : ''
          })
        }

        ListItem() {
          GroupedListSection() {
            this.AuthActionRow(AccountPageCoordinator.PROFILE_TITLE, '', () => {
              const username = this.currentUsername()
              if (username) {
                let p: UserProfileParams = { username: username }
                this.ns.pushPathByName('UserProfile', p as Object)
              }
            })
            this.SettingsDivider()
            this.AuthActionRow(AccountPageCoordinator.BALANCE_DETAIL_TITLE, '', () => {
              this.openV2exPathInSystemBrowser('/balance')
            })
            this.SettingsDivider()
            this.AuthActionRow(AccountPageCoordinator.WEB_ACCOUNT_SETTINGS_TITLE, '', () => {
              this.openV2exPathInSystemBrowser('/settings')
            })
          }
        }

        ListItem() {
          GroupedListSection() {
            ConciseListRow({
              title: AccountPageCoordinator.LOGOUT_TITLE,
              showChevron: false,
              primaryColor: Color.Red,
              action: () => {
                this.logoutAll()
                this.ns.pop()
              }
            })
          }
        }

        if (this.shouldShowApiDiagnostics()) {
          ListItem() {
            this.SectionHeader(AccountPageCoordinator.SECTION_ADVANCED_API)
          }
          .margin({ top: ThemeConstants.SPACE_MD })

          ListItem() {
            this.ApiDiagnosticsSection()
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .bindSheet($$this.twoFactorVisible, this.TwoFactorSheet(), towFASheetOptions(SheetSize.MEDIUM, () => {
      this.twoFactorVisible = false
    }))
  }

  @Builder
  TwoFactorSheet() {
    V2exTwoFactorPrompt({
      visible: $twoFactorVisible,
      cookie: this.twoFactorCookie,
      message: AccountPageCoordinator.TWO_FACTOR_MESSAGE,
      onSuccess: () => {
        this.sessionError = ''
        this.accountMetaError = ''
        this.validateCookieSession(true)
        this.loadAccountMeta(true)
      }
    })
  }

  @Builder
  SectionHeader(title: string) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  @Builder
  AuthActionRow(title: string, subtitle: string, action: () => void) {
    ConciseListRow({ title: title, subtitle: subtitle, action: action })
  }

  @Builder
  AuthSection() {
    Column() {
      if (!this.hasAnyAccount()) {
        this.AuthActionRow(AccountPageCoordinator.LOGIN_TITLE, AccountPageCoordinator.LOGIN_SUBTITLE, () => {
          this.ns.pushPathByName('V2exNativeLogin', null)
        })
      } else {
        AccountSignedInCard({
          avatarUrl: this.currentAvatar(),
          username: this.currentUsername(),
          balance: this.accountBalance,
          fallbackText: this.accountMetaText(),
          dailyMissionText: this.dailyMissionButtonText(),
          dailyMissionEnabled: this.dailyMissionEnabled(),
          redeemDailyMission: () => {
            this.redeemDailyMission()
          },
          openDetail: () => {
            this.ns.pushPathByName('Account', null)
          }
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .padding(4)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder
  StatusText(message: string, isError: boolean) {
    Text(message)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(isError ? Color.Red : $r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
  }

  @Builder
  AccountContentSection() {
    GroupedListSection() {
      this.AuthActionRow(AccountPageCoordinator.ACCOUNT_SAVED_TOPICS_TITLE, '', () => {
        this.ns.pushPathByName('MyTopics', null)
      })
      this.SettingsDivider()
      this.AuthActionRow(AccountPageCoordinator.ACCOUNT_SAVED_NODES_TITLE, '', () => {
        this.ns.pushPathByName('MyNodes', null)
      })
      this.SettingsDivider()
      this.AuthActionRow(AccountPageCoordinator.ACCOUNT_FOLLOWING_TITLE, '', () => {
        this.ns.pushPathByName('AccountFollowing', null)
      })
      this.SettingsDivider()
      this.AuthActionRow(AccountPageCoordinator.ACCOUNT_BLACKLIST_TITLE, '', () => {
        this.ns.pushPathByName('AccountBlacklist', null)
      })
    }
  }

  @Builder
  ApiDiagnosticsSection() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(AccountPageCoordinator.API_TOKEN_TITLE)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(AccountPageCoordinator.API_TOKEN_SUBTITLE)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_LG,
        right: ThemeConstants.SPACE_LG,
        top: ThemeConstants.SPACE_MD,
        bottom: ThemeConstants.SPACE_SM
      })

      if (this.tokenInfoError) {
        Text(this.tokenInfoError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
      }

      if (this.tokenInfo) {
        AccountTokenSummary({
          scope: this.tokenScope(),
          expiration: this.tokenExpiration(),
          lastUsed: this.tokenLastUsed()
        })
      }

      if (this.hasApiRateLimitSnapshot()) {
        this.SettingsDivider()
        AccountRateLimitSummary({
          limit: this.apiRateLimitLimit,
          remaining: this.apiRateLimitRemaining,
          resetAt: this.apiRateLimitReset,
          updatedAt: this.apiRateLimitUpdatedAt
        })
      }

      this.SettingsDivider()
      Row() {
        Text(AccountPageCoordinator.CLEAR_API_AUTH_TITLE)
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.Red)
          .layoutWeight(1)
        Text('›')
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
      .onClick(() => {
        this.confirmClearAuth()
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .clip(true)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder
  LocalContentSection() {
    GroupedListSection() {
      this.SearchEntryRow()
      this.SettingsDivider()
      this.TopicDraftEntryRow()
      this.SettingsDivider()
      ConciseListRow({
        title: AccountPageCoordinator.LOCAL_READ_LATER_TITLE,
        count: this.savedTopicCount,
        action: () => {
          this.ns.pushPathByName('SavedTopics', null)
        }
      })
      this.SettingsDivider()
      ConciseListRow({
        title: AccountPageCoordinator.LOCAL_VIEWED_TOPICS_TITLE,
        count: this.viewedTopicCount,
        action: () => {
          this.ns.pushPathByName('ViewedTopics', null)
        }
      })
      this.SettingsDivider()
      ConciseListRow({
        title: AccountPageCoordinator.LOCAL_SAVED_NODES_TITLE,
        count: this.savedNodeCount,
        action: () => {
          this.ns.pushPathByName('SavedNodes', null)
        }
      })
    }
  }

  @Builder
  SearchEntryRow() {
    ConciseListRow({
      title: AccountPageCoordinator.LOCAL_SEARCH_TITLE, action: () => {
        this.ns.pushPathByName('Search', null)
      }
    })
  }

  @Builder
  TopicDraftEntryRow() {
    ConciseListRow({
      title: AccountPageCoordinator.LOCAL_TOPIC_DRAFT_TITLE, action: () => {
        this.ns.pushPathByName('TopicEditor', null)
      }
    })
  }

  @Builder
  StorageSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AccountPageCoordinator.ABOUT_TITLE,
        action: () => {
          this.ns.pushPathByName('About', null)
        }
      })
    }
  }

  private hasCookieAccount(): boolean {
    return AccountPageCoordinator.hasCookieAccount(this.authCookieConfigured)
  }

  private hasAnyAccount(): boolean {
    return AccountPageCoordinator.hasAnyAccount(this.authCookieConfigured, this.authTokenConfigured)
  }

  private shouldShowApiDiagnostics(): boolean {
    return AccountPageCoordinator.shouldShowApiDiagnostics(this.authTokenConfigured)
  }

  private currentUsername(): string {
    return AccountPageCoordinator.identity(
      this.sessionUsername,
      this.sessionAvatar,
      this.authProfile,
      this.storedUsername
    ).username
  }

  private currentAvatar(): string {
    return AccountPageCoordinator.identity(
      this.sessionUsername,
      this.sessionAvatar,
      this.authProfile,
      this.storedUsername
    ).avatarUrl
  }

  private accountMetaText(): string {
    return AccountPageCoordinator.accountMetaText(
      this.hasCookieAccount(),
      this.authTokenConfigured,
      this.accountBalance,
      this.isAccountMetaLoading,
      this.accountMetaError
    )
  }

  private dailyMissionButtonText(): string {
    return AccountPageCoordinator.dailyMissionButtonText(this.isDailyRedeeming, this.dailyMission)
  }

  private dailyMissionEnabled(): boolean {
    return AccountPageCoordinator.dailyMissionEnabled(
      this.hasCookieAccount(),
      this.isAccountMetaLoading,
      this.isDailyRedeeming,
      this.dailyMission
    )
  }

  private profileTagline(): string {
    return AccountPageCoordinator.profileTagline(this.authProfile)
  }

  private profileLocation(): string {
    return AccountPageCoordinator.profileLocation(this.authProfile)
  }

  private profileCreatedAt(): number {
    return AccountPageCoordinator.profileCreatedAt(this.authProfile)
  }

  private tokenScope(): string {
    return AccountPageCoordinator.tokenScope(this.tokenInfo)
  }

  private tokenExpiration(): number {
    return AccountPageCoordinator.tokenExpiration(this.tokenInfo)
  }

  private tokenLastUsed(): number {
    return AccountPageCoordinator.tokenLastUsed(this.tokenInfo)
  }

  private hasApiRateLimitSnapshot(): boolean {
    return AccountPageCoordinator.hasApiRateLimitSnapshot(
      this.apiRateLimitLimit,
      this.apiRateLimitUpdatedAt,
      this.apiRateLimitReset
    )
  }

  private loadAuthSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.storedUsername = snapshot.username
        if (snapshot.token) {
          this.refreshAuthProfile(snapshot.token)
          this.refreshTokenInfo(snapshot.token)
        }
      })
      .catch((error: Error) => {
        this.authError = error.message
      })
  }

  private loadSessionSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.load(context)
      .then(() => {
        this.validateCookieSession()
        this.loadAccountMeta()
      })
      .catch((error: Error) => {
        console.error('restore cookie jar failed: ' + error.message)
      })
    AuthSessionSettings.load(context)
      .catch((error: Error) => {
        console.error('restore auth session failed: ' + error.message)
      })
  }

  private validateCookieSession(force: boolean = false): void {
    if (this.isSessionValidating) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      return
    }
    const now = Date.now()
    if (!force && this.sessionValidatedAt > 0 && now - this.sessionValidatedAt < 10 * 60 * 1000) {
      return
    }
    this.isSessionValidating = true
    this.sessionError = ''
    const headers: Record<string, string> = { 'Cookie': cookie }
    this.http.getTextResponseWithHeaders('/settings', headers)
      .then((res) => {
        if (res.location.indexOf('/2fa') >= 0 || V2exSigninParser.extractTwoFactorForm(res.text)) {
          throw new V2exCookieTwoFactorRequiredError('/settings')
        }
        const username = V2exSessionParser.extractUsername(res.text)
        if (!username) {
          throw new Error('Web 会话已失效，请重新登录')
        }
        return this.api.getMember(username)
          .then((profile) => {
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext
            return AuthSessionSettings.save(context, {
              loginMode: 'cookie',
              username: username,
              avatar: profile.avatar_normal || '',
              validatedAt: Date.now()
            })
              .then(() => {
                this.loadAccountMeta(true)
              })
          })
      })
      .catch((error: Error) => {
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        const message = error.message || 'Web 会话验证失败'
        this.sessionError = message
        this.handleExpiredCookieSession(message)
      })
      .finally(() => {
        this.isSessionValidating = false
      })
  }

  private handleExpiredCookieSession(message: string): void {
    if (!message || message.indexOf('会话已失效') < 0) {
      return
    }
    this.sessionError = message
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.clearForBaseUrl(context, HttpClient.getInstance().getBaseUrl())
      .then(() => AuthSessionSettings.clear(context))
      .catch((_error: Error) => {
      })
      .finally(() => {
        this.accountBalance = null
        this.dailyMission = null
      })
  }

  private openTwoFactorFromCookie(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.sessionError = 'V2EX 需要完成两步验证，请重新登录'
      return
    }
    this.sessionError = 'V2EX 需要完成两步验证'
    this.accountMetaError = 'V2EX 需要完成两步验证'
    this.twoFactorCookie = cookie
    this.twoFactorVisible = true
  }

  private refreshAuthProfile(token: string): void {
    this.api.getAuthenticatedMember(token)
      .then((profile: V2exAuthenticatedMember) => {
        this.authProfile = profile
        this.storedUsername = profile.username || this.storedUsername
      })
      .catch((error: Error) => {
        this.authError = error.message || '登录状态验证失败'
      })
  }

  private refreshTokenInfo(token: string): void {
    this.tokenInfoError = ''
    this.api.getTokenInfo(token)
      .then((info: V2exTokenInfo) => {
        if (info && info.success === false) {
          this.tokenInfo = null
          this.tokenInfoError = info.message || 'Token 信息获取失败'
          return
        }
        this.tokenInfo = info
        this.tokenInfoError = ''
      })
      .catch((error: Error) => {
        this.tokenInfo = null
        this.tokenInfoError = error.message || 'Token 信息获取失败'
      })
  }

  private confirmClearAuth(): void {
    if (!this.authTokenConfigured || this.isAuthLoading) {
      return
    }
    AlertDialog.show({
      title: AccountPageCoordinator.CLEAR_API_AUTH_TITLE,
      message: AccountPageCoordinator.CLEAR_API_AUTH_MESSAGE,
      primaryButton: {
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '清除',
        fontColor: Color.Red,
        action: () => {
          this.clearAuth()
        }
      }
    })
  }

  private clearAuth(): void {
    const keepCookieAccount = this.hasCookieAccount()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.clear(context)
      .then(() => NotificationSettings.clearCache(context).catch((_error: Error) => {
      }))
      .then(() => {
        this.authToken = ''
        this.authProfile = null
        this.tokenInfo = null
        this.tokenInfoError = ''
        this.authError = ''
        if (!keepCookieAccount) {
          this.accountBalance = null
          this.dailyMission = null
          this.accountMetaError = ''
        } else {
          this.loadAccountMeta(true)
        }
      })
      .catch((error: Error) => {
        this.authError = error.message
      })
  }

  private logoutAll(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.isAuthLoading = false
    this.isSessionValidating = false
    this.authError = ''
    this.sessionError = ''
    Promise.all([
      AuthSettings.clear(context).catch((error: Error) => {
        this.authError = error.message || '清除 Token 失败'
      }),
      AuthSessionSettings.clear(context).catch((error: Error) => {
        this.sessionError = error.message || '清除会话失败'
      }),
      CookieJarSettings.clear(context).catch((error: Error) => {
        this.sessionError = error.message || '清除 Cookie 失败'
      }),
      NotificationSettings.clearCache(context).catch((_error: Error) => {
      })
    ])
      .finally(() => {
        this.authToken = ''
        this.authProfile = null
        this.tokenInfo = null
        this.tokenInfoError = ''
        this.accountBalance = null
        this.dailyMission = null
        this.accountMetaError = ''
      })
  }

  private loadAccountMeta(force: boolean = false): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isAccountMetaLoading) {
      return
    }
    if (!force && this.accountBalance && this.dailyMission) {
      return
    }
    this.isAccountMetaLoading = true
    this.accountMetaError = ''
    Promise.all([
      this.api.getBalanceWithCookie(cookie),
      this.api.getDailyMissionWithCookie(cookie)
    ])
      .then((results) => {
        this.accountBalance = results[0]
        this.dailyMission = results[1]
      })
      .catch((error: Error) => {
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        const message = error.message || '读取账号信息失败'
        this.accountMetaError = message
        this.handleExpiredCookieSession(message)
      })
      .finally(() => {
        this.isAccountMetaLoading = false
      })
  }

  private redeemDailyMission(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isDailyRedeeming) {
      return
    }
    if (!this.dailyMission || !this.dailyMission.canRedeem || !this.dailyMission.redeemPath) {
      promptAction.openToast({ message: '今日已签到' }).catch((_error: Error) => {
      })
      return
    }
    this.isDailyRedeeming = true
    this.accountMetaError = ''
    this.api.redeemDailyMissionWithCookie(cookie, this.dailyMission.redeemPath)
      .then((mission: V2exDailyMission) => {
        this.dailyMission = mission
        promptAction.openToast({ message: mission.message || '签到完成' }).catch((_error: Error) => {
        })
        this.loadAccountMeta(true)
      })
      .catch((error: Error) => {
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        const message = error.message || '签到失败'
        this.accountMetaError = message
        this.handleExpiredCookieSession(message)
        promptAction.openToast({ message: message }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isDailyRedeeming = false
      })
  }

  private loadSavedTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountLocalContentCoordinator.loadSavedTopics(context)
      .then((result) => {
        this.savedTopics = result.items
        this.savedTopicCount = result.count
      })
      .catch((error: Error) => {
        console.error('load saved topics failed: ' + error.message)
      })
  }

  private loadSavedNodes(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountLocalContentCoordinator.loadSavedNodes(context)
      .then((result) => {
        this.savedNodes = result.items
        this.savedNodeCount = result.count
      })
      .catch((error: Error) => {
        console.error('load saved nodes failed: ' + error.message)
      })
  }

  private loadViewedTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountLocalContentCoordinator.loadViewedTopics(context)
      .then((result) => {
        this.viewedTopics = result.items
        this.viewedTopicCount = result.count
      })
      .catch((error: Error) => {
        console.error('load viewed topics failed: ' + error.message)
      })
  }

  private loadTopicReadStates(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountLocalContentCoordinator.syncTopicReadStates(context)
      .catch((error: Error) => {
        console.error('sync topic read states failed: ' + error.message)
      })
  }

  private refreshLocalData(): void {
    this.loadLocalContentStats()
    this.loadSavedTopics()
    this.loadSavedNodes()
    this.loadViewedTopics()
    this.loadTopicReadStates()
  }

  private loadLocalContentStats(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const requestId = ++this.localStatsRequestId
    AccountLocalContentCoordinator.loadLocalContentStats(context)
      .then((stats: LocalContentStats) => {
        if (requestId !== this.localStatsRequestId) {
          return
        }
        this.savedTopicCount = stats.savedTopicCount
        this.savedNodeCount = stats.savedNodeCount
        this.viewedTopicCount = stats.viewedTopicCount
      })
      .catch((error: Error) => {
        console.error('load local content stats failed: ' + error.message)
      })
  }

  private openV2exPathInSystemBrowser(path: string): void {
    const baseUrl = this.http.getBaseUrl()
    const cleanPath = (path || '').trim()
    if (!baseUrl || !cleanPath) {
      return
    }
    const url = cleanPath.startsWith('/') ? `${baseUrl}${cleanPath}` : `${baseUrl}/${cleanPath}`
    this.openInSystemBrowser(url)
  }

  private openInSystemBrowser(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: target }
    context.startAbility(want)
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => {
        })
      })
  }
}
