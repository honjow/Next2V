import {
  BlurStrategy,
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { common, Want } from '@kit.AbilityKit'
import type {
  SavedNode,
  SavedTopic,
  V2exAuthenticatedMember,
  V2exBalance,
  V2exDailyMission,
  V2exTokenInfo,
  ViewedTopic
} from 'shared'
import {
  ApiConstants,
  ApiService,
  AuthSessionSettings,
  AuthSettings,
  Avatar,
  CollectionSettings,
  ConciseListRow,
  CookieJarSettings,
  DateUtils,
  FeedTabSettings,
  GroupedListSection,
  HttpClient,
  ImagePreviewParams,
  ListDivider as SharedListDivider,
  NotificationSettings,
  NodeTopicListParams,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  StorageKeys,
  TabItem,
  ThemeConstants,
  TopicDetailParams,
  UserProfileParams,
  V2exRoute,
  V2exSessionParser,
  V2exUrlRouter
} from 'shared'
import { HomePage } from 'feed'
import { ReplyEditorPage, TopicDetailPage } from 'detail'
import { DiscoverPage, NodePickerPage, NodeTopicPage } from 'node'
import { UserProfilePage, UserRepliesPage, UserTopicsPage } from 'user'
import { SettingsPage } from 'settings'
import { ComponentContent, promptAction } from '@kit.ArkUI'
import { V2exWebLoginPage } from './V2exWebLoginPage'
import { V2exNativeLoginPage } from './V2exNativeLoginPage'
import { ImagePreviewPage } from './ImagePreviewPage'
import { SearchPage } from './SearchPage'
import { TopicEditorPage } from './TopicEditorPage'
import { MyTopicsPage } from './MyTopicsPage'
import { MyRepliesPage } from './MyRepliesPage'
import { MyNodesPage } from './MyNodesPage'
import { AccountBlacklistPage } from './AccountBlacklistPage'
import { AccountFollowingPage } from './AccountFollowingPage'
import { SavedTopicsPage } from './SavedTopicsPage'
import { ViewedTopicsPage } from './ViewedTopicsPage'
import { SavedNodesPage } from './SavedNodesPage'
import { NotificationPage } from './NotificationPage'

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
  @StorageLink('feedTab') @Watch('onFeedTabChanged') feedTab: string = 'tech'
  @StorageLink(StorageKeys.FEED_TAB_KEYS) @Watch('onFeedTabKeysChanged') feedTabKeys: string = FeedTabSettings.defaultKeysJson()
  @StorageLink(StorageKeys.FEED_TAB_VISUAL_INDEX) feedTabVisualIndex: number = 0
  @State private tabLefts: number[] = []
  @State private tabWidths: number[] = []
  @State private containerGlobalLeft: number = 0
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.feedTabVisualIndex = this.selectedTabIndex()
    this.centerCurrentTab(false)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ space: ThemeConstants.SPACE_XS, scroller: this.scroller }) {
        ForEach(this.visibleTabs(), (tab: TabItem, index: number) => {
          ListItem() {
            Column({ space: 1 }) {
              Text(tab.label)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor(this.visualSelectedIndex() === index ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_SECONDARY)
                .fontWeight(this.visualSelectedIndex() === index ? FontWeight.Medium : FontWeight.Regular)
                .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS })
              Blank().height(2).width(18)
            }
            .alignItems(HorizontalAlign.Center)
            .padding({ bottom: 0 })
            .onClick(() => {
              this.animateVisualTabIndex(index)
              this.feedTab = tab.key
            })
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              this.updateTabLayout(index, newValue)
            })
          }
        })
      }
      .scrollBar(BarState.Off)
      .listDirection(Axis.Horizontal)
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      .width('100%').height('100%')

      Row()
        .width(this.indicatorWidth())
        .height(3)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .borderRadius(1.5)
        .position({ x: this.indicatorLeft(), y: ApiConstants.TAB_BAR_HEIGHT - 14 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%').height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.containerGlobalLeft = this.areaX(newValue?.globalPosition?.x)
    })
  }

  private onFeedTabChanged(_propName: string): void {
    this.animateVisualTabIndex(this.selectedTabIndex())
    this.centerCurrentTab(true)
  }

  private onFeedTabKeysChanged(_propName: string): void {
    const tabs = this.visibleTabs()
    this.tabLefts = []
    this.tabWidths = []
    if (!tabs.find((tab: TabItem) => tab.key === this.feedTab)) {
      this.feedTab = tabs[0].key
    }
    this.feedTabVisualIndex = this.selectedTabIndex()
    this.centerCurrentTab(false)
  }

  private visibleTabs(): TabItem[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedTabKeys)
  }

  private selectedTabIndex(): number {
    const index = this.visibleTabs().findIndex((tab: TabItem) => tab.key === this.feedTab)
    return index < 0 ? 0 : index
  }

  private visualSelectedIndex(): number {
    return Math.max(0, Math.min(this.visibleTabs().length - 1, Math.round(this.feedTabVisualIndex)))
  }

  private animateVisualTabIndex(index: number): void {
    this.getUIContext().animateTo({ duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut }, () => {
      this.feedTabVisualIndex = Math.max(0, Math.min(this.visibleTabs().length - 1, index))
    })
  }

  private updateTabLayout(index: number, area: Area): void {
    const width = (area?.width as number) || 0
    const left = this.areaX(area?.globalPosition?.x) - this.containerGlobalLeft
    if (width <= 0) {
      return
    }
    const nextLefts = this.tabLefts.slice()
    const nextWidths = this.tabWidths.slice()
    nextLefts[index] = left
    nextWidths[index] = width
    this.tabLefts = nextLefts
    this.tabWidths = nextWidths
  }

  private indicatorWidth(): number {
    return 18
  }

  private indicatorLeft(): number {
    const visualIndex = Math.max(0, Math.min(this.visibleTabs().length - 1, this.feedTabVisualIndex))
    const fromIndex = Math.floor(visualIndex)
    const toIndex = Math.min(this.visibleTabs().length - 1, fromIndex + 1)
    const fraction = visualIndex - fromIndex
    const fromCenter = this.tabCenter(fromIndex)
    const toCenter = this.tabCenter(toIndex)
    return fromCenter + (toCenter - fromCenter) * fraction - this.indicatorWidth() / 2
  }

  private tabCenter(index: number): number {
    const left = this.tabLefts[index]
    const width = this.tabWidths[index]
    if (left !== undefined && width !== undefined && width > 0) {
      return left + width / 2
    }
    const fallbackIndex = this.selectedTabIndex()
    const fallbackLeft = this.tabLefts[fallbackIndex]
    const fallbackWidth = this.tabWidths[fallbackIndex]
    if (fallbackLeft !== undefined && fallbackWidth !== undefined && fallbackWidth > 0) {
      return fallbackLeft + fallbackWidth / 2
    }
    return ThemeConstants.SPACE_SM + this.indicatorWidth() / 2
  }

  private areaX(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private centerCurrentTab(smooth: boolean): void {
    this.scroller.scrollToIndex(this.selectedTabIndex(), smooth, ScrollAlign.CENTER)
  }
}

