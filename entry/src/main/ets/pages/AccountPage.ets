import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AccountRateLimitSummary,
  AccountSignedInCard,
  AccountTokenSummary
} from '../components/AccountDashboardComponents'
import {
  AppStrings,
  LocalContentStats,
  V2exAuthenticatedMember,
  V2exBalance,
  V2exDailyMission,
  V2exTokenInfo,
  translateApiError,
  ApiError,
  ApiErrorCode,
  ApiErrors,
  isApiError
} from 'shared'
import {
  AccountStore,
} from 'shared'
import type { AccountRecord } from 'shared'
import {
  ActiveAccountState,
  ApiService,
  ApiRateLimitState,
  AccountMetaSettings,
  AuthCookieState,
  AuthIdentityState,
  AuthSessionSignalState,
  AuthSessionSettings,
  AuthSettings,
  connectActiveAccount,
  connectApiRateLimit,
  connectAuthCookie,
  connectAuthIdentity,
  connectAuthSessionSignal,
  connectLocalDataSignal,
  connectNavStack,
  ConciseListRow,
  CookieJarSettings,
  DiagnosticLogger,
  GroupedListSection,
  HttpClient,
  ListDivider as SharedListDivider,
  LocalDataPublisher,
  LocalDataSignalState,
  NotificationSettings,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  StorageKeys,
  ThemeConstants,
  TwoFactorChallengeService,
  UserProfileParams,
  V2exCookieTwoFactorRequiredError,
  V2exSessionParser,
  V2exSigninParser
} from 'shared'
import { AccountLocalContentCoordinator } from '../model/AccountLocalContentCoordinator'
import { AccountPageCoordinator } from '../model/AccountPageCoordinator'

@ComponentV2
export struct AccountDashboardPage {
  // ns from NavStackHolder (was @Consume('ns')).
  private ns: NavPathStack = connectNavStack().stack
  // Auth/session/active-account/rate-limit/local-data read from their V2 mirrors (each dual-written at
  // its service chokepoint) — replaces the AUTH_* / ACTIVE_ACCOUNT_ID / API_RATE_LIMIT_* / LOCAL_DATA_*
  // @StorageLink. The @Monitor methods below replace the former @Watch reactions.
  private authIdentity: AuthIdentityState = connectAuthIdentity()
  private authCookie: AuthCookieState = connectAuthCookie()
  private session: AuthSessionSignalState = connectAuthSessionSignal()
  private activeAccount: ActiveAccountState = connectActiveAccount()
  private rateLimit: ApiRateLimitState = connectApiRateLimit()
  private localData: LocalDataSignalState = connectLocalDataSignal()
  // storedUsername is the API-token fallback identity, page-managed; the local counts are page-computed
  // and re-published to AppStorage (LocalDataPublisher) so other readers / a cold open still see them.
  @Local private storedUsername: string = ''
  @Local private savedTopicCount: number = 0
  @Local private savedNodeCount: number = 0
  @Local private viewedTopicCount: number = 0
  @Local private authToken: string = ''
  @Local private authProfile: V2exAuthenticatedMember | null = null
  @Local private tokenInfo: V2exTokenInfo | null = null
  @Local private tokenInfoError: string = ''
  @Local private authError: string = ''
  @Local private sessionError: string = ''
  @Local private isSessionValidating: boolean = false
  @Local private isAuthLoading: boolean = false
  @Local private accountBalance: V2exBalance | null = null
  @Local private dailyMission: V2exDailyMission | null = null
  @Local private accountMetaError: string = ''
  @Local private isAccountMetaLoading: boolean = false
  @Local private isDailyRedeeming: boolean = false
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()
  private localStatsRequestId: number = 0
  private localStatsInFlight: boolean = false
  private accountListInFlight: boolean = false
  private dashboardRefreshTimerId: number = -1
  private accountMetaRequestId: number = 0
  @Local private accountsCount: number = 0
  @Local private isAccountsLoaded: boolean = false
  @Local private activeAccountUsername: string = ''
  @Local private activeAccountAvatar: string = ''
  @Param refreshKey: number = 0
  @Param scroller: Scroller = new Scroller()
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

