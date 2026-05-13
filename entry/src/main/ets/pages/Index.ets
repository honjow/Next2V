import {
  BlurStrategy,
  BottomBuilderShowType,
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HideMode,
  IconType,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { common, Want } from '@kit.AbilityKit'
import {
  ApiConstants,
  AppSearchField,
  Avatar,
  FeedTabSettings,
  FoldScreenUtil,
  HttpClient,
  ImagePreviewParams,
  MotionHandStateService,
  NodeTopicListParams,
  StorageKeys,
  TabItem,
  ThemeConstants,
  TopicDetailParams,
  UserProfileParams,
  V2exRoute,
  V2exUrlRouter
} from 'shared'
import { HomePage } from 'feed'
import { ReplyEditorPage, TopicDetailPage } from 'detail'
import { DiscoverPage, NodePickerPage, NodeTopicPage } from 'node'
import { UserProfilePage, UserRepliesPage, UserTopicsPage } from 'user'
import { SettingsPage, StorageSettingsPage, ReadingSettingsPage, HomeNodeSettingsPage } from 'settings'
import { ComponentContent, promptAction, SymbolGlyphModifier } from '@kit.ArkUI'
import { V2exWebLoginPage } from './V2exWebLoginPage'
import { V2exNativeLoginPage } from './V2exNativeLoginPage'
import { ImagePreviewPage } from './ImagePreviewPage'
import { SearchPage } from './SearchPage'
import { TopicEditorPage } from './TopicEditorPage'
import { MyTopicsPage } from './MyTopicsPage'
import { MyNodesPage } from './MyNodesPage'
import { AccountBlacklistPage } from './AccountBlacklistPage'
import { AccountFollowingPage } from './AccountFollowingPage'
import { AccountDashboardPage } from './AccountPage'
import { SavedTopicsPage } from './SavedTopicsPage'
import { ViewedTopicsPage } from './ViewedTopicsPage'
import { SavedNodesPage } from './SavedNodesPage'
import { NotificationPage } from './NotificationPage'
import { AboutPage } from './AboutPage'

@Component
struct FeedPills {
  @StorageLink(StorageKeys.FEED_TAB) @Watch('onFeedTabChanged') feedTab: string = 'tech'
  @StorageLink(StorageKeys.FEED_TAB_KEYS) @Watch('onFeedTabKeysChanged') feedTabKeys: string =
    FeedTabSettings.defaultKeysJson()
  @StorageLink(StorageKeys.FEED_TAB_VISUAL_INDEX) feedTabVisualIndex: number = 0
  @State private tabLefts: number[] = []
  @State private tabWidths: number[] = []
  @State private containerGlobalLeft: number = 0
  private pendingCenterIndex: number = -1
  private pendingCenterSmooth: boolean = true
  private scroller: Scroller = new Scroller()

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ space: ThemeConstants.SPACE_XS, scroller: this.scroller }) {
        ForEach(this.visibleTabs(), (tab: TabItem, index: number) => {
          ListItem() {
            Column({ space: 1 }) {
              Text(tab.label)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor(this.visualSelectedIndex() === index ? ThemeConstants.BRAND_PRIMARY :
                  ThemeConstants.TEXT_SECONDARY)
                .fontWeight(this.visualSelectedIndex() === index ? FontWeight.Medium : FontWeight.Regular)
                .padding({
                  left: ThemeConstants.SPACE_MD,
                  right: ThemeConstants.SPACE_MD,
                  top: ThemeConstants.SPACE_XS
                })
              Blank().height(2).width(18)
            }
            .alignItems(HorizontalAlign.Center)
            .padding({ bottom: 0 })
            .onClick(() => {
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
      .width('100%')
      .height('100%')

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
    const index = this.selectedTabIndex()
    if (index < 0) {
      return
    }
    this.centerTab(index, true)
  }

  private onFeedTabKeysChanged(_propName: string): void {
    this.tabLefts = []
    this.tabWidths = []
    this.pendingCenterIndex = -1
  }

  private visibleTabs(): TabItem[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedTabKeys)
  }

  private selectedTabIndex(): number {
    const index = this.visibleTabs().findIndex((tab: TabItem) => tab.key === this.feedTab)
    return index
  }

  private visualSelectedIndex(): number {
    const count = this.visibleTabs().length
    if (count <= 0) {
      return 0
    }
    return Math.max(0, Math.min(count - 1, Math.round(this.feedTabVisualIndex)))
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
    if (this.pendingCenterIndex === index) {
      this.centerTab(index, this.pendingCenterSmooth)
    }
  }

  private indicatorWidth(): number {
    return 18
  }

  private indicatorLeft(): number {
    const count = this.visibleTabs().length
    if (count <= 0) {
      return ThemeConstants.SPACE_SM
    }
    const visualIndex = Math.max(0, Math.min(count - 1, this.feedTabVisualIndex))
    const fromIndex = Math.floor(visualIndex)
    const toIndex = Math.min(count - 1, fromIndex + 1)
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
    return this.estimatedTabCenter(index)
  }

  private averageMeasuredTabWidth(): number {
    let total = 0
    let count = 0
    for (let i = 0; i < this.tabWidths.length; i++) {
      const width = this.tabWidths[i]
      if (width !== undefined && width > 0) {
        total += width
        count++
      }
    }
    return count > 0 ? total / count : 48
  }

  private estimatedTabCenter(index: number): number {
    const step = this.averageMeasuredTabWidth() + ThemeConstants.SPACE_XS
    for (let prev = index - 1; prev >= 0; prev--) {
      const left = this.tabLefts[prev]
      const width = this.tabWidths[prev]
      if (left !== undefined && width !== undefined && width > 0) {
        return left + width / 2 + (index - prev) * step
      }
    }
    for (let next = index + 1; next < this.visibleTabs().length; next++) {
      const left = this.tabLefts[next]
      const width = this.tabWidths[next]
      if (left !== undefined && width !== undefined && width > 0) {
        return left + width / 2 - (next - index) * step
      }
    }
    return ThemeConstants.SPACE_SM + this.averageMeasuredTabWidth() / 2 + index * step
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

  private centerTab(index: number, smooth: boolean): void {
    if (index < 0 || index >= this.visibleTabs().length) {
      return
    }
    const width = this.tabWidths[index]
    if (width === undefined || width <= 0) {
      this.pendingCenterIndex = index
      this.pendingCenterSmooth = smooth
      return
    }
    this.pendingCenterIndex = -1
    this.scroller.scrollToIndex(index, smooth, ScrollAlign.CENTER)
  }
}

@Builder
function PillCCBuilder() {
  FeedPills()
}

@Component
struct DiscoverSearchComponent {
  @StorageLink(StorageKeys.DISCOVER_NODE_KEYWORD) keyword: string = ''

  build() {
    Row() {
      AppSearchField({
        text: $keyword,
        placeholder: '搜索节点'
      })
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: 4,
      bottom: 4
    })
  }
}

@Builder
function DiscoverSearchCCBuilder() {
  DiscoverSearchComponent()
}

const TITLE_BAR_COMPACT_WIDTH: number = 600
const TITLE_BAR_EXPANDED_WIDTH: number = 840
const TITLE_BAR_LEADING_EDGE_RESERVE_COMPACT: number = 16
const TITLE_BAR_LEADING_EDGE_RESERVE_MEDIUM: number = 24
const TITLE_BAR_LEADING_EDGE_RESERVE_EXPANDED: number = 32
const TITLE_BAR_BACK_BUTTON_SLOT_WIDTH: number = 48
const TITLE_BAR_ACTION_VISUAL_RESERVE: number = 36
const TITLE_BAR_TRAILING_SAFETY_GAP: number = 8
const TOPIC_DETAIL_TITLE_MENU_MAX_COUNT: number = 3

function titleBarLengthToNumber(value: Length | undefined): number {
  if (typeof value === 'number') {
    return value
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value)
    return Number.isNaN(parsed) ? 0 : parsed
  }
  return 0
}

function titleBarTrailingReserve(titleBarWidth: number, menuMaxCount: number, menuItemCount: number): number {
  const inlineCount = Math.max(0, Math.min(menuMaxCount, menuItemCount))
  const hasOverflowAction = menuItemCount > menuMaxCount
  const actionSlotCount = inlineCount + (hasOverflowAction ? 1 : 0)
  if (actionSlotCount <= 0) {
    return 0
  }
  // The stackBuilderComponent can measure its own titlebar width via
  // onAreaChange, but HDS exposes no per-route trailing menu bounds here
  // (only value/maxCount in TitleBarContentOptions). Keep bcdc554's tighter
  // 36vp visual footprint per visible/overflow action, then add only the
  // same width-aware edge gutter used for the leading side so unfolded layouts
  // get separation without reverting to full 48vp touch-slot padding.
  return actionSlotCount * TITLE_BAR_ACTION_VISUAL_RESERVE + TITLE_BAR_TRAILING_SAFETY_GAP +
    titleBarWidthAwareEdgeReserve(titleBarWidth)
}

function titleBarWidthAwareEdgeReserve(titleBarWidth: number): number {
  if (titleBarWidth >= TITLE_BAR_EXPANDED_WIDTH) {
    return TITLE_BAR_LEADING_EDGE_RESERVE_EXPANDED
  }
  if (titleBarWidth >= TITLE_BAR_COMPACT_WIDTH) {
    return TITLE_BAR_LEADING_EDGE_RESERVE_MEDIUM
  }
  return TITLE_BAR_LEADING_EDGE_RESERVE_COMPACT
}

function titleBarLeadingReserve(titleBarWidth: number): number {
  // HDS does not expose the MINI back-button bubble bounds to this custom
  // stackBuilderComponent. Keep the fixed 48vp back slot, then add only the
  // observed HDS leading gutter for the measured titlebar width: 16vp phone,
  // 24vp medium, 32vp unfolded. On the 2560px unfolded QA screenshot the
  // 64vp compact reserve started the identity avatar inside the back bubble;
  // the expanded 80vp reserve moves it just past the bubble with a small gap.
  return TITLE_BAR_BACK_BUTTON_SLOT_WIDTH + titleBarWidthAwareEdgeReserve(titleBarWidth)
}

interface UserProfileAppbarIdentityParams {
  titleUsername: string
  avatarUrl: string
  menuMaxCount: number
  menuItemCount: number
}

@Component
struct UserProfileAppbarIdentity {
  @Prop titleUsername: string = ''
  @Prop avatarUrl: string = ''
  @Prop menuMaxCount: number = 0
  @Prop menuItemCount: number = 0
  @State private titleBarWidth: number = 0

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      if ((this.titleUsername || '').trim()) {
        Avatar({ url: this.avatarUrl, avatarSize: 24, placeholder: (this.titleUsername || '').trim() })
        Text((this.titleUsername || '').trim())
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(ThemeConstants.TITLE_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: titleBarLeadingReserve(this.titleBarWidth),
      right: titleBarTrailingReserve(this.titleBarWidth, this.menuMaxCount, this.menuItemCount)
    })
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.titleBarWidth = titleBarLengthToNumber(newValue?.width)
    })
  }
}