@Builder
function PillCCBuilder() {
  FeedPills()
}

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
  @StorageLink(StorageKeys.AUTH_SESSION_UPDATED_AT) @Watch('onAuthSessionUpdated') authSessionUpdatedAt: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_LIMIT) apiRateLimitLimit: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_REMAINING) apiRateLimitRemaining: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_RESET) apiRateLimitReset: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_UPDATED_AT) apiRateLimitUpdatedAt: number = 0
  @StorageLink(StorageKeys.LOCAL_DATA_UPDATED_AT) @Watch('onLocalDataUpdated') localDataUpdatedAt: number = 0
  @StorageLink(StorageKeys.PENDING_V2EX_URL) @Watch('onPendingV2exUrlChanged') pendingV2exUrl: string = ''
  @State private authToken: string = ''
  @State private tokenDraft: string = ''
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

  aboutToAppear(): void {
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
    this.loadSavedTopics()
    this.loadSavedNodes()
    this.loadViewedTopics()
    this.loadTopicReadStates()
    this.consumePendingV2exUrl()
  }

  onLocalDataUpdated(_propName: string): void {
    this.savedTopics = []
    this.savedNodes = []
    this.viewedTopics = []
    this.loadSavedTopics()
    this.loadSavedNodes()
    this.loadViewedTopics()
    this.loadTopicReadStates()
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

  onPendingV2exUrlChanged(_propName: string): void {
    this.consumePendingV2exUrl()
  }

  @Builder
  pm(name: string, param: Object) {
    if (name === 'TopicDetail') {
      HdsNavDestination() {
        TopicDetailPage({
          topicId: ((param as Record<string, Object>)['topicId'] as number) || 0,
          targetFloor: ((param as Record<string, Object>)['targetFloor'] as number) || 0
        })
      }
      .titleBar(this.topicDetailTitleBarOpts())
    } else if (name === 'ImagePreview') {
      HdsNavDestination() {
        ImagePreviewPage({ url: (param as ImagePreviewParams).url })
      }
      .titleBar(this.navDestTitleBarOpts(undefined, this.imagePreviewTitleMenu()))
    } else if (name === 'NodeTopicList') {
      HdsNavDestination() {
        NodeTopicPage({
          nodeName: (param as Record<string, Object>)['nodeName'] as string,
          nodeTitle: (param as Record<string, Object>)['nodeTitle'] as string
        })
      }.titleBar(this.navDestTitleBarOpts())
    } else if (name === 'ReplyEditor') {
      HdsNavDestination() {
        ReplyEditorPage({
          topicId: ((param as Record<string, Object>)['topicId'] as number) || 0,
          topicTitle: ((param as Record<string, Object>)['topicTitle'] as string) || '',
          initialContent: ((param as Record<string, Object>)['initialContent'] as string) || ''
        })
      }.titleBar(this.navDestTitleBarOpts('回复'))
    } else if (name === 'UserProfile') {
      HdsNavDestination() {
        UserProfilePage({ username: (param as Record<string, Object>)['username'] as string })
      }
      .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'UserTopics') {
      HdsNavDestination() {
        UserTopicsPage({ username: (param as Record<string, Object>)['username'] as string })
      }
      .titleBar(this.navDestTitleBarOpts('全部主题'))
    } else if (name === 'UserReplies') {
      HdsNavDestination() {
        UserRepliesPage({ username: (param as Record<string, Object>)['username'] as string })
      }
      .titleBar(this.navDestTitleBarOpts('全部回复'))
    } else if (name === 'V2exWebLogin') {
      HdsNavDestination() {
        V2exWebLoginPage()
      }
      .titleBar(this.navDestTitleBarOpts('网页登录', this.webLoginTitleMenu()))
    } else if (name === 'V2exNativeLogin') {
      HdsNavDestination() {
        V2exNativeLoginPage()
      }
      .titleBar(this.navDestTitleBarOpts('账号密码登录'))
    } else if (name === 'NodePicker') {
      HdsNavDestination() {
        NodePickerPage()
      }
      .titleBar(this.navDestTitleBarOpts('选择节点'))
    } else if (name === 'Search') {
      HdsNavDestination() {
        SearchPage()
      }
      .titleBar(this.navDestTitleBarOpts('搜索', this.searchTitleMenu()))
    } else if (name === 'TopicEditor') {
      HdsNavDestination() {
        TopicEditorPage()
      }
      .titleBar(this.navDestTitleBarOpts('发帖草稿'))
    } else if (name === 'MyTopics') {
      HdsNavDestination() {
        MyTopicsPage()
      }
      .titleBar(this.navDestTitleBarOpts('收藏主题'))
    } else if (name === 'MyReplies') {
      HdsNavDestination() {
        MyRepliesPage()
      }
      .titleBar(this.navDestTitleBarOpts('我的回复'))
    } else if (name === 'MyNodes') {
      HdsNavDestination() {
        MyNodesPage()
      }
      .titleBar(this.navDestTitleBarOpts('收藏节点'))
    } else if (name === 'AccountBlacklist') {
      HdsNavDestination() {
        AccountBlacklistPage()
      }
      .titleBar(this.navDestTitleBarOpts('屏蔽与忽略'))
    } else if (name === 'AccountFollowing') {
      HdsNavDestination() {
        AccountFollowingPage()
      }
      .titleBar(this.navDestTitleBarOpts('关注与收藏'))
    } else if (name === 'Settings') {
      HdsNavDestination() {
        SettingsPage()
      }
      .titleBar(this.navDestTitleBarOpts('设置'))
    } else if (name === 'Account') {
      HdsNavDestination() {
        this.AccountPage()
      }
      .titleBar(this.navDestTitleBarOpts('账号'))
    } else if (name === 'SavedTopics') {
      HdsNavDestination() {
        SavedTopicsPage()
      }
      .titleBar(this.navDestTitleBarOpts('稍后读'))
    } else if (name === 'ViewedTopics') {
      HdsNavDestination() {
        ViewedTopicsPage()
      }
      .titleBar(this.navDestTitleBarOpts('最近浏览'))
    } else if (name === 'SavedNodes') {
      HdsNavDestination() {
        SavedNodesPage()
      }
      .titleBar(this.navDestTitleBarOpts('关注节点'))
    }
  }

  build() {
    HdsNavigation(this.ns) {
      HdsTabs({ controller: this.tc, index: this.ct }) {
        TabContent() {
          HomePage()
        }.tabBar(this.TabIcon('首页', 0))

        TabContent() {
          DiscoverPage()
        }.tabBar(this.TabIcon('发现', 1))

        TabContent() {
          NotificationPage({
            onOpenAccount: () => {
              this.tc.changeIndex(3)
            }
          })
        }.tabBar(this.TabIcon('通知', 2))

        TabContent() {
          this.MePage()
        }.tabBar(this.TabIcon('我的', 3))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .scrollable(false)
      .animationDuration(0)
      .barFloatingStyle({
        barBottomMargin: ThemeConstants.SPACE_XL,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      } as HdsTabsFloatingStyle)
      .onChange((i: number) => {
        this.ct = i
        if (i === 3) {
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
    .navDestination(this.pm)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private navDestTitleBarOpts(title?: string, menu?: Record<string, Object>): Record<string, Object> {
    let mat: Record<string, Object> =
      { 'materialType': hdsMaterial.MaterialType.ADAPTIVE, 'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE }
    let scrollOpts: Record<string, Object> =
      { 'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR }
    let style: Record<string, Object> = { 'systemMaterialEffect': mat, 'scrollEffectOpts': scrollOpts }
    if (title || menu) {
      let content: Record<string, Object> = {}
      if (menu) {
        content['menu'] = menu
      }
      if (!title) {
        return {
          'avoidLayoutSafeArea': true,
          'enableComponentSafeArea': false,
          'blurStrategy': BlurStrategy.ENABLE,
          'content': content,
          'style': style
        }
      }
      let titleInfo: Record<string, Object> = { 'mainTitle': title }
      content['title'] = titleInfo
      return {
        'avoidLayoutSafeArea': true,
        'enableComponentSafeArea': false,
        'blurStrategy': BlurStrategy.ENABLE,
        'content': content,
        'style': style
      }
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'style': style
    }
  }

  private topicDetailTitleBarOpts(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('回复', $r('sys.symbol.ellipsis_bubble'), () => {
        this.sendTopicAction('reply')
      }),
      this.topicActionItem('稍后读', $r('sys.symbol.star'), () => {
        this.sendTopicAction('saveLater')
      }),
      this.topicActionItem('站内收藏', $r('sys.symbol.heart_fill'), () => {
        this.sendTopicAction('siteFavorite')
      }),
      this.topicActionItem('感谢主题', $r('sys.symbol.heart_fill'), () => {
        this.sendTopicAction('thankTopic')
      }),
      this.topicActionItem('复制标题', $r('sys.symbol.doc_plaintext'), () => {
        this.sendTopicAction('copyTitle')
      }),
      this.topicActionItem('复制链接', $r('sys.symbol.plus_square_on_square'), () => {
        this.sendTopicAction('copyLink')
      }),
      this.topicActionItem('分享链接', $r('sys.symbol.share'), () => {
        this.sendTopicAction('share')
      }),
      this.topicActionItem('浏览器打开', $r('sys.symbol.search_things'), () => {
        this.sendTopicAction('openBrowser')
      })
    ]
    let menu: Record<string, Object> = { 'value': items, 'maxCount': 3 }
    return this.navDestTitleBarOpts(undefined, menu)
  }

  private sendTopicAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_ACTION, `${Date.now()}:${action}`)
  }

  private sendSearchAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.SEARCH_ACTION, `${Date.now()}:${action}`)
  }

  private sendImagePreviewAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.IMAGE_PREVIEW_ACTION, `${Date.now()}:${action}`)
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

  private consumePendingV2exUrl(): void {
    const command = (this.pendingV2exUrl || '').trim()
    if (!command) {
      return
    }
    const stampedUrlMatch = command.match(/^\d+:(.+)$/)
    const url = stampedUrlMatch && stampedUrlMatch[1] ? stampedUrlMatch[1] : command
    if (this.openV2exRoute(url)) {
      AppStorage.setOrCreate<string>(StorageKeys.PENDING_V2EX_URL, '')
    }
  }

  private openV2exRoute(url: string): boolean {
    const route = V2exUrlRouter.parse(url)
    if (!route) {
      return false
    }
    this.pushV2exRoute(route)
    return true
  }

  private pushV2exRoute(route: V2exRoute): void {
    if (route.kind === 'topic' && route.topicId && route.topicId > 0) {
      const p: TopicDetailParams = route.targetFloor && route.targetFloor > 0
        ? { topicId: route.topicId, targetFloor: route.targetFloor }
        : { topicId: route.topicId }
      this.ns.pushPathByName('TopicDetail', p as Object)
      return
    }
    if (route.kind === 'member' && route.username) {
      const p: UserProfileParams = { username: route.username }
      this.ns.pushPathByName('UserProfile', p as Object)
      return
    }
    if (route.kind === 'node' && route.nodeName) {
      const p: NodeTopicListParams = { nodeName: route.nodeName, nodeTitle: route.nodeName }
      this.ns.pushPathByName('NodeTopicList', p as Object)
      return
    }
    if (route.kind === 'search' && route.query) {
      AppStorage.setOrCreate<string>(StorageKeys.PENDING_SEARCH_QUERY, `${Date.now()}:${route.query}`)
      this.ns.pushPathByName('Search', null)
    }
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
    let mat: Record<string, Object> =
      { 'materialType': hdsMaterial.MaterialType.ADAPTIVE, 'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE }
    let scrollOpts: Record<string, Object> =
      { 'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR }
    let style: Record<string, Object> = { 'systemMaterialEffect': mat, 'scrollEffectOpts': scrollOpts }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style
    }
  }

  private meTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('设置', $r('sys.symbol.gearshape'), () => {
        this.ns.pushPathByName('Settings', null)
      })
    ]
    return { 'value': items, 'maxCount': 1 }
  }

  private searchTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('筛选', $r('sys.symbol.funnel'), () => {
        this.sendSearchAction('filter')
      })
    ]
    return { 'value': items, 'maxCount': 1 }
  }

  private webLoginTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('保存登录', $r('sys.symbol.checkmark_circle'), () => {
        this.sendWebLoginAction('save')
      }),
      this.topicActionItem('重新加载', $r('sys.symbol.arrow_clockwise'), () => {
        this.sendWebLoginAction('reload')
      })
    ]
    return { 'value': items, 'maxCount': 2 }
  }

  private imagePreviewTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('保存图片', $r('sys.symbol.arrow_down_to_line'), () => {
        this.sendImagePreviewAction('save')
      })
    ]
    return { 'value': items, 'maxCount': 1 }
  }

  private sendWebLoginAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.WEB_LOGIN_ACTION, `${Date.now()}:${action}`)
  }

  @Builder
  TabIcon(title: string, idx: number) {
    Column() {
      SymbolGlyph(idx === 0 ? $r('sys.symbol.house_fill')
        : idx === 1 ? $r('sys.symbol.square_fill_grid_2x2')
          : idx === 2 ? $r('sys.symbol.bell_fill')
            : $r('sys.symbol.person_fill'))
        .fontSize(ThemeConstants.INDICATOR_SIZE - 6).renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .fontColor([this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary')])
      Text(title)
        .fontSize(ThemeConstants.FONT_SIZE_TINY)
        .fontColor(this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: ThemeConstants.SPACE_SM - 2, bottom: ThemeConstants.SPACE_XS })
  }

  @Builder
  MePage() {
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
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
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
      .then((_snapshot) => {
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
            })
              .then(() => {
                this.loadAccountMeta(true)
              })
          })
      })
      .catch((error: Error) => {
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

  @Builder
  SectionHeader(title: string) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
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
  CoinAmount(rimColor: string, faceColor: string, edgeColor: string, amount: number) {
    Row({ space: 4 }) {
      CoinIconCanvas({ rimColor, faceColor, edgeColor })
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
  AccountPage() {
    Column() {
      SecondaryListScaffold({ bottomPadding: ThemeConstants.SPACE_MD }) {
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
                this.logoutAll();
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
  }

  @Builder
  AuthActionRow(title: string, subtitle: string, action: () => void) {
    ConciseListRow({ title: title, subtitle: subtitle, action: action })
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
      this.AuthActionRow('我的回复', '', () => {
        this.ns.pushPathByName('MyReplies', null)
      })
      this.SettingsDivider()
      this.AuthActionRow('收藏节点', '', () => {
        this.ns.pushPathByName('MyNodes', null)
      })
      this.SettingsDivider()
      this.AuthActionRow('关注与收藏', '', () => {
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
      this.LocalNavigationRow('稍后读', this.savedTopics.length, () => {
        this.ns.pushPathByName('SavedTopics', null)
      })
      this.SettingsDivider()
      this.LocalNavigationRow('最近浏览', this.viewedTopics.length, () => {
        this.ns.pushPathByName('ViewedTopics', null)
      })
      this.SettingsDivider()
      this.LocalNavigationRow('关注节点', this.savedNodes.length, () => {
        this.ns.pushPathByName('SavedNodes', null)
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
  LocalNavigationRow(title: string, count: number, action: () => void) {
    ConciseListRow({
      title: title,
      count: count,
      action: action,
      showChevron: true
    })
  }

  @Builder
  StorageSection() {
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

  private loadAuthSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.storedUsername = snapshot.username
        this.tokenDraft = ''
        if (snapshot.token) {
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
        return AuthSettings.saveToken(context, token, username)
      })
      .then(() => {
        this.tokenDraft = ''
        this.refreshTokenInfo(token)
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
        this.tokenDraft = ''
        this.authProfile = null
        this.tokenInfo = null
        this.tokenInfoError = ''
        this.authError = ''
        if (!keepCookieAccount) {
          this.accountBalance = null
          this.dailyMission = null
          this.accountMetaError = ''
        }
        if (keepCookieAccount) {
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
        this.tokenDraft = ''
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

}