  aboutToAppear(): void {
    this.hydrateLocalCounts()
    this.storedUsername = this.authIdentity.username
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
    this.requestDashboardRefresh('appear')
  }

  aboutToDisappear(): void {
    this.clearDashboardRefreshTimer()
  }

  // Hydrate the page-computed local counts from their AppStorage cache (kept fresh by
  // LocalDataPublisher) so they render immediately before the async refresh completes.
  private hydrateLocalCounts(): void {
    this.savedTopicCount = AppStorage.get<number>(StorageKeys.LOCAL_SAVED_TOPIC_COUNT) ?? 0
    this.savedNodeCount = AppStorage.get<number>(StorageKeys.LOCAL_SAVED_NODE_COUNT) ?? 0
    this.viewedTopicCount = AppStorage.get<number>(StorageKeys.LOCAL_VIEWED_TOPIC_COUNT) ?? 0
  }

  @Monitor('localData.updatedAt')
  onLocalDataUpdated(): void {
    this.requestDashboardRefresh('local_data_updated')
  }

  @Monitor('refreshKey')
  onRefreshKeyChanged(): void {
    this.requestDashboardRefresh('refresh_key')
  }

  @Monitor('session.updatedAt')
  onAuthSessionUpdated(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    this.loadAccounts()
    if (!cookie) {
      this.resetAccountMeta()
      this.clearAccountMetaCache()
      return
    }
    this.sessionError = ''
    this.resetAccountMeta()
    this.loadAccountMetaCache()
    this.loadAccountMeta(true)
  }

