import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { V2exTwoFactorPrompt } from '../components/V2exTwoFactorPrompt'
import type {
  LocalContentStats,
  SavedNode,
  SavedTopic,
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
  Avatar,
  CollectionSettings,
  ConciseListRow,
  CookieJarSettings,
  DateUtils,
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

@Component
struct AccountCoinIconCanvas {
  @Prop rimColor: string
  @Prop faceColor: string
  @Prop edgeColor: string
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  build() {
    Canvas(this.context)
      .width(16)
      .height(16)
      .onReady(() => {
        this.drawCoin()
      })
  }

  private drawCoin(): void {
    const ctx = this.context
    ctx.clearRect(0, 0, 16, 16)
    const face = ctx.createLinearGradient(3, 2, 13, 14)
    face.addColorStop(0.0, this.faceColor)
    face.addColorStop(0.62, this.edgeColor)
    face.addColorStop(1.0, this.rimColor)
    ctx.beginPath()
    ctx.arc(8, 8, 7.2, 0, Math.PI * 2)
    ctx.fillStyle = this.rimColor
    ctx.fill()
    ctx.save()
    ctx.beginPath()
    ctx.arc(8, 8, 5.8, 0, Math.PI * 2)
    ctx.clip()
    ctx.fillStyle = face
    ctx.fillRect(2, 2, 12, 12)
    ctx.fillStyle = 'rgba(0,0,0,0.10)'
    ctx.beginPath()
    ctx.moveTo(2.2, 10.8)
    ctx.quadraticCurveTo(8.0, 13.8, 13.8, 10.8)
    ctx.lineTo(13.8, 14.2)
    ctx.lineTo(2.2, 14.2)
    ctx.closePath()
    ctx.fill()
    ctx.restore()
    ctx.beginPath()
    ctx.arc(8, 8, 5.8, 0, Math.PI * 2)
    ctx.lineWidth = 1.1
    ctx.strokeStyle = 'rgba(255,255,255,0.55)'
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(8, 8, 3.1, 0, Math.PI * 2)
    ctx.lineWidth = 1
    ctx.strokeStyle = 'rgba(255,255,255,0.34)'
    ctx.stroke()
  }
}

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
            this.SectionHeader('账号')
          }

          ListItem() {
            this.AuthSection()
          }

          if (this.hasCookieAccount()) {
            ListItem() {
              this.SectionHeader('账号内容')
            }
            .margin({ top: ThemeConstants.SPACE_MD })

            ListItem() {
              this.AccountContentSection()
            }
          }

          ListItem() {
            this.SectionHeader('本地内容')
          }
          .margin({ top: ThemeConstants.SPACE_MD })

          ListItem() {
            this.LocalContentSection()
          }

          ListItem() {
            this.SectionHeader('更多')
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
      .bindSheet($$this.twoFactorVisible, this.TwoFactorSheet(), {
        height: SheetSize.MEDIUM,
        preferType: SheetType.BOTTOM,
        dragBar: false,
        showClose: false,
        maskColor: 'rgba(0,0,0,0.24)',
        backgroundColor: $r('sys.color.ohos_id_color_card_bg'),
        onDisappear: () => {
          this.twoFactorVisible = false
        }
      })
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
          Column({ space: ThemeConstants.SPACE_MD }) {
            Avatar({ url: this.currentAvatar(), avatarSize: 72 })
            Text(this.currentUsername() || 'V2EX 用户')
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            this.AccountDetailMetaBlock()
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .padding(ThemeConstants.SPACE_LG)
          .borderRadius(ThemeConstants.RADIUS_CARD)
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }

        ListItem() {
          GroupedListSection() {
            this.AuthActionRow('个人主页', '', () => {
              const username = this.currentUsername()
              if (username) {
                let p: UserProfileParams = { username: username }
                this.ns.pushPathByName('UserProfile', p as Object)
              }
            })
            this.SettingsDivider()
            this.AuthActionRow('余额明细', '', () => {
              this.openV2exPathInSystemBrowser('/balance')
            })
            this.SettingsDivider()
            this.AuthActionRow('网页账号设置', '', () => {
              this.openV2exPathInSystemBrowser('/settings')
            })
          }
        }

        ListItem() {
          GroupedListSection() {
            ConciseListRow({
              title: '退出登录',
              showChevron: false,
              primaryColor: Color.Red,
              action: () => {
                this.logoutAll()
                this.ns.pop()
              }
            })
          }
        }

        if (this.authTokenConfigured) {
          ListItem() {
            this.SectionHeader('高级 API')
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
    .bindSheet($$this.twoFactorVisible, this.TwoFactorSheet(), {
      height: SheetSize.MEDIUM,
      preferType: SheetType.BOTTOM,
      dragBar: false,
      showClose: false,
      maskColor: 'rgba(0,0,0,0.24)',
      backgroundColor: $r('sys.color.ohos_id_color_card_bg'),
      onDisappear: () => {
        this.twoFactorVisible = false
      }
    })
  }

  @Builder
  TwoFactorSheet() {
    V2exTwoFactorPrompt({
      visible: $twoFactorVisible,
      cookie: this.twoFactorCookie,
      message: '完成两步验证后即可继续访问 V2EX 账号内容。',
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
  CoinBalance() {
    if (this.accountBalance) {
      if (this.accountBalance.gold > 0 || this.accountBalance.silver > 0 || this.accountBalance.bronze > 0) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          if (this.accountBalance.gold > 0) {
            this.CoinAmount('#B97818', '#F6D77A', '#D59A24', this.accountBalance.gold)
          }
          if (this.accountBalance.silver > 0) {
            this.CoinAmount('#5C6978', '#F6FAFF', '#9FAFC0', this.accountBalance.silver)
          }
          if (this.accountBalance.bronze > 0) {
            this.CoinAmount('#7E4B27', '#D99B65', '#A66B3D', this.accountBalance.bronze)
          }
        }
        .alignItems(VerticalAlign.Center)
        .height(22)
      }
    } else {
      if (this.accountMetaText()) {
        Text(this.accountMetaText())
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
  }

  @Builder
  AccountDetailMetaBlock() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.CoinBalance()
      if (this.sessionError) {
        Text(this.sessionError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else if (this.accountMetaError) {
        Text(this.accountMetaError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else if (this.dailyMission) {
        Text(this.dailyMission.message)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Blank().height(ThemeConstants.FONT_SIZE_CAPTION)
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height(52)
  }

  @Builder
  CoinAmount(rimColor: string, faceColor: string, edgeColor: string, amount: number) {
    Row({ space: 4 }) {
      AccountCoinIconCanvas({ rimColor, faceColor, edgeColor })
      Text(this.formatCoinAmount(amount))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AuthSection() {
    Column() {
      if (!this.authCookieConfigured && !this.authTokenConfigured) {
        this.AuthActionRow('未登录', '点击登录 V2EX', () => {
          this.ns.pushPathByName('V2exNativeLogin', null)
        })
      } else {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Avatar({ url: this.currentAvatar(), avatarSize: 54 })
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(this.currentUsername() || 'V2EX 用户')
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            this.CoinBalance()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button(this.dailyMissionButtonText())
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .type(ButtonType.Normal)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .fontColor(this.dailyMissionEnabled() ? Color.White : $r('sys.color.font_secondary'))
            .backgroundColor(this.dailyMissionEnabled() ? ThemeConstants.BRAND_PRIMARY :
              $r('sys.color.ohos_id_color_button_normal'))
            .enabled(this.dailyMissionEnabled())
            .onClick(() => {
              this.redeemDailyMission()
            })

          Text('›')
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')
        .padding(ThemeConstants.SPACE_LG)
        .onClick(() => {
          this.ns.pushPathByName('Account', null)
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
  ProfileSummary() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.profileTagline()) {
        Text(this.profileTagline())
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        if (this.profileLocation()) {
          Text(`位置: ${this.profileLocation()}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
        if (this.profileCreatedAt() > 0) {
          Text(`注册: ${DateUtils.toDateString(this.profileCreatedAt())}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
  }

  @Builder
  TokenSummary() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.tokenScope()) {
        Text(`Token 权限: ${this.tokenScope()}`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.tokenExpiration() > 0) {
        Text(`到期: ${DateUtils.toDateString(this.tokenExpiration())}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.tokenLastUsed() > 0) {
        Text(`最后使用: ${DateUtils.toDateString(this.tokenLastUsed())}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
  }

  @Builder
  RateLimitSummary() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.apiRateLimitLimit > 0) {
        Text(`API 额度: ${this.apiRateLimitRemaining} / ${this.apiRateLimitLimit}`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.apiRateLimitReset > 0) {
        Text(`重置时间: ${DateUtils.toDateString(this.apiRateLimitReset)}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.apiRateLimitUpdatedAt > 0) {
        Text(`更新于 ${DateUtils.toDateString(this.apiRateLimitUpdatedAt)}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
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
      this.AuthActionRow('收藏主题', '', () => {
        this.ns.pushPathByName('MyTopics', null)
      })
      this.SettingsDivider()
      this.AuthActionRow('收藏节点', '', () => {
        this.ns.pushPathByName('MyNodes', null)
      })
      this.SettingsDivider()
      this.AuthActionRow('关注用户', '', () => {
        this.ns.pushPathByName('AccountFollowing', null)
      })
      this.SettingsDivider()
      this.AuthActionRow('屏蔽与忽略', '', () => {
        this.ns.pushPathByName('AccountBlacklist', null)
      })
    }
  }

  @Builder
  ApiDiagnosticsSection() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('Personal Access Token')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('已保存，仅用于 V2EX API v2 高级能力')
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
        this.TokenSummary()
      }

      if (this.hasApiRateLimitSnapshot()) {
        this.SettingsDivider()
        this.RateLimitSummary()
      }

      this.SettingsDivider()
      Row() {
        Text('清除 API 授权')
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
        title: '稍后读',
        count: this.savedTopicCount,
        action: () => {
          this.ns.pushPathByName('SavedTopics', null)
        }
      })
      this.SettingsDivider()
      ConciseListRow({
        title: '最近浏览',
        count: this.viewedTopicCount,
        action: () => {
          this.ns.pushPathByName('ViewedTopics', null)
        }
      })
      this.SettingsDivider()
      ConciseListRow({
        title: '本地关注节点',
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
      title: '搜索', action: () => {
        this.ns.pushPathByName('Search', null)
      }
    })
  }

  @Builder
  TopicDraftEntryRow() {
    ConciseListRow({
      title: '发帖草稿', action: () => {
        this.ns.pushPathByName('TopicEditor', null)
      }
    })
  }

  @Builder
  StorageSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '关于 Next2V',
        action: () => {
          this.ns.pushPathByName('About', null)
        }
      })
    }
  }

  private hasCookieAccount(): boolean {
    return this.authCookieConfigured
  }

  private formatCoinAmount(amount: number): string {
    if (amount > 0 && amount < 1) {
      return amount.toFixed(2)
    }
    return `${amount}`
  }

  private currentUsername(): string {
    return this.sessionUsername || this.authProfile?.username || this.storedUsername || ''
  }

  private currentAvatar(): string {
    return this.sessionAvatar || this.authProfile?.avatar_normal || this.authProfile?.avatar_large || ''
  }

  private accountMetaText(): string {
    if (!this.hasCookieAccount()) {
      if (this.authTokenConfigured) {
        return 'API 授权已配置'
      }
      return ''
    }
    if (this.accountBalance) {
      return this.accountBalance.summary
    }
    if (this.isAccountMetaLoading) {
      return '虚拟币同步中'
    }
    if (this.accountMetaError) {
      return '虚拟币信息不可用'
    }
    return ''
  }

  private dailyMissionButtonText(): string {
    if (this.isDailyRedeeming) {
      return '签到中'
    }
    if (this.dailyMission && !this.dailyMission.canRedeem) {
      return '已签到'
    }
    return '签到'
  }

  private dailyMissionEnabled(): boolean {
    return this.hasCookieAccount() &&
      !this.isAccountMetaLoading && !this.isDailyRedeeming &&
      (!this.dailyMission || this.dailyMission.canRedeem)
  }

  private profileTagline(): string {
    return this.authProfile?.tagline || ''
  }

  private profileLocation(): string {
    return this.authProfile?.location || ''
  }

  private profileCreatedAt(): number {
    return this.authProfile?.created || 0
  }

  private tokenScope(): string {
    return this.tokenInfo?.scope || ''
  }

  private tokenExpiration(): number {
    return this.tokenInfo?.expiration || 0
  }

  private tokenLastUsed(): number {
    return this.tokenInfo?.last_used || 0
  }

  private hasApiRateLimitSnapshot(): boolean {
    return this.apiRateLimitLimit > 0 || this.apiRateLimitUpdatedAt > 0 || this.apiRateLimitReset > 0
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
    CookieJarSettings.clear(context)
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
      title: '清除 API 授权',
      message: '仅清除本地保存的 Personal Access Token，不会退出网页登录。',
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
    CollectionSettings.loadSavedTopics(context)
      .then((items: SavedTopic[]) => {
        this.savedTopics = items
        this.savedTopicCount = items.length
      })
      .catch((error: Error) => {
        console.error('load saved topics failed: ' + error.message)
      })
  }

  private loadSavedNodes(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedNodes(context)
      .then((items: SavedNode[]) => {
        this.savedNodes = items
        this.savedNodeCount = items.length
      })
      .catch((error: Error) => {
        console.error('load saved nodes failed: ' + error.message)
      })
  }

  private loadViewedTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadViewedTopics(context)
      .then((items: ViewedTopic[]) => {
        this.viewedTopics = items
        this.viewedTopicCount = items.length
      })
      .catch((error: Error) => {
        console.error('load viewed topics failed: ' + error.message)
      })
  }

  private loadTopicReadStates(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.syncTopicReadStates(context)
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
    CollectionSettings.loadLocalContentStats(context)
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
