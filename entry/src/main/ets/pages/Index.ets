import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController, HdsTabsFloatingStyle,
  hdsMaterial, HdsNavigationTitleMode, ScrollEffectType, BlurStrategy
} from '@kit.UIDesignKit'
import { common } from '@kit.AbilityKit'
import {
  HttpClient, ThemeConstants, StorageKeys, ApiConstants, TabItem,
  AuthSettings, ApiService, ApiV2Service, DateUtils, CollectionSettings, TopicDetailParams, ImagePreviewParams, UserProfileParams,
  CookieJarSettings, AuthSessionSettings, V2exSessionParser, LoadingFooter, NotificationSettings, SecondaryListScaffold,
  Avatar
}
  from 'shared'
import type {
  V2exAuthenticatedMember, V2exNotification, SavedTopic, SavedNode, ViewedTopic, V2exBalance, V2exDailyMission
} from 'shared'
import type { V2exTokenInfo } from 'shared'
import { HomePage } from 'feed'
import { ReplyEditorPage, TopicDetailPage } from 'detail'
import { DiscoverPage, NodePickerPage, NodeTopicPage } from 'node'
import { UserProfilePage } from 'user'
import { SettingsPage } from 'settings'
import { ComponentContent, promptAction } from '@kit.ArkUI'
import { V2exWebLoginPage } from './V2exWebLoginPage'
import { V2exNativeLoginPage } from './V2exNativeLoginPage'
import { ImagePreviewPage } from './ImagePreviewPage'
import { SearchPage } from './SearchPage'
import { TopicEditorPage } from './TopicEditorPage'

@Component
struct CoinIconCanvas {
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

    ctx.fillStyle = 'rgba(255,255,255,0.16)'
    ctx.beginPath()
    ctx.arc(5.8, 5.2, 2.8, 0, Math.PI * 2)
    ctx.fill()

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
    ctx.lineWidth = 1
    ctx.strokeStyle = 'rgba(255,255,255,0.42)'
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(8, 8, 6.9, 0, Math.PI * 2)
    ctx.lineWidth = 1.2
    ctx.strokeStyle = this.rimColor
    ctx.stroke()
  }
}

@Component
struct FeedPills {
  @StorageLink('feedTab') feedTab: string = 'tech'

  build() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_XS }) {
        ForEach(ApiConstants.TAB_ITEMS, (tab: TabItem) => {
          Column({ space: 2 }) {
            Text(tab.label)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(this.feedTab === tab.key ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_SECONDARY)
              .fontWeight(this.feedTab === tab.key ? FontWeight.Medium : FontWeight.Regular)
              .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })
            if (this.feedTab === tab.key) {
              Divider().strokeWidth(2).color(ThemeConstants.BRAND_PRIMARY).width(18)
            }
          }
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: ThemeConstants.SPACE_XS })
          .onClick(() => { this.feedTab = tab.key })
        })
      }
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      .alignItems(VerticalAlign.Center).height('100%')
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width('100%').height('100%')
  }
}