  @Monitor('activeAccount.id')
  onActiveAccountChanged(): void {
    this.loadAccounts()
    this.resetAccountMeta()
    this.loadAccountMetaCache()
    this.loadAccountMeta(true)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + ThemeConstants.SPACE_MD,
        onDidScroll: (offset: number, state: ScrollState) => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        }
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
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.requestDashboardRefresh('visible')
      }
    })
  }

  @Builder
  SectionHeader(title: ResourceStr) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  @Builder
  AuthActionRow(title: ResourceStr, subtitle: ResourceStr, action: () => void) {
    ConciseListRow({ title: title, subtitle: subtitle, action: action })
  }

  @Builder
  AuthSection() {
    if (!this.hasAnyAccount()) {
      GroupedListSection() {
        ConciseListRow({
          title: AccountPageCoordinator.LOGIN_TITLE,
          subtitle: AccountPageCoordinator.LOGIN_SUBTITLE,
          action: () => {
            this.ns.pushPathByName('V2exNativeLogin', null)
          }
        })
      }
    } else {
      GroupedListSection() {
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
            if (this.canOpenActiveAccountDetail()) {
              this.ns.pushPathByName('AccountDetail', null)
            }
          }
        })
      }
    }
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
      this.AuthActionRow(AppStrings.R_NAV_BLOCKED_LISTS, '', () => {
        this.ns.pushPathByName('BlockedLists', null)
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
          limit: this.rateLimit.limit,
          remaining: this.rateLimit.remaining,
          resetAt: this.rateLimit.reset,
          updatedAt: this.rateLimit.updatedAt
        })
      }

      this.SettingsDivider()
      Row() {
        Text(AccountPageCoordinator.CLEAR_API_AUTH_TITLE)
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.Red)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(ThemeConstants.ICON_SIZE_SM)
          .fontColor([$r('sys.color.font_secondary')])
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
    return AccountPageCoordinator.hasCookieAccount(this.authCookie.configured)
  }

  private hasAnyAccount(): boolean {
    return AccountPageCoordinator.hasAnyAccount(
      this.authCookie.configured,
      this.authIdentity.tokenConfigured,
      this.accountsCount,
      this.session.username
    )
  }

  private canOpenActiveAccountDetail(): boolean {
    const username = this.currentUsername()
    if (!username) {
      return false
    }
    return this.hasRestoredActiveAccountIdentity()
  }

  private hasRestoredActiveAccountIdentity(): boolean {
    return !!this.activeAccount.id &&
      this.hasCookieAccount() &&
      !!(this.activeAccountUsername || this.session.username)
  }

  private loadAccounts(): void {
    if (this.accountListInFlight) {
      DiagnosticLogger.info('account', 'account_list_load_skip', { reason: 'in_flight' })
      return
    }
    this.accountListInFlight = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountStore.migrateFromSingletonIfNeeded(context)
      .then(() => AccountStore.restoreActiveId(context))
      .then(() => AccountStore.getAll(context))
      .then((records: AccountRecord[]) => {
        this.accountsCount = records.length
        this.loadActiveAccountIdentity(context, records)
        this.isAccountsLoaded = true
      })
      .catch((error: Error) => {
        console.error('loadAccounts failed: ' + error.message)
        this.accountsCount = 0
        this.activeAccountUsername = ''
        this.activeAccountAvatar = ''
        this.isAccountsLoaded = true
      })
      .finally(() => {
        this.accountListInFlight = false
      })
  }

  private loadActiveAccountIdentity(context: common.UIAbilityContext, records: AccountRecord[]): void {
    if (records.length === 0) {
      this.activeAccountUsername = ''
      this.activeAccountAvatar = ''
      return
    }
    const activeId = AccountStore.getActiveId()
    const fallbackRecord = records.find((record: AccountRecord) => record.id === activeId) ?? records[0]
    if (!activeId) {
      this.applyActiveAccountIdentity(fallbackRecord)
      return
    }
    AccountStore.getById(context, activeId)
      .then((record: AccountRecord | null) => {
        this.applyActiveAccountIdentity(record ?? fallbackRecord)
      })
      .catch((_error: Error) => {
        this.applyActiveAccountIdentity(fallbackRecord)
      })
  }

  private applyActiveAccountIdentity(record: AccountRecord | null): void {
    const nextUsername = record?.username || ''
    const nextAvatar = record?.avatar || ''
    const changed = nextUsername !== this.activeAccountUsername || nextAvatar !== this.activeAccountAvatar
    this.activeAccountUsername = nextUsername
    this.activeAccountAvatar = nextAvatar
    if (changed) {
      this.resetAccountMeta()
      this.loadAccountMetaCache()
      this.loadAccountMeta(true)
    }
  }

  private currentUsername(): string {
    if (this.activeAccount.id && this.activeAccountUsername) {
      return this.activeAccountUsername
    }
    return AccountPageCoordinator.identity(
      this.session.username,
      this.session.avatar,
      this.authProfile,
      this.storedUsername,
      this.activeAccountUsername,
      this.activeAccountAvatar
    ).username
  }

  private currentAvatar(): string {
    if (this.activeAccount.id && this.activeAccountAvatar) {
      return this.activeAccountAvatar
    }
    return AccountPageCoordinator.identity(
      this.session.username,
      this.session.avatar,
      this.authProfile,
      this.storedUsername,
      this.activeAccountUsername,
      this.activeAccountAvatar
    ).avatarUrl
  }

  private accountMetaText(): ResourceStr {
    return AccountPageCoordinator.accountMetaText(
      this.hasCookieAccount(),
      this.authIdentity.tokenConfigured,
      this.accountBalance,
      this.isAccountMetaLoading,
      this.accountMetaError
    )
  }

  private dailyMissionButtonText(): ResourceStr {
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
      this.rateLimit.limit,
      this.rateLimit.updatedAt,
      this.rateLimit.reset
    )
  }

  private loadAuthSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.storedUsername = snapshot.username
        DiagnosticLogger.info('account', 'account_auth_snapshot_loaded', {
          hasToken: !!snapshot.token,
          usernameHash: DiagnosticLogger.ownerHash(snapshot.username)
        })
        if (snapshot.token) {
          this.refreshAuthProfile(snapshot.token)
          this.refreshTokenInfo(snapshot.token)
        }
      })
      .catch((error: Error) => {
        this.authError = translateApiError(error)
      })
  }

  private loadSessionSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.load(context)
      .then(() => {
        DiagnosticLogger.info('account', 'account_cookie_restore_success', {})
        this.loadAccountMetaCache()
        this.validateCookieSession()
        this.loadAccountMeta()
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('account', 'account_cookie_restore_error', {}, error)
      })
    AuthSessionSettings.load(context)
      .catch((error: Error) => {
        console.error('restore auth session failed: ' + error.message)
      })
  }

  private validateCookieSession(force: boolean = false): void {
    if (this.isSessionValidating) {
      DiagnosticLogger.info('account', 'account_session_validate_skip', { reason: 'in_flight' })
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      DiagnosticLogger.info('account', 'account_session_validate_skip', { reason: 'no_cookie' })
      return
    }
    const now = Date.now()
    if (!force && this.session.validatedAt > 0 && now - this.session.validatedAt < 10 * 60 * 1000) {
      DiagnosticLogger.info('account', 'account_session_validate_skip', { reason: 'recent', force: force })
      return
    }
    const startedAt = Date.now()
    this.isSessionValidating = true
    this.sessionError = ''
    DiagnosticLogger.info('account', 'account_session_validate_start', {
      force: force,
      usernameHash: DiagnosticLogger.ownerHash(this.currentUsername())
    })
    const headers: Record<string, string> = { 'Cookie': cookie }
    this.http.getTextResponseWithHeaders('/settings', headers)
      .then((res) => {
        if (res.location.indexOf('/2fa') >= 0 || V2exSigninParser.extractTwoFactorForm(res.text)) {
          throw new V2exCookieTwoFactorRequiredError('/settings')
        }
        const username = V2exSessionParser.extractUsername(res.text)
        if (!username) {
          throw ApiErrors.webSessionExpired()
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
                DiagnosticLogger.info('account', 'account_session_validate_success', {
                  force: force,
                  usernameHash: DiagnosticLogger.ownerHash(username),
                  durationMs: Date.now() - startedAt
                })
                this.loadAccountMeta(true)
              })
          })
      })
      .catch((error: Error) => {
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        DiagnosticLogger.warn('account', 'account_session_validate_error', { force: force, durationMs: Date.now() - startedAt }, error)
        const message = translateApiError(error)
        this.sessionError = message
        this.handleExpiredCookieSession(error, message)
      })
      .finally(() => {
        this.isSessionValidating = false
      })
  }

  private handleExpiredCookieSession(error: Error, message: string): void {
    if (!isApiError(error) || (error as ApiError).code !== ApiErrorCode.WEB_SESSION_EXPIRED) {
      return
    }
    DiagnosticLogger.warn('account', 'account_session_expired', {})
    this.sessionError = message
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.clearForBaseUrl(context, HttpClient.getInstance().getBaseUrl())
      .then(() => AuthSessionSettings.clear(context))
      .catch((_error: Error) => {
      })
      .finally(() => {
        this.accountBalance = null
        this.dailyMission = null
        this.clearAccountMetaCache()
      })
  }

  private openTwoFactorFromCookie(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    DiagnosticLogger.warn('account', 'account_session_two_factor_required', {})
    if (!cookie) {
      this.sessionError = AppStrings.text(AppStrings.R_TWO_FACTOR_RELOGIN_REQUIRED, 'V2EX requires two-factor verification. Please sign in again')
      return
    }
    this.sessionError = AppStrings.text(AppStrings.R_TWO_FACTOR_REQUIRED, 'V2EX requires two-factor verification')
    this.accountMetaError = AppStrings.text(AppStrings.R_TWO_FACTOR_REQUIRED, 'V2EX requires two-factor verification')
    TwoFactorChallengeService.request(cookie, 'account')
  }

  private refreshAuthProfile(token: string): void {
    this.api.getAuthenticatedMember(token)
      .then((profile: V2exAuthenticatedMember) => {
        this.authProfile = profile
        this.storedUsername = profile.username || this.storedUsername
      })
      .catch((error: Error) => {
        this.authError = translateApiError(error)
      })
  }

  private refreshTokenInfo(token: string): void {
    this.tokenInfoError = ''
    this.api.getTokenInfo(token)
      .then((info: V2exTokenInfo) => {
        if (info && info.success === false) {
          this.tokenInfo = null
          this.tokenInfoError = info.message || AppStrings.text(AppStrings.R_TOKEN_INFO_FAILED, 'Failed to fetch token info')
          return
        }
        this.tokenInfo = info
        this.tokenInfoError = ''
      })
      .catch((error: Error) => {
        this.tokenInfo = null
        this.tokenInfoError = translateApiError(error)
      })
  }

  private confirmClearAuth(): void {
    if (!this.authIdentity.tokenConfigured || this.isAuthLoading) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AccountPageCoordinator.CLEAR_API_AUTH_TITLE,
      message: AccountPageCoordinator.CLEAR_API_AUTH_MESSAGE,
      primaryButton: {
        value: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'), action: () => {
        }
      },
      secondaryButton: {
        value: AppStrings.text(AppStrings.R_COMMON_CLEAR, 'Clear'),
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
          this.clearAccountMetaCache()
        } else {
          this.loadAccountMetaCache()
          this.loadAccountMeta(true)
        }
      })
      .catch((error: Error) => {
        this.authError = translateApiError(error)
      })
  }

  private accountMetaOwnerKey(): string {
    return AccountMetaSettings.ownerKey(this.currentUsername(), this.accountMetaSource())
  }

  private accountMetaSource(): string {
    return this.activeAccount.id ? 'cookie:' + this.activeAccount.id : 'cookie'
  }

  private resetAccountMeta(): void {
    this.accountBalance = null
    this.dailyMission = null
    this.accountMetaError = ''
    this.isAccountMetaLoading = false
    this.accountMetaRequestId++
  }

  private loadAccountMetaCache(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const ownerKey = this.accountMetaOwnerKey()
    if (!cookie || !ownerKey) {
      DiagnosticLogger.info('account', 'account_meta_cache_load_miss', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) })
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountMetaSettings.loadCache(context, ownerKey)
      .then((snapshot) => {
        if (!snapshot || snapshot.ownerKey !== this.accountMetaOwnerKey()) {
          DiagnosticLogger.info('account', 'account_meta_cache_load_miss', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) })
          return
        }
        DiagnosticLogger.info('account', 'account_meta_cache_load_hit', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) })
        if (snapshot.balance) {
          this.accountBalance = snapshot.balance
        }
        if (snapshot.dailyMission) {
          this.dailyMission = snapshot.dailyMission
        }
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('account', 'account_meta_cache_load_error', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) }, error)
      })
  }

  private saveAccountMetaCache(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const ownerKey = this.accountMetaOwnerKey()
    if (!cookie || !ownerKey || !this.accountBalance) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountMetaSettings.saveCache(context, ownerKey, this.accountBalance, this.dailyMission, this.accountMetaSource())
      .then(() => {
        DiagnosticLogger.info('account', 'account_meta_cache_save_success', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) })
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('account', 'account_meta_cache_save_error', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) }, error)
      })
  }

  private clearAccountMetaCache(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DiagnosticLogger.info('account', 'account_meta_store_clear', {})
    AccountMetaSettings.clearCache(context).catch((error: Error) => {
      console.error('clear account meta cache failed: ' + error.message)
    })
  }

  private loadAccountMeta(force: boolean = false): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isAccountMetaLoading) {
      DiagnosticLogger.info('account', 'account_meta_fetch_skip', { reason: cookie ? 'in_flight' : 'no_cookie' })
      return
    }
    if (!force && this.accountBalance && this.dailyMission) {
      DiagnosticLogger.info('account', 'account_meta_fetch_skip', { reason: 'already_loaded', force: force })
      return
    }
    this.isAccountMetaLoading = true
    this.accountMetaError = ''
    const requestId = ++this.accountMetaRequestId
    const ownerKey = this.accountMetaOwnerKey()
    DiagnosticLogger.info('account', 'account_meta_fetch_start', { force: force, hasBalance: !!this.accountBalance, canRedeem: this.dailyMission ? this.dailyMission.canRedeem === true : false })
    Promise.all([
      this.api.getBalanceWithCookie(cookie),
      this.api.getDailyMissionWithCookie(cookie)
    ])
      .then((results) => {
        if (requestId !== this.accountMetaRequestId || cookie !== CookieJarSettings.getCurrentCookie() || ownerKey !== this.accountMetaOwnerKey()) {
          DiagnosticLogger.info('account', 'account_meta_fetch_stale', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) })
          return
        }
        this.accountBalance = results[0]
        this.dailyMission = results[1]
        DiagnosticLogger.info('account', 'account_meta_fetch_success', {
          force: force,
          hasBalance: !!this.accountBalance,
          canRedeem: this.dailyMission ? this.dailyMission.canRedeem === true : false
        })
        this.saveAccountMetaCache()
      })
      .catch((error: Error) => {
        if (requestId !== this.accountMetaRequestId || cookie !== CookieJarSettings.getCurrentCookie() || ownerKey !== this.accountMetaOwnerKey()) {
          DiagnosticLogger.info('account', 'account_meta_fetch_stale_error', { ownerHash: DiagnosticLogger.ownerHash(ownerKey) })
          return
        }
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        DiagnosticLogger.warn('account', 'account_meta_fetch_error', { force: force }, error)
        const message = translateApiError(error)
        this.accountMetaError = message
        this.handleExpiredCookieSession(error, message)
      })
      .finally(() => {
        this.isAccountMetaLoading = false
      })
  }

  private redeemDailyMission(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isDailyRedeeming) {
      DiagnosticLogger.info('account', 'account_daily_redeem_skip', { reason: cookie ? 'in_flight' : 'no_cookie' })
      return
    }
    if (!this.dailyMission || !this.dailyMission.canRedeem || !this.dailyMission.redeemPath) {
      DiagnosticLogger.info('account', 'account_daily_redeem_skip', { reason: 'not_redeemable' })
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_ALREADY_CHECKED_IN_TODAY, 'Already checked in today') }).catch((_error: Error) => {
      })
      return
    }
    this.isDailyRedeeming = true
    this.accountMetaError = ''
    DiagnosticLogger.info('account', 'account_daily_redeem_start', { canRedeem: true })
    this.api.redeemDailyMissionWithCookie(cookie, this.dailyMission.redeemPath)
      .then((mission: V2exDailyMission) => {
        this.dailyMission = mission
        DiagnosticLogger.info('account', 'account_daily_redeem_success', { canRedeem: mission.canRedeem === true, messageCode: mission.message ? 'message_present' : '' })
        promptAction.openToast({ message: AccountPageCoordinator.dailyMissionMessage(mission.message) || AppStrings.text(AppStrings.R_CHECKIN_COMPLETED, 'Check-in completed') }).catch((_error: Error) => {
        })
        this.loadAccountMeta(true)
      })
      .catch((error: Error) => {
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        DiagnosticLogger.warn('account', 'account_daily_redeem_error', { canRedeem: this.dailyMission ? this.dailyMission.canRedeem === true : false }, error)
        const message = translateApiError(error)
        this.accountMetaError = message
        this.handleExpiredCookieSession(error, message)
        promptAction.openToast({ message: message }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isDailyRedeeming = false
      })
  }

  private clearDashboardRefreshTimer(): void {
    if (this.dashboardRefreshTimerId === -1) {
      return
    }
    clearTimeout(this.dashboardRefreshTimerId)
    this.dashboardRefreshTimerId = -1
  }

  private requestDashboardRefresh(reason: string): void {
    if (this.dashboardRefreshTimerId !== -1) {
      DiagnosticLogger.info('account', 'account_dashboard_refresh_coalesced', { reason: reason })
      return
    }
    this.dashboardRefreshTimerId = setTimeout((): void => {
      this.dashboardRefreshTimerId = -1
      this.refreshDashboardSnapshot(reason)
    }, 0)
  }

  private refreshDashboardSnapshot(reason: string): void {
    DiagnosticLogger.info('account', 'account_dashboard_refresh_start', { reason: reason })
    this.loadLocalContentStats()
    this.loadAccounts()
  }

  private loadLocalContentStats(): void {
    if (this.localStatsInFlight) {
      DiagnosticLogger.info('account', 'account_local_stats_load_skip', { reason: 'in_flight' })
      return
    }
    this.localStatsInFlight = true
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
        // Re-publish to AppStorage (was the @StorageLink write-back) so other readers / a cold open
        // see the freshly computed counts.
        LocalDataPublisher.publishLocalContentStats(stats)
      })
      .catch((error: Error) => {
        console.error('load local content stats failed: ' + error.message)
      })
      .finally(() => {
        this.localStatsInFlight = false
      })
  }

}
