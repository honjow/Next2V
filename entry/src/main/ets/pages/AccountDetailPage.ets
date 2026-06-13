import { AppPrompt } from 'shared'
import { common } from '@kit.AbilityKit'
import { AccountDetailHeaderCard } from '../components/AccountDashboardComponents'
import {
  AccountStore,
  AccountMetaSettings,
  AccountMetaState,
  AccountMetaPublisher,
  AccountSessionCoordinator,
  ActiveAccountState,
  ApiService,
  AppStrings,
  connectAccountMeta,
  AuthCookieState,
  AuthIdentityState,
  AuthSessionSignalState,
  AuthSettings,
  AuthSessionSettings,
  connectActiveAccount,
  connectAuthCookie,
  connectAuthIdentity,
  connectAuthSessionSignal,
  connectNavStack,
  CookieJarSettings,
  ConciseListRow,
  DiagnosticLogger,
  GroupedListSection,
  HttpClient,
  ListDivider as SharedListDivider,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  publishAccountWebViewUrl,
  ThemeConstants,
  UserProfileParams,
  V2exBalance,
  V2exDailyMission,
  V2exDailyRedeemResult,
  V2exAuthenticatedMember,
  translateApiError,
} from 'shared'
import type { AccountRecord } from 'shared'
import { AccountPageCoordinator } from '../model/AccountPageCoordinator'
@ComponentV2
export struct AccountDetailPage {
  // ns from NavStackHolder (was @Consume('ns')).
  private ns: NavPathStack = connectNavStack().stack;
  // Auth/session/active-account read from their V2 mirrors (dual-written at the auth service
  // chokepoints) — replaces the AUTH_* / ACTIVE_ACCOUNT_ID @StorageLink. The page never mutates these;
  // the account state machine does, and the mirrors reflect it.
  private authCookie: AuthCookieState = connectAuthCookie();
  private authIdentity: AuthIdentityState = connectAuthIdentity();
  private session: AuthSessionSignalState = connectAuthSessionSignal();
  private activeAccount: ActiveAccountState = connectActiveAccount();
  // Shared balance/daily-mission holder mirrored by both account surfaces (single source of truth).
  private accountMeta: AccountMetaState = connectAccountMeta();

  // storedUsername is the API-token fallback identity, page-managed (loaded from AuthSettings; cleared
  // on logout) — not a mirror because the page is its own authority for this display value.
  @Local private storedUsername: string = '';
  @Local private authToken: string = '';
  @Local private authProfile: V2exAuthenticatedMember | null = null;
  @Local private authError: string = '';
  @Local private accountBalance: V2exBalance | null = null;
  @Local private dailyMission: V2exDailyMission | null = null;
  @Local private accountMetaError: string = '';
  @Local private isAccountMetaLoading: boolean = false;
  @Local private isDailyRedeeming: boolean = false;
  @Local private isLoggingOut: boolean = false;
  @Local private activeAccountUsername: string = '';
  @Local private activeAccountAvatar: string = '';

  private http: HttpClient = HttpClient.getInstance();
  private api: ApiService = new ApiService();
  private accountMetaRequestId: number = 0;

  aboutToAppear(): void {
    this.storedUsername = this.authIdentity.username
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
    this.loadAccounts()
  }

  @Monitor('session.updatedAt')
  onAuthSessionUpdated(): void {
    this.resetAccountMeta()
    this.loadAccounts()
    this.loadAccountMetaCache()
    this.loadAccountMeta(true)
  }

