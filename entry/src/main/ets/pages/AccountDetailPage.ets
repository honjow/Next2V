import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AccountSignedInCard,
} from '../components/AccountDashboardComponents'
import {
  AccountMetaSettings,
  ApiService,
  AppStrings,
  AuthSettings,
  AuthSessionSettings,
  CookieJarSettings,
  ConciseListRow,
  DiagnosticLogger,
  GroupedListSection,
  HttpClient,
  ListDivider as SharedListDivider,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  setAppStorageValue,
  StorageKeys,
  ThemeConstants,
  UserProfileParams,
  V2exBalance,
  V2exDailyMission,
  V2exAuthenticatedMember,
  translateApiError,
} from 'shared'
import { AccountPageCoordinator } from '../model/AccountPageCoordinator'

@Component
export struct AccountDetailPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) authCookieConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_TOKEN_CONFIGURED) authTokenConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_USERNAME) storedUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) sessionUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_AVATAR) sessionAvatar: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_UPDATED_AT) @Watch('onAuthSessionUpdated') authSessionUpdatedAt: number = 0

  @State private authToken: string = ''
  @State private authProfile: V2exAuthenticatedMember | null = null
  @State private authError: string = ''
  @State private accountBalance: V2exBalance | null = null
  @State private dailyMission: V2exDailyMission | null = null
  @State private accountMetaError: string = ''
  @State private isAccountMetaLoading: boolean = false
  @State private isDailyRedeeming: boolean = false
  @State private isLoggingOut: boolean = false

  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
  }

  onAuthSessionUpdated(_propName: string): void {
    this.loadAccountMetaCache()
    this.loadAccountMeta()
  }

  build() {
    Column() {
      SecondaryListScaffold({
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_MD,
      }) {
        ListItem() {
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
              }
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
              setAppStorageValue<string>(StorageKeys.ACCOUNT_WEB_VIEW_URL, url)
              this.ns.pushPathByName('AccountWebView', null)
            })
            this.SettingsDivider()
            this.AccountRow(AccountPageCoordinator.WEB_ACCOUNT_SETTINGS_TITLE, () => {
              const url = this.webBaseUrl() + '/settings'
              setAppStorageValue<string>(StorageKeys.ACCOUNT_WEB_VIEW_URL, url)
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
      }
    })
  }

  private currentUsername(): string {
    return AccountPageCoordinator.identity(
      this.sessionUsername,
      this.sessionAvatar,
      this.authProfile,
      this.storedUsername,
      '',
      ''
    ).username
  }

  private currentAvatar(): string {
    return AccountPageCoordinator.identity(
      this.sessionUsername,
      this.sessionAvatar,
      this.authProfile,
      this.storedUsername,
      '',
      ''
    ).avatarUrl
  }

  private hasCookieAccount(): boolean {
    return AccountPageCoordinator.hasCookieAccount(this.authCookieConfigured)
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
    AuthSessionSettings.load(context)
      .catch((error: Error) => {
        console.error('AccountDetailPage auth session restore failed: ' + error.message)
      })
  }

  private accountMetaOwnerKey(): string {
    return AccountMetaSettings.ownerKey(this.currentUsername(), 'cookie')
  }

  private loadAccountMetaCache(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const ownerKey = this.accountMetaOwnerKey()
    if (!cookie || !ownerKey) {
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
      })
      .catch((_error: Error) => {
      })
  }

  private loadAccountMeta(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isAccountMetaLoading) {
      return
    }
    if (this.accountBalance && this.dailyMission) {
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
        this.saveAccountMetaCache()
      })
      .catch((error: Error) => {
        const message = translateApiError(error)
        this.accountMetaError = message
      })
      .finally(() => {
        this.isAccountMetaLoading = false
      })
  }

  private saveAccountMetaCache(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const ownerKey = this.accountMetaOwnerKey()
    if (!cookie || !ownerKey || !this.accountBalance) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountMetaSettings.saveCache(context, ownerKey, this.accountBalance, this.dailyMission, 'cookie')
      .catch((_error: Error) => {
      })
  }

  private redeemDailyMission(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isDailyRedeeming) {
      return
    }
    if (!this.dailyMission || !this.dailyMission.canRedeem || !this.dailyMission.redeemPath) {
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_ALREADY_CHECKED_IN_TODAY, 'Already checked in today') })
        .catch((_error: Error) => {})
      return
    }
    this.isDailyRedeeming = true
    this.accountMetaError = ''
    this.api.redeemDailyMissionWithCookie(cookie, this.dailyMission.redeemPath)
      .then((mission: V2exDailyMission) => {
        this.dailyMission = mission
        promptAction.openToast({ message: AppStrings.text(AppStrings.R_CHECKIN_COMPLETED, 'Check-in completed') })
          .catch((_error: Error) => {})
        this.loadAccountMeta()
      })
      .catch((error: Error) => {
        const message = translateApiError(error)
        this.accountMetaError = message
        promptAction.openToast({ message: message }).catch((_error: Error) => {})
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
    this.getUIContext().showAlertDialog({
      title: AccountPageCoordinator.LOGOUT_TITLE,
      message: AppStrings.text(AppStrings.R_ACCOUNT_REMOVE_MESSAGE_ARG, 'Sign out of this account?')
        .replace('{0}', this.currentUsername() || AppStrings.text(AppStrings.R_ACCOUNT_V2EX_USER, 'V2EX user')),
      primaryButton: {
        value: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: AccountPageCoordinator.LOGOUT_TITLE,
        fontColor: Color.Red,
        action: () => {
          this.performLogout(context)
          this.ns.pop()
        }
      }
    })
  }

  private performLogout(context: common.UIAbilityContext): void {
    this.isLoggingOut = true
    const baseUrl = this.http.getBaseUrl()
    CookieJarSettings.clearForBaseUrl(context, baseUrl)
      .then(() => AuthSessionSettings.clear(context))
      .then(() => {
        this.ns.pop()
      })
      .catch((error: Error) => {
        console.error('AccountDetailPage logout failed: ' + error.message)
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isLoggingOut = false
      })
  }
}