@Builder
function UserProfileIdentityCCBuilder(params: UserProfileAppbarIdentityParams) {
  UserProfileAppbarIdentity({
    titleUsername: params.titleUsername,
    avatarUrl: params.avatarUrl,
    menuMaxCount: params.menuMaxCount,
    menuItemCount: params.menuItemCount
  })
}

interface TopicDetailAppbarIdentityParams {
  title: string
  avatarUrl: string
  username: string
  menuMaxCount: number
  menuItemCount: number
}

@Component
struct TopicDetailAppbarIdentity {
  @Prop title: string = ''
  @Prop avatarUrl: string = ''
  @Prop username: string = ''
  @Prop menuMaxCount: number = 0
  @Prop menuItemCount: number = 0
  @State private titleBarWidth: number = 0

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      if ((this.title || '').trim()) {
        Avatar({ url: this.avatarUrl, avatarSize: 24, placeholder: (this.username || this.title || '').trim() })
        Text((this.title || '').trim())
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          // layoutWeight(1) is required: without it, a Text in a Row keeps
          // its intrinsic width and OVERFLOWS the parent's right padding
          // into the trailing menu icon area. Ellipsis only triggers when
          // the Text's own width is constrained. Short / wrappable titles
          // fit by coincidence; long CJK titles overlap by ~1 character.
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(ThemeConstants.TITLE_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: titleBarLeadingReserve(this.titleBarWidth),
      right: titleBarTrailingReserve(this.titleBarWidth, this.menuMaxCount, this.menuItemCount)
    })
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.titleBarWidth = titleBarLengthToNumber(newValue?.width)
    })
  }
}