  @Monitor('activeAccount.id')
  onActiveAccountChanged(): void {
    this.resetAccountMeta()
    this.loadAccounts()
    this.loadAccountMetaCache()
    this.loadAccountMeta(true)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_MD,
      }) {
        ListItem() {
          GroupedListSection() {
            AccountDetailHeaderCard({
              avatarUrl: this.currentAvatar(),
              username: this.currentUsername(),
              balance: this.accountBalance,
              fallbackText: this.accountMetaFallbackText(),
              sessionError: this.authError,
              accountMetaError: this.accountMetaError,
              dailyMissionMessage: this.dailyMissionStatusText(),
            })
          }
        }
        ListItem() {
          this.SectionHeader(AccountPageCoordinator.SECTION_ACCOUNT_CONTENT)
        }
        .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() {
          GroupedListSection() {
            this.AccountRow(AccountPageCoordinator.PROFILE_TITLE, () => {
              const username = this.currentUsername()
              if (username) {
                let p: UserProfileParams = { username: username }
                this.ns.pushPathByName('UserProfile', p as Object)
              }
            })
            this.SettingsDivider()
            this.AccountRow(AccountPageCoordinator.BALANCE_DETAIL_TITLE, () => {
              const url = this.webBaseUrl() + '/balance'
              publishAccountWebViewUrl(url)
              this.ns.pushPathByName('AccountWebView', null)
            })
            this.SettingsDivider()
            this.AccountRow(AccountPageCoordinator.WEB_ACCOUNT_SETTINGS_TITLE, () => {
              const url = this.webBaseUrl() + '/settings'
              publishAccountWebViewUrl(url)
              this.ns.pushPathByName('AccountWebView', null)
            })
          }
        }
        ListItem() {
          GroupedListSection() {
            this.LogoutRow()
          }
        }
        .margin({ top: ThemeConstants.SPACE_MD })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
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
  AccountRow(title: ResourceStr, action: () => void) {
    ConciseListRow({ title: title, action: action })
  }

  @Builder
  LogoutRow() {
    ConciseListRow({
      title: AccountPageCoordinator.LOGOUT_TITLE,
      showChevron: false,
      primaryColor: Color.Red,
      action: () => {
        this.confirmLogout()
      },
    })
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
      this.activeAccountAvatar,
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
      this.activeAccountAvatar,
    ).avatarUrl
  }

  private hasCookieAccount(): boolean {
    return AccountPageCoordinator.hasCookieAccount(this.authCookie.configured)
  }

  private accountMetaText(): ResourceStr {
    return AccountPageCoordinator.accountMetaText(
      this.hasCookieAccount(),
      this.authIdentity.tokenConfigured,
      this.accountBalance,
      this.isAccountMetaLoading,
      this.accountMetaError,
    )
  }

  private dailyMissionButtonText(): ResourceStr {
    return AccountPageCoordinator.dailyMissionButtonText(this.isDailyRedeeming, this.dailyMission)
  }

  private accountMetaFallbackText(): ResourceStr {
    return this.accountMetaError ? '' : this.accountMetaText()
  }

  private dailyMissionStatusText(): ResourceStr {
    if (!this.dailyMission) {
      return ''
    }
    return AccountPageCoordinator.dailyMissionMessage(this.dailyMission.message)
  }

  private dailyMissionEnabled(): boolean {
    return AccountPageCoordinator.dailyMissionEnabled(
      this.hasCookieAccount(),
      this.isAccountMetaLoading,
      this.isDailyRedeeming,
      this.dailyMission,
    )
  }

  private webBaseUrl(): string {
    return this.http.getBaseUrl()
  }

  private loadAuthSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.storedUsername = snapshot.username
      })
      .catch((error: Error) => {
        this.authError = translateApiError(error)
      })
  }

  private loadSessionSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.load(context)
      .then(() => {
        this.loadAccountMetaCache()
        this.loadAccountMeta()
      })
      .catch((error: Error) => {
        console.error('AccountDetailPage cookie restore failed: ' + error.message)
      })
    AuthSessionSettings.load(context).catch((error: Error) => {
      console.error('AccountDetailPage auth session restore failed: ' + error.message)
    })
  }

  private loadAccounts(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountStore.migrateFromSingletonIfNeeded(context)
      .then(() => AccountStore.restoreActiveId(context))
      .then(() => AccountStore.getAll(context))
      .then((records: AccountRecord[]) => {
        this.loadActiveAccountIdentity(context, records)
      })
      .catch((error: Error) => {
        console.error('AccountDetailPage loadAccounts failed: ' + error.message)
        this.activeAccountUsername = ''
        this.activeAccountAvatar = ''
      })
  }

  private loadActiveAccountIdentity(
    context: common.UIAbilityContext,
    records: AccountRecord[],
  ): void {
    if (records.length === 0) {
      this.activeAccountUsername = ''
      this.activeAccountAvatar = ''
      return
    }
    const activeId = AccountStore.getActiveId()
    const fallbackRecord =
      records.find((record: AccountRecord) => record.id === activeId) ?? records[0]
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
    const changed =
      nextUsername !== this.activeAccountUsername || nextAvatar !== this.activeAccountAvatar
    this.activeAccountUsername = nextUsername
    this.activeAccountAvatar = nextAvatar
    if (changed) {
      this.resetAccountMeta()
      this.loadAccountMetaCache()
      this.loadAccountMeta(true)
    }
  }

  // Mirror the shared holder into local render fields when a peer fetch / browse-harvest updates it. The
  // ownerKey gate keeps a different account's value from bleeding in across a switch.
  @Monitor('accountMeta.updatedAt')
  onAccountMetaUpdated(): void {
    this.mirrorAccountMetaFromHolder()
  }

  private mirrorAccountMetaFromHolder(): boolean {
    const ownerKey = this.accountMetaOwnerKey()
    if (!ownerKey || this.accountMeta.ownerKey !== ownerKey || !this.accountMeta.balance) {
      return false
    }
    this.accountBalance = this.accountMeta.balance
    if (this.accountMeta.dailyMission) {
      this.dailyMission = this.accountMeta.dailyMission
    }
    return true
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
      return
    }
    // Prefer the live shared holder; fall back to the persisted cache only on a cold start.
    if (this.mirrorAccountMetaFromHolder()) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountMetaSettings.loadCache(context, ownerKey)
      .then((snapshot) => {
        if (!snapshot || snapshot.ownerKey !== this.accountMetaOwnerKey()) {
          return
        }
        if (snapshot.balance) {
          this.accountBalance = snapshot.balance
        }
        if (snapshot.dailyMission) {
          this.dailyMission = snapshot.dailyMission
        }
        AccountMetaPublisher.publishCached(
          snapshot.ownerKey,
          snapshot.balance,
          snapshot.dailyMission,
        )
      })
      .catch((_error: Error) => {})
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
    const requestId = ++this.accountMetaRequestId
    const ownerKey = this.accountMetaOwnerKey()
    Promise.all([this.api.getBalanceWithCookie(cookie), this.api.getDailyMissionWithCookie(cookie)])
      .then((results) => {
        if (
          requestId !== this.accountMetaRequestId ||
          cookie !== CookieJarSettings.getCurrentCookie() ||
          ownerKey !== this.accountMetaOwnerKey()
        ) {
          return
        }
        this.accountBalance = results[0]
        this.dailyMission = results[1]
        this.publishAccountMeta(cookie, ownerKey)
      })
      .catch((error: Error) => {
        if (
          requestId !== this.accountMetaRequestId ||
          cookie !== CookieJarSettings.getCurrentCookie() ||
          ownerKey !== this.accountMetaOwnerKey()
        ) {
          return
        }
        const message = translateApiError(error)
        this.accountMetaError = message
      })
      .finally(() => {
        this.isAccountMetaLoading = false
      })
  }

  // Authoritative fetch result → shared holder (mirrors to this page + the dashboard card) + cache.
  private publishAccountMeta(cookie: string, ownerKey: string): void {
    if (!cookie || !ownerKey || !this.accountBalance) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountMetaPublisher.publishFetched(
      context,
      ownerKey,
      this.accountBalance,
      this.dailyMission,
      this.accountMetaSource(),
      cookie,
    )
  }

  private redeemDailyMission(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isDailyRedeeming) {
      return
    }
    if (!this.dailyMission || !this.dailyMission.canRedeem || !this.dailyMission.redeemPath) {
      AppPrompt.openToast({
          message: AppStrings.text(
            $r('app.string.already_checked_in_today'),
            'Already checked in today',
          ),
        })
        .catch((_error: Error) => {})
      return
    }
    this.isDailyRedeeming = true
    this.accountMetaError = ''
    this.api
      .redeemDailyMissionWithCookie(cookie)
      .then((redeemed: V2exDailyRedeemResult) => {
        this.dailyMission = redeemed.mission
        const toastMessage =
          redeemed.rewardCoins > 0
            ? AppStrings.format(
                AppStrings.text($r('app.string.daily_checkin_reward_toast'), 'Checked in: +{0} bronze'),
                [`${redeemed.rewardCoins}`],
              )
            : AppStrings.text($r('app.string.checkin_completed'), 'Check-in completed')
        AppPrompt.openToast({ message: toastMessage }).catch((_error: Error) => {})
        this.loadAccountMeta()
      })
      .catch((error: Error) => {
        const message = translateApiError(error)
        this.accountMetaError = message
        AppPrompt.openToast({ message: message }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isDailyRedeeming = false
      })
  }

  private confirmLogout(): void {
    if (this.isLoggingOut) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AppPrompt.showAlertDialog(this.getUIContext(), {
      title: AccountPageCoordinator.LOGOUT_TITLE,
      message: AppStrings.text(
        $r('app.string.account_remove_message_arg'),
        'Sign out of this account?',
      ).replace(
        '{0}',
        this.currentUsername() || AppStrings.text($r('app.string.account_v2ex_user'), 'V2EX user'),
      ),
      primaryButton: {
        value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: AccountPageCoordinator.LOGOUT_TITLE,
        fontColor: Color.Red,
        action: () => {
          this.performLogout(context)
        },
      },
    })
  }

  private performLogout(context: common.UIAbilityContext): void {
    this.isLoggingOut = true
    AccountSessionCoordinator.removeActiveAccount(context)
      .then(() => {
        // Session identity (username/avatar) is mirror-read now; removeActiveAccount applies the new
        // session/logged-out state at the service, so no optimistic local clear is needed before pop.
        this.authToken = ''
        this.authProfile = null
        this.storedUsername = ''
        this.accountBalance = null
        this.dailyMission = null
        this.accountMetaError = ''
        this.ns.pop()
      })
      .catch((error: Error) => {
        console.error('AccountDetailPage logout failed: ' + error.message)
        AppPrompt.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isLoggingOut = false
      })
  }
}
