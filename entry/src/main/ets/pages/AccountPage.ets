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
  SavedNode,
  SavedTopic,
  V2exAuthenticatedMember,
  V2exBalance,
  V2exDailyMission,
  V2exTokenInfo,
  ViewedTopic,
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
  ApiService,
  AccountMetaSettings,
  AuthSessionSettings,
  AuthSettings,
  ConciseListRow,
  CookieJarSettings,
  DiagnosticLogger,
  GroupedListSection,
  HttpClient,
  ListDivider as SharedListDivider,
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
  @StorageLink(StorageKeys.ACTIVE_ACCOUNT_ID) @Watch('onActiveAccountChanged') activeAccountId: string = ''
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
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()
  private localStatsRequestId: number = 0
  private accountMetaRequestId: number = 0
  @State private accountsCount: number = 0
  @State private isAccountsLoaded: boolean = false
  @State private activeAccountUsername: string = ''
  @State private activeAccountAvatar: string = ''
  @Prop @Watch('onRefreshKeyChanged') refreshKey: number = 0

  aboutToAppear(): void {
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
    this.refreshLocalData()
    this.loadAccounts()
  }

  onLocalDataUpdated(_propName: string): void {
    this.refreshLocalData()
  }

  onRefreshKeyChanged(_propName: string): void {
    this.refreshLocalData()
    this.loadAccounts()
  }

  onAuthSessionUpdated(_propName: string): void {
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

  onActiveAccountChanged(_propName: string): void {
    this.loadAccounts()
    this.resetAccountMeta()
    this.loadAccountMetaCache()
    this.loadAccountMeta(true)
  }

  build() {
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
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.refreshLocalData()
        this.loadAccounts()
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
    return AccountPageCoordinator.hasCookieAccount(this.authCookieConfigured)
  }

  private hasAnyAccount(): boolean {
    return AccountPageCoordinator.hasAnyAccount(
      this.authCookieConfigured,
      this.authTokenConfigured,
      this.accountsCount,
      this.sessionUsername
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
    return !!this.activeAccountId &&
      this.hasCookieAccount() &&
      !!(this.activeAccountUsername || this.sessionUsername)
  }

  private loadAccounts(): void {
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
    if (this.activeAccountId && this.activeAccountUsername) {
      return this.activeAccountUsername
    }
    return AccountPageCoordinator.identity(
      this.sessionUsername,
      this.sessionAvatar,
      this.authProfile,
      this.storedUsername,
      this.activeAccountUsername,
      this.activeAccountAvatar
    ).username
  }

  private currentAvatar(): string {
    if (this.activeAccountId && this.activeAccountAvatar) {
      return this.activeAccountAvatar
    }
    return AccountPageCoordinator.identity(
      this.sessionUsername,
      this.sessionAvatar,
      this.authProfile,
      this.storedUsername,
      this.activeAccountUsername,
      this.activeAccountAvatar
    ).avatarUrl
  }

  private accountMetaText(): ResourceStr {
    return AccountPageCoordinator.accountMetaText(
      this.hasCookieAccount(),
      this.authTokenConfigured,
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
    if (!force && this.sessionValidatedAt > 0 && now - this.sessionValidatedAt < 10 * 60 * 1000) {
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
    if (!this.authTokenConfigured || this.isAuthLoading) {
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
    return this.activeAccountId ? 'cookie:' + this.activeAccountId : 'cookie'
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

}