@Builder
function PillCCBuilder() { FeedPills() }

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack()
  private tc: HdsTabsController = new HdsTabsController()
  private tabTitles: string[] = ['首页', '发现', '通知', '我的']
  @State ct: number = 0
  @StorageLink(StorageKeys.AUTH_TOKEN_CONFIGURED) authTokenConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) authCookieConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_USERNAME) storedUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) sessionUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_AVATAR) sessionAvatar: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_VALIDATED_AT) sessionValidatedAt: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_LIMIT) apiRateLimitLimit: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_REMAINING) apiRateLimitRemaining: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_RESET) apiRateLimitReset: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_UPDATED_AT) apiRateLimitUpdatedAt: number = 0
  @StorageLink(StorageKeys.LOCAL_DATA_UPDATED_AT) @Watch('onLocalDataUpdated') localDataUpdatedAt: number = 0
  @State private authToken: string = ''
  @State private tokenDraft: string = ''
  @State private authProfile: V2exAuthenticatedMember | null = null
  @State private tokenInfo: V2exTokenInfo | null = null
  @State private tokenInfoError: string = ''
  @State private authError: string = ''
  @State private sessionError: string = ''
  @State private isSessionValidating: boolean = false
  @State private isAuthLoading: boolean = false
  @State private notifications: V2exNotification[] = []
  @State private savedTopics: SavedTopic[] = []
  @State private savedNodes: SavedNode[] = []
  @State private viewedTopics: ViewedTopic[] = []
  @State private notificationError: string = ''
  @State private isNotificationLoading: boolean = false
  @State private isNotificationDeleting: boolean = false
  @State private notificationPage: number = 1
  @State private notificationHasMore: boolean = true
  @State private isNotificationLoadingMore: boolean = false
  @State private notificationCacheUpdatedAt: number = 0
  @State private notificationLoadedFromCache: boolean = false
  @State private accountBalance: V2exBalance | null = null
  @State private dailyMission: V2exDailyMission | null = null
  @State private accountMetaError: string = ''
  @State private isAccountMetaLoading: boolean = false
  @State private isDailyRedeeming: boolean = false
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private readonly NOTIFICATION_PAGE_SIZE: number = 20

  aboutToAppear(): void {
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
    this.loadSavedTopics()
    this.loadSavedNodes()
    this.loadViewedTopics()
    this.loadTopicReadStates()
  }

  onLocalDataUpdated(_propName: string): void {
    this.savedTopics = []
    this.savedNodes = []
    this.viewedTopics = []
    this.resetNotificationState()
    this.loadSavedTopics()
    this.loadSavedNodes()
    this.loadViewedTopics()
    this.loadTopicReadStates()
  }

  @Builder pm(name: string, param: Object) {
    if (name === 'TopicDetail') {
      HdsNavDestination() { TopicDetailPage({ topicId: (param as Record<string, Object>)['topicId'] as number }) }
        .titleBar(this.topicDetailTitleBarOpts())
    } else if (name === 'ImagePreview') {
      HdsNavDestination() { ImagePreviewPage({ url: (param as ImagePreviewParams).url }) }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'NodeTopicList') {
      HdsNavDestination() {
        NodeTopicPage({ nodeName: (param as Record<string, Object>)['nodeName'] as string, nodeTitle: (param as Record<string, Object>)['nodeTitle'] as string })
      }.titleBar(this.navDestTitleBarOpts())
    } else if (name === 'ReplyEditor') {
      HdsNavDestination() {
        ReplyEditorPage({
          topicId: ((param as Record<string, Object>)['topicId'] as number) || 0,
          topicTitle: ((param as Record<string, Object>)['topicTitle'] as string) || ''
        })
      }.titleBar(this.navDestTitleBarOpts('回复'))
    } else if (name === 'UserProfile') {
      HdsNavDestination() { UserProfilePage({ username: (param as Record<string, Object>)['username'] as string }) }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'V2exWebLogin') {
      HdsNavDestination() { V2exWebLoginPage() }
        .titleBar(this.navDestTitleBarOpts('网页登录'))
    } else if (name === 'V2exNativeLogin') {
      HdsNavDestination() { V2exNativeLoginPage() }
        .titleBar(this.navDestTitleBarOpts('账号密码登录'))
    } else if (name === 'NodePicker') {
      HdsNavDestination() { NodePickerPage() }
        .titleBar(this.navDestTitleBarOpts('选择节点'))
    } else if (name === 'Search') {
      HdsNavDestination() { SearchPage() }
        .titleBar(this.navDestTitleBarOpts('搜索'))
    } else if (name === 'TopicEditor') {
      HdsNavDestination() { TopicEditorPage() }
        .titleBar(this.navDestTitleBarOpts('发帖草稿'))
    } else if (name === 'Settings') {
      HdsNavDestination() { SettingsPage() }
        .titleBar(this.navDestTitleBarOpts('设置'))
    } else if (name === 'Account') {
      HdsNavDestination() { this.AccountPage() }
        .titleBar(this.navDestTitleBarOpts('账号'))
    } else if (name === 'SavedTopics') {
      HdsNavDestination() { this.SavedTopicsPage() }
        .titleBar(this.navDestTitleBarOpts('稍后读'))
    } else if (name === 'ViewedTopics') {
      HdsNavDestination() { this.ViewedTopicsPage() }
        .titleBar(this.navDestTitleBarOpts('最近浏览'))
    } else if (name === 'SavedNodes') {
      HdsNavDestination() { this.SavedNodesPage() }
        .titleBar(this.navDestTitleBarOpts('关注节点'))
    }
  }

  build() {
    HdsNavigation(this.ns) {
      HdsTabs({ controller: this.tc, index: this.ct }) {
        TabContent() { HomePage() }.tabBar(this.TabIcon('首页', 0))
        TabContent() { DiscoverPage() }.tabBar(this.TabIcon('发现', 1))
        TabContent() { this.NotifyPage() }.tabBar(this.TabIcon('通知', 2))
        TabContent() { this.MePage() }.tabBar(this.TabIcon('我的', 3))
      }
        .barOverlap(true).barPosition(BarPosition.End).barMode(BarMode.Fixed)
        .scrollable(false)
        .animationDuration(0)
        .barFloatingStyle({
          barBottomMargin: ThemeConstants.SPACE_XL,
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
        } as HdsTabsFloatingStyle)
        .onChange((i: number) => {
          this.ct = i
          if (i === 2) {
            this.loadNotifications()
          } else if (i === 3) {
            this.validateCookieSession()
            this.loadAccountMeta()
            this.loadSavedTopics()
            this.loadSavedNodes()
            this.loadViewedTopics()
          }
        })
    }
      .titleBar(this.titleBarOptions())
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .navDestination(this.pm).mode(NavigationMode.Stack).width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private navDestTitleBarOpts(title?: string, menu?: Record<string, Object>): Record<string, Object> {
    let mat: Record<string, Object> = { 'materialType': hdsMaterial.MaterialType.ADAPTIVE, 'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE }
    let scrollOpts: Record<string, Object> = { 'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR }
    let style: Record<string, Object> = { 'systemMaterialEffect': mat, 'scrollEffectOpts': scrollOpts }
    if (title || menu) {
      let content: Record<string, Object> = {}
      if (menu) {
        content['menu'] = menu
      }
      if (!title) {
        return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'blurStrategy': BlurStrategy.ENABLE, 'content': content, 'style': style }
      }
      let titleInfo: Record<string, Object> = { 'mainTitle': title }
      content['title'] = titleInfo
      return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'blurStrategy': BlurStrategy.ENABLE, 'content': content, 'style': style }
    }
    return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'blurStrategy': BlurStrategy.ENABLE, 'style': style }
  }

  private topicDetailTitleBarOpts(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('回复', $r('sys.symbol.ellipsis_bubble'), () => { this.sendTopicAction('reply') }),
      this.topicActionItem('稍后读', $r('sys.symbol.star'), () => { this.sendTopicAction('saveLater') }),
      this.topicActionItem('复制标题', $r('sys.symbol.doc_plaintext'), () => { this.sendTopicAction('copyTitle') }),
      this.topicActionItem('复制链接', $r('sys.symbol.plus_square_on_square'), () => { this.sendTopicAction('copyLink') }),
      this.topicActionItem('分享链接', $r('sys.symbol.share'), () => { this.sendTopicAction('share') }),
      this.topicActionItem('浏览器打开', $r('sys.symbol.search_things'), () => { this.sendTopicAction('openBrowser') })
    ]
    let menu: Record<string, Object> = { 'value': items, 'maxCount': 3 }
    return this.navDestTitleBarOpts(undefined, menu)
  }

  private sendTopicAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_ACTION, `${Date.now()}:${action}`)
  }

  private topicActionItem(label: string, icon: Resource, action: () => void): Record<string, Object> {
    let content: Record<string, Object> = {
      'label': label,
      'icon': icon,
      'isEnabled': true,
      'action': action
    }
    return { 'content': content }
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': this.tabTitles[this.ct] }
    let content: Record<string, Object>
    if (this.ct === 0) {
      let cc = new ComponentContent(this.getUIContext(), wrapBuilder(PillCCBuilder))
      let bb: Record<string, Object> = { 'builderComponent': cc, 'height': ApiConstants.TAB_BAR_HEIGHT, 'showType': 0 }
      content = { 'title': titleInfo, 'bottomBuilder': bb }
    } else {
      content = { 'title': titleInfo }
    }
    if (this.tabTitles[this.ct] === '我的') {
      content['menu'] = this.meTitleMenu()
    } else {
      let emptyMenu: Record<string, Object> = { 'value': [], 'maxCount': 0 }
      content['menu'] = emptyMenu
    }
    let mat: Record<string, Object> = { 'materialType': hdsMaterial.MaterialType.ADAPTIVE, 'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE }
    let scrollOpts: Record<string, Object> = { 'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR }
    let style: Record<string, Object> = { 'systemMaterialEffect': mat, 'scrollEffectOpts': scrollOpts }
    return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'blurStrategy': BlurStrategy.ENABLE, 'content': content, 'style': style }
  }

  private meTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('设置', $r('sys.symbol.gearshape'), () => { this.ns.pushPathByName('Settings', null) })
    ]
    return { 'value': items, 'maxCount': 1 }
  }

  @Builder TabIcon(title: string, idx: number) {
    Column() {
      SymbolGlyph(idx === 0 ? $r('sys.symbol.house_fill')
        : idx === 1 ? $r('sys.symbol.square_fill_grid_2x2')
        : idx === 2 ? $r('sys.symbol.bell_fill')
        : $r('sys.symbol.person_fill'))
        .fontSize(ThemeConstants.INDICATOR_SIZE - 6).renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .fontColor([this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary')])
      Text(title).fontSize(ThemeConstants.FONT_SIZE_TINY).fontColor(this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary'))
    }
      .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center).width('100%').height('100%')
      .padding({ top: ThemeConstants.SPACE_SM - 2, bottom: ThemeConstants.SPACE_XS })
  }

  // NotifyPage 和 MePage 较为简单，保留在 Index 文件内
  @StorageProp('topAvoidHeight') topH: number = 0
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT

  @Builder NotifyPage() {
    Column() {
      if (!this.hasNotificationAuth()) {
        this.AuthRequiredView('登录后可查看通知')
      } else if (this.isNotificationLoading && this.notifications.length === 0) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE)
          .height(ThemeConstants.LOADING_SIZE)
      } else if (this.notificationError && this.notifications.length === 0) {
        this.NotificationErrorView()
      } else {
        List({ space: ThemeConstants.SPACE_SM }) {
          ListItem() { Column() { Blank().height(this.topH + this.TBH) } }
          ListItem() { this.NotificationSummaryRow() }
            .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
          ForEach(this.notifications, (item: V2exNotification) => {
            ListItem() { this.NotificationCard(item) }
              .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
              .onClick(() => {
                const topicId = item.topic_id || 0
                if (topicId > 0) {
                  let p: TopicDetailParams = { topicId: topicId }
                  this.ns.pushPathByName('TopicDetail', p as Object)
                }
              })
              .swipeAction({ end: this.NotificationSwipeEnd(item) })
          })
          if (this.notifications.length === 0) {
            ListItem() { this.EmptyNoticeView() }
          }
          if (this.notifications.length > 0) {
            ListItem() {
              LoadingFooter({ isLoading: this.isNotificationLoadingMore, hasMore: this.notificationHasMore })
            }
              .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
          }
          ListItem() { Column() { Blank().height(this.bottomH + this.FLOAT_H) } }
        }
        .onReachEnd(() => {
          this.loadMoreNotifications()
        })
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
    }
      .justifyContent(FlexAlign.Center)
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder MePage() {
    Column() {
      List({ space: ThemeConstants.SPACE_SM }) {
        ListItem() {
          Column() {
            Blank().height(this.TBH + ThemeConstants.SPACE_XL + ThemeConstants.SPACE_LG)
          }
          .width('100%')
        }

        ListItem() {
          this.SectionHeader('账号')
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.AuthSection()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })

        ListItem() {
          this.SectionHeader('本地内容')
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.LocalContentSection()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })

        ListItem() {
          this.SectionHeader('更多')
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.StorageSection()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })

        ListItem() {
          Column() {
            Blank().height(this.bottomH + this.FLOAT_H + ThemeConstants.SPACE_MD)
          }
          .width('100%')
        }
      }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .width('100%')
        .height('100%')
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private hasNotificationAuth(): boolean {
    return (this.authTokenConfigured && !!this.authToken) || (this.authCookieConfigured && !!CookieJarSettings.getCurrentCookie())
  }

  private loginStatusText(): string {
    if (this.authCookieConfigured) {
      return '已登录'
    }
    if (this.authTokenConfigured) {
      return 'Token 已配置'
    }
    return '未登录'
  }

  private loginStatusColor(): ResourceColor {
    if (this.authCookieConfigured || this.authTokenConfigured) {
      return ThemeConstants.BRAND_PRIMARY
    }
    return $r('sys.color.font_secondary')
  }

  private currentUsername(): string {
    return this.sessionUsername || this.authProfile?.username || this.storedUsername || ''
  }

  private currentAvatar(): string {
    return this.sessionAvatar || this.authProfile?.avatar_normal || this.authProfile?.avatar_large || ''
  }

  private accountMetaText(): string {
    if (this.accountBalance) {
      return this.accountBalance.summary
    }
    if (this.isAccountMetaLoading) {
      return '虚拟币同步中'
    }
    if (this.accountMetaError) {
      return '虚拟币信息不可用'
    }
    return '金币 0 · 银币 0 · 铜币 0'
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
    return this.authCookieConfigured && !!CookieJarSettings.getCurrentCookie() &&
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
      .then((snapshot) => {
        this.loadNotificationCache(snapshot.username)
      })
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
    this.http.getTextWithHeaders('/settings', headers)
      .then((html: string) => {
        const username = V2exSessionParser.extractUsername(html)
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
            }).then(() => {
              this.loadNotificationCache(username)
              this.loadAccountMeta(true)
              if (this.ct === 2) {
                this.loadNotifications(true)
              }
            })
          })
      })
      .catch((error: Error) => {
        this.sessionError = error.message || 'Web 会话验证失败'
      })
      .finally(() => {
        this.isSessionValidating = false
      })
  }

  @Builder SectionHeader(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: ThemeConstants.SPACE_XS })
      .width('100%')
  }

  @Builder SettingsDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.ohos_id_color_list_separator'))
      .margin({ left: ThemeConstants.SPACE_LG })
  }

  @Builder CoinBalance() {
    if (this.accountBalance) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        if (this.accountBalance.gold > 0) {
          this.CoinAmount('#B97818', '#F6D77A', '#D59A24', this.accountBalance.gold)
        }
        if (this.accountBalance.silver > 0) {
          this.CoinAmount('#7E8994', '#EEF3F7', '#A8B1BC', this.accountBalance.silver)
        }
        this.CoinAmount('#7E4B27', '#D99B65', '#A66B3D', this.accountBalance.bronze)
      }
      .alignItems(VerticalAlign.Center)
      .height(22)
    } else {
      Text(this.accountMetaText())
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  @Builder CoinAmount(rimColor: string, faceColor: string, edgeColor: string, amount: number) {
    Row({ space: 4 }) {
      CoinIconCanvas({ rimColor, faceColor, edgeColor })
      Text(`${amount}`)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder AuthSection() {
    Column() {
      if (!this.authCookieConfigured && !this.authTokenConfigured) {
        this.AuthActionRow('未登录', '点击登录 V2EX', () => { this.ns.pushPathByName('V2exNativeLogin', null) })
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
            .backgroundColor(this.dailyMissionEnabled() ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
            .enabled(this.dailyMissionEnabled())
            .onClick(() => { this.redeemDailyMission() })

          Text('›')
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')
        .padding(ThemeConstants.SPACE_LG)
        .onClick(() => { this.ns.pushPathByName('Account', null) })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder AccountPage() {
    Column() {
      List({ space: ThemeConstants.SPACE_SM }) {
        ListItem() { Column() { Blank().height(this.topH + this.TBH + ThemeConstants.SPACE_MD) } }

        ListItem() {
          Column({ space: ThemeConstants.SPACE_MD }) {
            Avatar({ url: this.currentAvatar(), avatarSize: 72 })
            Text(this.currentUsername() || 'V2EX 用户')
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            this.CoinBalance()
            if (this.dailyMission) {
              Text(this.dailyMission.message)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor($r('sys.color.font_secondary'))
            }
            if (this.sessionError) {
              Text(this.sessionError)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor(Color.Red)
            }
            if (this.accountMetaError) {
              Text(this.accountMetaError)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor(Color.Red)
            }
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .padding(ThemeConstants.SPACE_LG)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
        .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })

        ListItem() {
          Column() {
            this.AuthActionRow('查看个人主页', '打开 V2EX 个人资料页', () => {
              const username = this.currentUsername()
              if (username) {
                let p: UserProfileParams = { username: username }
                this.ns.pushPathByName('UserProfile', p as Object)
              }
            })
            this.SettingsDivider()
            this.AuthActionRow('重新登录', '账号密码登录或切换到网页登录', () => { this.ns.pushPathByName('V2exNativeLogin', null) })
            this.SettingsDivider()
            Row() {
              Text('退出登录')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.Red)
                .layoutWeight(1)
              Text('›')
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .padding(ThemeConstants.SPACE_LG)
            .onClick(() => { this.logoutAll(); this.ns.pop() })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
        .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })

        ListItem() { Column() { Blank().height(this.bottomH + ThemeConstants.SPACE_MD) } }
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder AuthActionRow(title: string, subtitle: string, action: () => void) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(title)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(subtitle)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
    .onClick(action)
  }

  @Builder ProfileSummary() {
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

  @Builder TokenSummary() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.tokenScope()) {
        Text(`Token Scope: ${this.tokenScope()}`)
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

  @Builder RateLimitSummary() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(`API Rate Limit: ${this.apiRateLimitRemaining} / ${this.apiRateLimitLimit}`)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
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

  @Builder StatusText(message: string, isError: boolean) {
    Text(message)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(isError ? Color.Red : $r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
  }

  @Builder LocalContentSection() {
    Column() {
      this.SearchEntryRow()
      this.SettingsDivider()
      this.TopicDraftEntryRow()
      this.SettingsDivider()
      this.LocalNavigationRow('稍后读', '主题详情页保存的主题', this.savedTopics.length, () => {
        this.ns.pushPathByName('SavedTopics', null)
      })
      this.SettingsDivider()
      this.LocalNavigationRow('最近浏览', '打开主题详情后自动记录', this.viewedTopics.length, () => {
        this.ns.pushPathByName('ViewedTopics', null)
      })
      this.SettingsDivider()
      this.LocalNavigationRow('关注节点', '节点主题页关注的节点', this.savedNodes.length, () => {
        this.ns.pushPathByName('SavedNodes', null)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder SearchEntryRow() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text('搜索')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('本地数据 / 节点库 / 网页搜索')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .onClick(() => { this.ns.pushPathByName('Search', null) })
  }

  @Builder TopicDraftEntryRow() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text('发帖草稿')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('编辑/预览新主题草稿，不会直接提交')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .onClick(() => { this.ns.pushPathByName('TopicEditor', null) })
  }

  @Builder LocalNavigationRow(title: string, subtitle: string, count: number, action: () => void) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(subtitle)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Row({ space: ThemeConstants.SPACE_XS }) {
        Text(`${count}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
        Text('›')
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
    .onClick(action)
  }

  @Builder SavedTopicsPage() {
    SecondaryListScaffold() {
      if (this.savedTopics.length === 0) {
        ListItem() { this.LocalEmptyView('还没有稍后读主题') }
      } else {
        ForEach(this.savedTopics, (item: SavedTopic) => {
          ListItem() {
            this.LocalTopicRow(item.title, item.nodeTitle, item.nodeName, item.username, item.savedAt, '保存于')
          }
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.ns.pushPathByName('TopicDetail', p as Object)
          })
        }, (item: SavedTopic) => `saved-${item.id}`)
      }
    }
  }

  @Builder ViewedTopicsPage() {
    SecondaryListScaffold() {
      if (this.viewedTopics.length === 0) {
        ListItem() { this.LocalEmptyView('还没有最近浏览记录') }
      } else {
        ForEach(this.viewedTopics, (item: ViewedTopic) => {
          ListItem() {
            this.LocalTopicRow(item.title, item.nodeTitle, item.nodeName, item.username, item.viewedAt, '浏览于')
          }
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.ns.pushPathByName('TopicDetail', p as Object)
          })
        }, (item: ViewedTopic) => `viewed-${item.id}`)
      }
    }
  }

  @Builder SavedNodesPage() {
    SecondaryListScaffold() {
      if (this.savedNodes.length === 0) {
        ListItem() { this.LocalEmptyView('还没有关注节点') }
      } else {
        ForEach(this.savedNodes, (item: SavedNode) => {
          ListItem() {
            this.LocalNodeRow(item)
          }
          .onClick(() => {
            let p: Record<string, Object> = { 'nodeName': item.name, 'nodeTitle': item.title }
            this.ns.pushPathByName('NodeTopicList', p as Object)
          })
        }, (item: SavedNode) => `node-${item.name}`)
      }
    }
  }

  @Builder LocalTopicRow(title: string, nodeTitle: string, nodeName: string, username: string, timestamp: number, prefix: string) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(nodeTitle || nodeName)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.ohos_id_color_activated'))
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 2, bottom: 2 })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        Text(username)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${prefix} ${DateUtils.toDateString(timestamp)}`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder LocalNodeRow(item: SavedNode) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title || item.name)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(`${item.name} · ${item.topics} 个主题 · 关注于 ${DateUtils.toDateString(item.savedAt)}`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder LocalEmptyView(message: string) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      SymbolGlyph($r('sys.symbol.doc_text'))
        .fontSize(42)
        .fontColor([$r('sys.color.font_secondary')])
      Text(message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(220)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder StorageSection() {
    Column() {
      Row() {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('关于 Next2V')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('版本 0.1.0')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder AuthRequiredView(message: string) {
    Column() {
      Text(message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去我的页面配置')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.tc.changeIndex(3) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder NotificationErrorView() {
    Column() {
      Text(this.notificationError)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.loadNotifications(true) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder EmptyNoticeView() {
    Column() {
      Text('暂无通知')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder NotificationSummaryRow() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(`${this.notifications.length} 条通知`)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        if (this.notificationError && this.notifications.length > 0) {
          Text(this.notificationError)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.notificationCacheUpdatedAt > 0) {
          Text(`缓存于 ${DateUtils.toDateString(this.notificationCacheUpdatedAt)}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('刷新')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .height(ThemeConstants.TOUCH_TARGET_SM)
        .type(ButtonType.Normal)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .enabled(!this.isNotificationLoading && !this.isNotificationLoadingMore)
        .onClick(() => { this.loadNotifications(true) })

      Button('批量清除')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .height(ThemeConstants.TOUCH_TARGET_SM)
        .type(ButtonType.Normal)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .enabled(false)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder NotificationCard(item: V2exNotification) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(this.notificationTitle(item))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.notificationBody(item))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.created) {
        Text(DateUtils.toDateString(item.created))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder NotificationSwipeEnd(item: V2exNotification) {
    Row() {
      Button('删除')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(40)
        .fontColor(Color.White)
        .backgroundColor(Color.Red)
        .onClick(() => { this.confirmDeleteNotification(item) })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }

  private confirmDeleteNotification(item: V2exNotification): void {
    const id = item.id || 0
    if (id <= 0 || this.isNotificationDeleting) {
      return
    }
    AlertDialog.show({
      title: '删除通知',
      message: '确定删除这条通知吗？',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: () => { this.deleteNotification(id) }
      }
    })
  }

  private deleteNotification(notificationId: number): void {
    if (!this.authTokenConfigured || !this.authToken || this.isNotificationDeleting) {
      promptAction.openToast({ message: '删除通知需要 V2 API 授权' }).catch((_error: Error) => { })
      return
    }
    this.isNotificationDeleting = true
    this.apiV2.deleteNotification(this.authToken, notificationId)
      .then(() => {
        this.notifications = this.notifications.filter(item => item.id !== notificationId)
        this.saveNotificationCache()
        promptAction.openToast({ message: '已删除' }).catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '删除失败' }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isNotificationDeleting = false
      })
  }

  private loadAuthSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.storedUsername = snapshot.username
        this.tokenDraft = ''
        if (snapshot.token) {
          this.loadNotificationCache(snapshot.username)
          this.refreshAuthProfile(snapshot.token)
          this.refreshTokenInfo(snapshot.token)
        }
      })
      .catch((error: Error) => {
        this.authError = error.message
      })
  }

  private verifyAndSaveToken(): void {
    const token = this.tokenDraft.trim() || this.authToken
    if (!token) {
      this.authError = '请输入 Personal Access Token'
      return
    }
    this.isAuthLoading = true
    this.authError = ''
    this.api.getAuthenticatedMember(token)
      .then((profile: V2exAuthenticatedMember) => {
        const username = profile.username || ''
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        this.authProfile = profile
        this.authToken = token
        this.storedUsername = username
        this.resetNotificationState()
        return AuthSettings.saveToken(context, token, username)
      })
      .then(() => {
        this.tokenDraft = ''
        this.refreshTokenInfo(token)
        this.loadNotifications(true)
      })
      .catch((error: Error) => {
        this.authError = error.message || 'Token 验证失败'
      })
      .finally(() => {
        this.isAuthLoading = false
      })
  }

  private refreshAuthProfile(token: string): void {
    this.api.getAuthenticatedMember(token)
      .then((profile: V2exAuthenticatedMember) => {
        this.authProfile = profile
        this.storedUsername = profile.username || this.storedUsername
        this.loadNotificationCache(this.storedUsername)
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

  private clearAuth(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.clear(context)
      .then(() => NotificationSettings.clearCache(context).catch((error: Error) => {
        this.notificationError = error.message || '清除通知缓存失败'
      }))
      .then(() => {
        this.authToken = ''
        this.tokenDraft = ''
        this.authProfile = null
        this.tokenInfo = null
        this.tokenInfoError = ''
        this.authError = ''
        this.accountBalance = null
        this.dailyMission = null
        this.accountMetaError = ''
        this.resetNotificationState()
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
      AuthSettings.clear(context).catch((error: Error) => { this.authError = error.message || '清除 Token 失败' }),
      AuthSessionSettings.clear(context).catch((error: Error) => { this.sessionError = error.message || '清除会话失败' }),
      CookieJarSettings.clear(context).catch((error: Error) => { this.sessionError = error.message || '清除 Cookie 失败' }),
      NotificationSettings.clearCache(context).catch((error: Error) => { this.notificationError = error.message || '清除通知缓存失败' })
    ])
      .finally(() => {
        this.authToken = ''
        this.tokenDraft = ''
        this.authProfile = null
        this.tokenInfo = null
        this.tokenInfoError = ''
        this.accountBalance = null
        this.dailyMission = null
        this.accountMetaError = ''
        this.resetNotificationState()
      })
  }

  private loadAccountMeta(force: boolean = false): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!this.authCookieConfigured || !cookie || this.isAccountMetaLoading) {
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
        this.accountMetaError = error.message || '读取账号信息失败'
      })
      .finally(() => {
        this.isAccountMetaLoading = false
      })
  }

  private redeemDailyMission(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!this.authCookieConfigured || !cookie || this.isDailyRedeeming) {
      return
    }
    if (!this.dailyMission || !this.dailyMission.canRedeem || !this.dailyMission.redeemPath) {
      promptAction.openToast({ message: '今日已签到' }).catch((_error: Error) => { })
      return
    }
    this.isDailyRedeeming = true
    this.accountMetaError = ''
    this.api.redeemDailyMissionWithCookie(cookie, this.dailyMission.redeemPath)
      .then((mission: V2exDailyMission) => {
        this.dailyMission = mission
        promptAction.openToast({ message: mission.message || '签到完成' }).catch((_error: Error) => { })
        this.loadAccountMeta(true)
      })
      .catch((error: Error) => {
        this.accountMetaError = error.message || '签到失败'
        promptAction.openToast({ message: this.accountMetaError }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isDailyRedeeming = false
      })
  }

  private loadNotifications(force: boolean = false): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if ((!this.authTokenConfigured || !this.authToken) && (!this.authCookieConfigured || !cookie)) {
      return
    }
    if (this.isNotificationLoading || this.isNotificationLoadingMore) {
      return
    }
    if (this.notifications.length > 0 && !force && !this.notificationLoadedFromCache) {
      return
    }
    this.isNotificationLoading = true
    this.notificationError = ''
    this.notificationPage = 1
    this.notificationHasMore = true
    const request = this.authTokenConfigured && this.authToken
      ? this.api.getNotifications(this.authToken, 1)
      : this.api.getNotificationsWithCookie(cookie, 1)
    request
      .then((items: V2exNotification[]) => {
        this.notifications = items
        this.notificationPage = 1
        this.notificationHasMore = items.length >= this.NOTIFICATION_PAGE_SIZE
        this.notificationLoadedFromCache = false
        this.saveNotificationCache()
      })
      .catch((error: Error) => {
        this.notificationError = error.message || '通知加载失败'
        this.notificationHasMore = false
      })
      .finally(() => {
        this.isNotificationLoading = false
      })
  }

  private loadMoreNotifications(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if ((!this.authTokenConfigured || !this.authToken) && (!this.authCookieConfigured || !cookie)) {
      return
    }
    if (this.isNotificationLoading || this.isNotificationLoadingMore || !this.notificationHasMore) {
      return
    }
    const nextPage = this.notificationPage + 1
    this.isNotificationLoadingMore = true
    this.notificationError = ''
    const request = this.authTokenConfigured && this.authToken
      ? this.api.getNotifications(this.authToken, nextPage)
      : this.api.getNotificationsWithCookie(cookie, nextPage)
    request
      .then((items: V2exNotification[]) => {
        if (!items || items.length === 0) {
          this.notificationHasMore = false
          return
        }
        const existing = new Set<number>(this.notifications.map(item => item.id))
        const unique = items.filter(item => item && item.id > 0 && !existing.has(item.id))
        if (unique.length === 0) {
          this.notificationHasMore = false
          return
        }
        this.notifications = this.notifications.concat(unique)
        this.notificationPage = nextPage
        this.notificationHasMore = items.length >= this.NOTIFICATION_PAGE_SIZE
        this.notificationLoadedFromCache = false
        this.saveNotificationCache()
      })
      .catch((error: Error) => {
        this.notificationError = error.message || '加载更多失败'
        this.notificationHasMore = false
      })
      .finally(() => {
        this.isNotificationLoadingMore = false
      })
  }

  private resetNotificationState(): void {
    this.notifications = []
    this.notificationError = ''
    this.isNotificationLoading = false
    this.notificationPage = 1
    this.notificationHasMore = true
    this.isNotificationLoadingMore = false
    this.notificationCacheUpdatedAt = 0
    this.notificationLoadedFromCache = false
  }

  private loadNotificationCache(username: string): void {
    const ownerKey = this.notificationOwnerKey(username)
    if (!ownerKey || (this.notifications.length > 0 && !this.notificationLoadedFromCache)) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NotificationSettings.loadCache(context, ownerKey)
      .then((snapshot) => {
        this.notificationCacheUpdatedAt = snapshot.updatedAt
        if (snapshot.items.length === 0 || (this.notifications.length > 0 && !this.notificationLoadedFromCache)) {
          return
        }
        this.notifications = snapshot.items
        this.notificationPage = snapshot.page
        this.notificationHasMore = snapshot.hasMore
        this.notificationLoadedFromCache = true
      })
      .catch((error: Error) => {
        console.error('load notification cache failed: ' + error.message)
      })
  }

  private saveNotificationCache(): void {
    const ownerKey = this.notificationOwnerKey('')
    if (!ownerKey) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NotificationSettings.saveCache(context, ownerKey, this.notifications, this.notificationPage, this.notificationHasMore)
      .then((snapshot) => {
        this.notificationCacheUpdatedAt = snapshot.updatedAt
      })
      .catch((error: Error) => {
        console.error('save notification cache failed: ' + error.message)
      })
  }

  private notificationOwnerKey(username: string): string {
    let owner = username.trim()
    if (!owner) {
      owner = (this.storedUsername || '').trim()
    }
    if (!owner) {
      owner = (this.sessionUsername || '').trim()
    }
    if (!owner && this.authProfile) {
      owner = (this.authProfile.username || '').trim()
    }
    return owner ? 'member:' + owner : ''
  }

  private loadSavedTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedTopics(context)
      .then((items: SavedTopic[]) => {
        this.savedTopics = items
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

  private notificationTitle(item: V2exNotification): string {
    return item.topic_title || item.title || item.member?.username || '通知'
  }

  private notificationBody(item: V2exNotification): string {
    return item.text || item.content || item.payload || item.content_rendered || item.payload_rendered || ''
  }
}