@Builder
function TopicDetailIdentityCCBuilder(params: TopicDetailAppbarIdentityParams) {
  TopicDetailAppbarIdentity({
    title: params.title,
    avatarUrl: params.avatarUrl,
    username: params.username,
    menuMaxCount: params.menuMaxCount,
    menuItemCount: params.menuItemCount
  })
}

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack()
  private tc: HdsTabsController = new HdsTabsController()
  private tabTitles: string[] = ['首页', '发现', '通知', '我的']
  @State ct: number = 0
  @StorageLink(StorageKeys.PENDING_V2EX_URL) @Watch('onPendingV2exUrlChanged') pendingV2exUrl: string = ''
  @StorageLink(StorageKeys.TOPIC_DETAIL_SAVED_LATER) topicDetailSavedLater: boolean = false
  @StorageLink(StorageKeys.TOPIC_DETAIL_SITE_FAVORITED) topicDetailSiteFavorited: boolean = false
  @StorageLink(StorageKeys.TOPIC_DETAIL_THANKED) topicDetailThanked: boolean = false
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE) topicDetailAppbarTitle: string = ''
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_URL) topicDetailAppbarAvatarUrl: string = ''
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME) topicDetailAppbarUsername: string = ''
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID) topicDetailAppbarRouteTopicId: string = ''
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE_STATES) topicDetailAppbarTitleStates: string = '{}'
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_STATES) topicDetailAppbarAvatarStates: string = '{}'
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME_STATES) topicDetailAppbarUsernameStates: string = '{}'
  @StorageLink(StorageKeys.NODE_TOPIC_SAVED) nodeTopicSaved: boolean = false
  @StorageLink(StorageKeys.NODE_TOPIC_SITE_FAVORITED) nodeTopicSiteFavorited: boolean = false
  @StorageLink(StorageKeys.NODE_TOPIC_TITLE) nodeTopicTitle: string = ''
  @StorageLink(StorageKeys.NODE_TOPIC_SUBTITLE) nodeTopicSubtitle: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_AVAILABLE) userProfileActionsAvailable: boolean = false
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_USERNAME) userProfileActionsUsername: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOW_LABEL) userProfileFollowLabel: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_BLOCK_LABEL) userProfileBlockLabel: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOWING) userProfileFollowing: boolean = false
  @StorageLink(StorageKeys.USER_PROFILE_BLOCKED) userProfileBlocked: boolean = false
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_USERNAME) userProfileAppbarTitleUsername: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_AVATAR_URL) userProfileAppbarTitleAvatarUrl: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_ROUTE_USERNAME) userProfileAppbarTitleRouteUsername: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_STATES) userProfileAppbarTitleStates: string = '{}'
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_AVATAR_STATES) userProfileAppbarAvatarStates: string = '{}'
  @State private accountRefreshKey: number = 0
  @State private isFoldedAndUseOuterScreen: boolean = false
  private http: HttpClient = HttpClient.getInstance()
  private foldScreenCallback: (value: boolean) => void = (value: boolean) => {
    this.isFoldedAndUseOuterScreen = value
  }

  aboutToAppear(): void {
    MotionHandStateService.start()
    this.consumePendingV2exUrl()

    // 注册折叠屏状态变化回调
    const foldScreenUtil = FoldScreenUtil.getInstance()
    this.isFoldedAndUseOuterScreen = foldScreenUtil.isFoldedAndUseOuterScreen()
    foldScreenUtil.registerCallback(this.foldScreenCallback)
  }

  aboutToDisappear(): void {
    // 取消注册折叠屏状态变化回调
    FoldScreenUtil.getInstance().unregisterCallback(this.foldScreenCallback)
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
          targetFloor: ((param as Record<string, Object>)['targetFloor'] as number) || 0,
        })
      }
      .titleBar(this.topicDetailTitleBarOpts(((param as Record<string, Object>)['topicId'] as number) || 0))
      .dynamicHideTitleBar({
        hideTitleArea: this.isFoldedAndUseOuterScreen,
        hideStatusBar: this.isFoldedAndUseOuterScreen,
        mode: HideMode.SCROLL_UP,
      })
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
      }.titleBar(this.nodeTopicTitleBarOpts(
        (param as Record<string, Object>)['nodeName'] as string,
        (param as Record<string, Object>)['nodeTitle'] as string
      ))
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
      .titleBar(this.userProfileTitleBarOpts((param as Record<string, Object>)['username'] as string))
      .onShown(() => {
        this.notifyUserProfileShown((param as Record<string, Object>)['username'] as string)
      })
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
      .titleBar(this.navDestTitleBarOpts('关注用户'))
    } else if (name === 'Settings') {
      HdsNavDestination() {
        SettingsPage()
      }
      .titleBar(this.navDestTitleBarOpts('设置'))
    } else if (name === 'Storage') {
      HdsNavDestination() {
        StorageSettingsPage()
      }
      .titleBar(this.navDestTitleBarOpts('存储'))
    } else if (name === 'HomeNodeSettings') {
      HdsNavDestination() {
        HomeNodeSettingsPage()
      }
      .titleBar(this.navDestTitleBarOpts('首页栏目设置'))
    } else if (name === 'ReadingSettings') {
      HdsNavDestination() {
        ReadingSettingsPage()
      }
      .titleBar(this.navDestTitleBarOpts('阅读设置'))
    } else if (name === 'Account') {
      HdsNavDestination() {
        AccountDashboardPage({ showDetail: true })
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
      .titleBar(this.navDestTitleBarOpts('本地关注节点'))
    } else if (name === 'About') {
      HdsNavDestination() {
        AboutPage()
      }
      .titleBar(this.navDestTitleBarOpts('关于'))
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
          AccountDashboardPage({ refreshKey: this.accountRefreshKey })
        }.tabBar(this.TabIcon('我的', 3))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .scrollable(false)
      .animationDuration(0)
      .barFloatingStyle({
        barBottomMargin: ThemeConstants.SPACE_XL,
        adaptToHandedness: true,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      } as HdsTabsFloatingStyle)
      .onChange((i: number) => {
        this.ct = i
        if (i === 3) {
          this.accountRefreshKey = Date.now()
          this.refreshLocalData()
        }
      })
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .dynamicHideTitleBar({
      hideTitleArea: this.ct === 1 || this.ct === 2,
      hideBottomBuilder: this.ct === 1,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .navDestination(this.pm)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private navDestTitleBarOpts<T extends Object>(title?: string, menu?: Record<string, Object>, subTitle?: string,
    bottomBuilder?: Record<string, Object>, stackBuilderComponent?: ComponentContent<T>,
    titleAccessibilityText?: string): Record<string, Object> {
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
      if (titleAccessibilityText) {
        titleInfo['mainTitleAccessibilityText'] = titleAccessibilityText
      }
      if (subTitle) {
        titleInfo['subTitle'] = subTitle
      }
      content['title'] = titleInfo
      if (stackBuilderComponent) {
        content['stackBuilderComponent'] = stackBuilderComponent
      }
      if (bottomBuilder) {
        content['bottomBuilder'] = bottomBuilder
      }
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

  private topicDetailTitleBarOpts(topicId: number): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('感谢主题', this.topicDetailThanked ? $r('sys.symbol.heart_fill') :
        $r('sys.symbol.heart'), () => {
        this.sendTopicAction(topicId, 'thankTopic')
      }),
      this.topicActionItem('站内收藏', this.topicDetailSiteFavorited ? $r('sys.symbol.star_fill') :
        $r('sys.symbol.star'), () => {
        this.sendTopicAction(topicId, 'siteFavorite')
      }),
      this.topicActionItem('稍后读', this.topicDetailSavedLater ? $r('sys.symbol.bookmark_fill') :
        $r('sys.symbol.bookmark'), () => {
        this.sendTopicAction(topicId, 'saveLater')
      }),
      this.topicActionItem('忽略主题', $r('sys.symbol.xmark'), () => {
        this.sendTopicAction(topicId, 'ignoreTopic')
      }),
      this.topicActionItem('举报主题', $r('sys.symbol.exclamationmark_triangle'), () => {
        this.sendTopicAction(topicId, 'reportTopic')
      }),
      this.topicActionItem('复制标题', $r('sys.symbol.doc_plaintext'), () => {
        this.sendTopicAction(topicId, 'copyTitle')
      }),
      this.topicActionItem('复制链接', $r('sys.symbol.plus_square_on_square'), () => {
        this.sendTopicAction(topicId, 'copyLink')
      }),
      this.topicActionItem('分享链接', $r('sys.symbol.share'), () => {
        this.sendTopicAction(topicId, 'share')
      }),
      this.topicActionItem('浏览器打开', $r('sys.symbol.search_things'), () => {
        this.sendTopicAction(topicId, 'openBrowser')
      })
    ]
    let menu: Record<string, Object> = { 'value': items, 'maxCount': TOPIC_DETAIL_TITLE_MENU_MAX_COUNT }
    const routeKey = topicId > 0 ? topicId.toString() : ''
    if (!routeKey) {
      return this.navDestTitleBarOpts(undefined, menu)
    }
    const titleFromState = this.topicDetailAppbarStringFor(this.topicDetailAppbarTitleStates, routeKey)
    const avatarFromState = this.topicDetailAppbarStringFor(this.topicDetailAppbarAvatarStates, routeKey)
    const usernameFromState = this.topicDetailAppbarStringFor(this.topicDetailAppbarUsernameStates, routeKey)
    const titleRouteKey = (this.topicDetailAppbarRouteTopicId || '').trim()
    const title = titleFromState || (titleRouteKey === routeKey ? (this.topicDetailAppbarTitle || '').trim() : '')
    if (title.trim()) {
      const avatarUrl =
        avatarFromState || (titleRouteKey === routeKey ? (this.topicDetailAppbarAvatarUrl || '').trim() : '')
      const username =
        usernameFromState || (titleRouteKey === routeKey ? (this.topicDetailAppbarUsername || '').trim() : '')
      let cc = new ComponentContent<TopicDetailAppbarIdentityParams>(
        this.getUIContext(),
        wrapBuilder(TopicDetailIdentityCCBuilder),
        {
          title: title,
          avatarUrl: avatarUrl,
          username: username,
          menuMaxCount: TOPIC_DETAIL_TITLE_MENU_MAX_COUNT,
          menuItemCount: items.length
        })
      return this.navDestTitleBarOpts(' ', menu, undefined, undefined, cc, title)
    }
    return this.navDestTitleBarOpts(undefined, menu)
  }

  private topicDetailAppbarStringFor(statesJson: string, routeKey: string): string {
    if (!routeKey) {
      return ''
    }
    try {
      const states = JSON.parse(statesJson || '{}') as Record<string, string>
      return (states[routeKey] || '').trim()
    } catch (_e) {
      return ''
    }
  }

  private nodeTopicTitleBarOpts(nodeName: string, nodeTitle: string): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('站内收藏', this.nodeTopicSiteFavorited ? $r('sys.symbol.star_fill') :
        $r('sys.symbol.star'), () => {
        this.sendNodeTopicAction('siteFavorite')
      }),
      this.topicActionItem('关注节点', this.nodeTopicSaved ? $r('sys.symbol.bookmark_fill') :
        $r('sys.symbol.bookmark'), () => {
        this.sendNodeTopicAction('saveNode')
      })
    ]
    let menu: Record<string, Object> = { 'value': items, 'maxCount': 2 }
    const baseTitle = (nodeTitle || nodeName || '').trim()
    const liveTitle = (this.nodeTopicTitle || '').trim()
    const title = liveTitle || baseTitle
    const subtitle = (this.nodeTopicSubtitle || '').trim()
    return this.navDestTitleBarOpts(title, menu, subtitle)
  }

  private userProfileTitleBarOpts(username: string): Record<string, Object> {
    const routeUsername = (username || '').trim()
    const titleFromState = this.userProfileAppbarTitleFor(routeUsername)
    const avatarFromState = this.userProfileAppbarAvatarFor(routeUsername)
    const titleRouteUsername = (this.userProfileAppbarTitleRouteUsername || '').trim()
    const titleUsername = (this.userProfileAppbarTitleUsername || '').trim()
    const title = titleFromState ||
      (titleUsername && this.sameUsername(titleRouteUsername, routeUsername) ? titleUsername : ' ')
    const profileMenu = this.userProfileTitleMenu(username)
    if (title.trim()) {
      const avatarUrl = avatarFromState ||
        (this.sameUsername(titleRouteUsername, routeUsername) ? (this.userProfileAppbarTitleAvatarUrl || '').trim() :
          '')
      let cc = new ComponentContent<UserProfileAppbarIdentityParams>(
        this.getUIContext(),
        wrapBuilder(UserProfileIdentityCCBuilder),
        {
          titleUsername: title,
          avatarUrl: avatarUrl,
          menuMaxCount: this.titleBarMenuMaxCount(profileMenu),
          menuItemCount: this.titleBarMenuItemCount(profileMenu)
        })
      return this.navDestTitleBarOpts(' ', profileMenu, undefined, undefined, cc, title)
    }
    return this.navDestTitleBarOpts(title, profileMenu)
  }

  private titleBarMenuItemCount(menu: Record<string, Object>): number {
    const value = menu['value'] as Record<string, Object>[]
    return value ? value.length : 0
  }

  private titleBarMenuMaxCount(menu: Record<string, Object>): number {
    const value = menu['maxCount'] as number
    return value === undefined ? 0 : Math.max(0, value)
  }

  private userProfileAppbarTitleFor(username: string): string {
    const key = (username || '').trim().toLowerCase()
    if (!key) {
      return ''
    }
    try {
      const states = JSON.parse(this.userProfileAppbarTitleStates || '{}') as Record<string, string>
      const title = (states[key] || '').trim()
      return title
    } catch (_e) {
      return ''
    }
  }

  private userProfileAppbarAvatarFor(username: string): string {
    const key = (username || '').trim().toLowerCase()
    if (!key) {
      return ''
    }
    try {
      const states = JSON.parse(this.userProfileAppbarAvatarStates || '{}') as Record<string, string>
      return (states[key] || '').trim()
    } catch (_e) {
      return ''
    }
  }

  private userProfileTitleMenu(username: string): Record<string, Object> {
    if (!this.userProfileActionsAvailable || this.userProfileActionsUsername !== username) {
      return { 'value': [], 'maxCount': 0 }
    }
    let items: Record<string, Object>[] = []
    if (this.userProfileFollowLabel) {
      items.push(this.topicActionItem(
        this.userProfileFollowLabel,
        this.userProfileFollowing ? $r('sys.symbol.person_xmark') : $r('sys.symbol.person_badge_plus'),
        () => {
          this.sendUserProfileAction('follow')
        }))
    }
    if (this.userProfileBlockLabel) {
      items.push(this.topicActionItem(
        this.userProfileBlockLabel,
        this.userProfileBlockIcon(),
        () => {
          this.sendUserProfileAction('block')
        }))
    }
    return { 'value': items, 'maxCount': 1 }
  }

  private userProfileBlockIcon(): SymbolGlyphModifier {
    return new SymbolGlyphModifier(this.userProfileBlocked ? $r('sys.symbol.eye_slash') : $r('sys.symbol.nosign'))
      .fontColor([Color.Red])
  }

  private sameUsername(a: string, b: string): boolean {
    return !!a && !!b && a.trim().toLowerCase() === b.trim().toLowerCase()
  }

  private sendTopicAction(topicId: number, action: string): void {
    // Payload format: `${ts}:${topicId}:${action}` so each TopicDetailPage
    // instance can filter by its own topicId. Without this, the global
    // AppStorage @Watch broadcasts the action to every live TopicDetailPage
    // in the nav stack — both top and underneath — causing duplicate
    // dialogs (e.g. opening detail B from a link in detail A and tapping
    // 收藏 fired the toggle on both topics).
    AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_ACTION, `${Date.now()}:${topicId}:${action}`)
  }

  private refreshLocalData(): void {
    const updatedAt = Date.now()
    if (!AppStorage.set<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)) {
      AppStorage.setOrCreate<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)
    }
  }

  private sendNodeTopicAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.NODE_TOPIC_ACTION, `${Date.now()}:${action}`)
  }

  private sendUserProfileAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_ACTION, `${Date.now()}:${action}`)
  }

  private notifyUserProfileShown(username: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_SHOWN, `${Date.now()}:${username}`)
  }

  private sendNotificationAction(action: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.NOTIFICATION_ACTION, `${Date.now()}:${action}`)
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

  private topicActionItem(label: string, icon: IconType, action: () => void): Record<string, Object> {
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
      let bb: Record<string, Object> = {
        'builderComponent': cc,
        'height': ApiConstants.TAB_BAR_HEIGHT,
        'showType': BottomBuilderShowType.DIRECTLY_SHOW
      }
      content = { 'title': titleInfo, 'bottomBuilder': bb }
    } else if (this.ct === 1) {
      let cc = new ComponentContent(this.getUIContext(), wrapBuilder(DiscoverSearchCCBuilder))
      let bb: Record<string, Object> = {
        'builderComponent': cc,
        'height': 48,
        'showType': BottomBuilderShowType.DIRECTLY_SHOW
      }
      content = { 'title': titleInfo, 'bottomBuilder': bb }
    } else {
      content = { 'title': titleInfo }
    }
    if (this.tabTitles[this.ct] === '通知') {
      content['menu'] = this.notificationTitleMenu()
    } else if (this.tabTitles[this.ct] === '我的') {
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

  private notificationTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem('刷新', $r('sys.symbol.arrow_clockwise'), () => {
        this.sendNotificationAction('refresh')
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
}
