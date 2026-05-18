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
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { common, Want } from '@kit.AbilityKit'
import {
  ApiConstants,
  FoldScreenUtil,
  HttpClient,
  MotionHandStateService,
  StorageKeys,
  ThemeConstants,
  V2exRoute,
  V2exUrlRouter,
} from 'shared'
import { HomePage } from 'feed'
import { ReplyEditorPage, TopicDetailPage } from 'detail'
import { DiscoverPage, NodePickerPage, NodeTopicPage } from 'node'
import { UserProfilePage, UserRepliesPage, UserTopicsPage } from 'user'
import {
  SettingsPage,
  StorageSettingsPage,
  ReadingSettingsPage,
  HomeNodeSettingsPage,
} from 'settings'
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
import {
  DiscoverSearchCCBuilder,
  PillCCBuilder,
  TopicDetailAppbarIdentityParams,
  TopicDetailIdentityCCBuilder,
  UserProfileAppbarIdentityParams,
  UserProfileIdentityCCBuilder,
} from '../components/IndexTitleBarComponents'
import { MainTabIcon } from '../components/MainTabIcon'
import {
  TopicDetailTitleAction,
  TopicDetailTitleActionDescriptor,
  TopicDetailTitleBarCoordinator
} from '../model/TopicDetailTitleBarCoordinator'
import {
  IndexTitleBarCoordinator,
  IndexTitleMenuDescriptor,
} from '../model/IndexTitleBarCoordinator'
import { IndexRouteCoordinator } from '../model/IndexRouteCoordinator'

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack();
  private tc: HdsTabsController = new HdsTabsController();
  private tabTitles: string[] = ['首页', '发现', '通知', '我的'];
  @State ct: number = 0;
  @StorageLink(StorageKeys.PENDING_V2EX_URL)
  @Watch('onPendingV2exUrlChanged')
  pendingV2exUrl: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_SAVED_LATER) topicDetailSavedLater: boolean = false;
  @StorageLink(StorageKeys.TOPIC_DETAIL_SITE_FAVORITED) topicDetailSiteFavorited: boolean = false;
  @StorageLink(StorageKeys.TOPIC_DETAIL_THANKED) topicDetailThanked: boolean = false;
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE) topicDetailAppbarTitle: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_URL) topicDetailAppbarAvatarUrl: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME) topicDetailAppbarUsername: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID)
  topicDetailAppbarRouteTopicId: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE_STATES) topicDetailAppbarTitleStates: string =
    '{}';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_STATES)
  topicDetailAppbarAvatarStates: string = '{}';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME_STATES)
  topicDetailAppbarUsernameStates: string = '{}';
  @StorageLink(StorageKeys.NODE_TOPIC_SAVED) nodeTopicSaved: boolean = false;
  @StorageLink(StorageKeys.NODE_TOPIC_SITE_FAVORITED) nodeTopicSiteFavorited: boolean = false;
  @StorageLink(StorageKeys.NODE_TOPIC_TITLE) nodeTopicTitle: string = '';
  @StorageLink(StorageKeys.NODE_TOPIC_SUBTITLE) nodeTopicSubtitle: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_AVAILABLE) userProfileActionsAvailable: boolean =
    false;
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_USERNAME) userProfileActionsUsername: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOW_LABEL) userProfileFollowLabel: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_BLOCK_LABEL) userProfileBlockLabel: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOWING) userProfileFollowing: boolean = false;
  @StorageLink(StorageKeys.USER_PROFILE_BLOCKED) userProfileBlocked: boolean = false;
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_USERNAME)
  userProfileAppbarTitleUsername: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_AVATAR_URL)
  userProfileAppbarTitleAvatarUrl: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_ROUTE_USERNAME)
  userProfileAppbarTitleRouteUsername: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_STATES) userProfileAppbarTitleStates: string =
    '{}';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_AVATAR_STATES)
  userProfileAppbarAvatarStates: string = '{}';
  @State private notificationRefreshKey: number = 0;
  @State private accountRefreshKey: number = 0;
  @State private isFoldedAndUseOuterScreen: boolean = false;
  private http: HttpClient = HttpClient.getInstance();
  private foldScreenCallback: (value: boolean) => void = (value: boolean) => {
    this.isFoldedAndUseOuterScreen = value
  };

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
          topicId: IndexRouteCoordinator.topicDetailRouteParams(param).topicId,
          targetFloor: IndexRouteCoordinator.topicDetailRouteParams(param).targetFloor || 0,
        })
      }
      .titleBar(
        this.topicDetailTitleBarOpts(IndexRouteCoordinator.topicDetailRouteParams(param).topicId),
      )
      .dynamicHideTitleBar({
        hideTitleArea: this.isFoldedAndUseOuterScreen,
        hideStatusBar: this.isFoldedAndUseOuterScreen,
        mode: HideMode.SCROLL_UP,
      })
    } else if (name === 'ImagePreview') {
      HdsNavDestination() {
        ImagePreviewPage({ url: IndexRouteCoordinator.imagePreviewRouteParams(param).url })
      }.titleBar(this.navDestTitleBarOpts(undefined, this.imagePreviewTitleMenu()))
    } else if (name === 'NodeTopicList') {
      HdsNavDestination() {
        NodeTopicPage({
          nodeName: IndexRouteCoordinator.nodeTopicRouteParams(param).nodeName,
          nodeTitle: IndexRouteCoordinator.nodeTopicRouteParams(param).nodeTitle,
        })
      }
      .titleBar(
        this.nodeTopicTitleBarOpts(
          IndexRouteCoordinator.nodeTopicRouteParams(param).nodeName,
          IndexRouteCoordinator.nodeTopicRouteParams(param).nodeTitle,
        ),
      )
    } else if (name === 'ReplyEditor') {
      HdsNavDestination() {
        ReplyEditorPage({
          topicId: IndexRouteCoordinator.replyEditorRouteParams(param).topicId,
          topicTitle: IndexRouteCoordinator.replyEditorRouteParams(param).topicTitle,
          initialContent: IndexRouteCoordinator.replyEditorRouteParams(param).initialContent,
        })
      }.titleBar(this.navDestTitleBarOpts('回复'))
    } else if (name === 'UserProfile') {
      HdsNavDestination() {
        UserProfilePage({ username: IndexRouteCoordinator.userProfileRouteParams(param).username })
      }
      .titleBar(
        this.userProfileTitleBarOpts(IndexRouteCoordinator.userProfileRouteParams(param).username),
      )
      .onShown(() => {
        this.notifyUserProfileShown(IndexRouteCoordinator.userProfileRouteParams(param).username)
      })
    } else if (name === 'UserTopics') {
      HdsNavDestination() {
        UserTopicsPage({ username: IndexRouteCoordinator.userProfileRouteParams(param).username })
      }.titleBar(this.navDestTitleBarOpts('全部主题'))
    } else if (name === 'UserReplies') {
      HdsNavDestination() {
        UserRepliesPage({ username: IndexRouteCoordinator.userProfileRouteParams(param).username })
      }.titleBar(this.navDestTitleBarOpts('全部回复'))
    } else if (name === 'V2exWebLogin') {
      HdsNavDestination() {
        V2exWebLoginPage()
      }.titleBar(this.navDestTitleBarOpts('网页登录', this.webLoginTitleMenu()))
    } else if (name === 'V2exNativeLogin') {
      HdsNavDestination() {
        V2exNativeLoginPage()
      }.titleBar(this.navDestTitleBarOpts('账号密码登录'))
    } else if (name === 'NodePicker') {
      HdsNavDestination() {
        NodePickerPage()
      }.titleBar(this.navDestTitleBarOpts('选择节点'))
    } else if (name === 'Search') {
      HdsNavDestination() {
        SearchPage()
      }.titleBar(this.navDestTitleBarOpts('搜索', this.searchTitleMenu()))
    } else if (name === 'TopicEditor') {
      HdsNavDestination() {
        TopicEditorPage()
      }.titleBar(this.navDestTitleBarOpts('发帖草稿'))
    } else if (name === 'MyTopics') {
      HdsNavDestination() {
        MyTopicsPage()
      }.titleBar(this.navDestTitleBarOpts('收藏主题'))
    } else if (name === 'MyNodes') {
      HdsNavDestination() {
        MyNodesPage()
      }.titleBar(this.navDestTitleBarOpts('收藏节点'))
    } else if (name === 'AccountBlacklist') {
      HdsNavDestination() {
        AccountBlacklistPage()
      }.titleBar(this.navDestTitleBarOpts('屏蔽与忽略'))
    } else if (name === 'AccountFollowing') {
      HdsNavDestination() {
        AccountFollowingPage()
      }.titleBar(this.navDestTitleBarOpts('关注用户'))
    } else if (name === 'Settings') {
      HdsNavDestination() {
        SettingsPage()
      }.titleBar(this.navDestTitleBarOpts('设置'))
    } else if (name === 'Storage') {
      HdsNavDestination() {
        StorageSettingsPage()
      }.titleBar(this.navDestTitleBarOpts('存储'))
    } else if (name === 'HomeNodeSettings') {
      HdsNavDestination() {
        HomeNodeSettingsPage()
      }.titleBar(this.navDestTitleBarOpts('首页栏目设置'))
    } else if (name === 'ReadingSettings') {
      HdsNavDestination() {
        ReadingSettingsPage()
      }.titleBar(this.navDestTitleBarOpts('阅读字体设置'))
    } else if (name === 'Account') {
      HdsNavDestination() {
        AccountDashboardPage({ showDetail: true })
      }.titleBar(this.navDestTitleBarOpts('账号'))
    } else if (name === 'SavedTopics') {
      HdsNavDestination() {
        SavedTopicsPage()
      }.titleBar(this.navDestTitleBarOpts('稍后读'))
    } else if (name === 'ViewedTopics') {
      HdsNavDestination() {
        ViewedTopicsPage()
      }.titleBar(this.navDestTitleBarOpts('最近浏览'))
    } else if (name === 'SavedNodes') {
      HdsNavDestination() {
        SavedNodesPage()
      }.titleBar(this.navDestTitleBarOpts('本地关注节点'))
    } else if (name === 'About') {
      HdsNavDestination() {
        AboutPage()
      }.titleBar(this.navDestTitleBarOpts('关于'))
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
          NotificationPage({ refreshKey: this.notificationRefreshKey })
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
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      } as HdsTabsFloatingStyle)
      .onChange((i: number) => {
        this.ct = i
        if (i === 2) {
          this.notificationRefreshKey = Date.now()
        }
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
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM],
    )
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .navDestination(this.pm)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private navDestTitleBarOpts<T extends Object>(
    title?: string,
    menu?: Record<string, Object>,
    subTitle?: string,
    bottomBuilder?: Record<string, Object>,
    stackBuilderComponent?: ComponentContent<T>,
    titleAccessibilityText?: string,
  ): Record<string, Object> {
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
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
          'style': style,
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
        'style': style,
      }
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'style': style,
    }
  }

  private topicDetailTitleBarOpts(topicId: number): Record<string, Object> {
    let items: Record<string, Object>[] = TopicDetailTitleBarCoordinator.actions().map(
      (descriptor: TopicDetailTitleActionDescriptor) => this.topicActionItem(
        descriptor.label,
        this.topicDetailTitleActionIcon(descriptor.action),
        () => {
          this.sendTopicAction(topicId, descriptor.action)
        },
      )
    )
    let menu: Record<string, Object> = {
      'value': items,
      'maxCount': TopicDetailTitleBarCoordinator.MENU_MAX_COUNT,
    }
    const routeKey = TopicDetailTitleBarCoordinator.routeKey(topicId)
    if (!routeKey) {
      return this.navDestTitleBarOpts(undefined, menu)
    }
    const identity = TopicDetailTitleBarCoordinator.identity(
      routeKey,
      this.topicDetailAppbarRouteTopicId,
      this.topicDetailAppbarTitle,
      this.topicDetailAppbarAvatarUrl,
      this.topicDetailAppbarUsername,
      this.topicDetailAppbarTitleStates,
      this.topicDetailAppbarAvatarStates,
      this.topicDetailAppbarUsernameStates,
    )
    if (identity.title.trim()) {
      let cc = new ComponentContent<TopicDetailAppbarIdentityParams>(
        this.getUIContext(),
        wrapBuilder(TopicDetailIdentityCCBuilder),
        {
          title: identity.title,
          avatarUrl: identity.avatarUrl,
          username: identity.username,
          menuMaxCount: TopicDetailTitleBarCoordinator.MENU_MAX_COUNT,
          menuItemCount: items.length,
        },
      )
      return this.navDestTitleBarOpts(' ', menu, undefined, undefined, cc, identity.title)
    }
    return this.navDestTitleBarOpts(undefined, menu)
  }

  private topicDetailTitleActionIcon(action: TopicDetailTitleAction): Resource {
    const active = TopicDetailTitleBarCoordinator.activeForState(action, {
      savedLater: this.topicDetailSavedLater,
      siteFavorited: this.topicDetailSiteFavorited,
      thanked: this.topicDetailThanked,
    })
    if (action === 'thankTopic') {
      return active ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart')
    }
    if (action === 'siteFavorite') {
      return active ? $r('sys.symbol.star_fill') : $r('sys.symbol.star')
    }
    if (action === 'saveLater') {
      return active ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark')
    }
    if (action === 'ignoreTopic') {
      return $r('sys.symbol.xmark')
    }
    if (action === 'reportTopic') {
      return $r('sys.symbol.exclamationmark_triangle')
    }
    if (action === 'copyTitle') {
      return $r('sys.symbol.doc_plaintext')
    }
    if (action === 'copyLink') {
      return $r('sys.symbol.plus_square_on_square')
    }
    if (action === 'share') {
      return $r('sys.symbol.share')
    }
    return $r('sys.symbol.search_things')
  }

  private nodeTopicTitleBarOpts(nodeName: string, nodeTitle: string): Record<string, Object> {
    let items: Record<string, Object>[] = [
      this.topicActionItem(
        '站内收藏',
        this.nodeTopicSiteFavorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
        () => {
          this.sendNodeTopicAction(nodeName, 'siteFavorite')
        },
      ),
      this.topicActionItem(
        '关注节点',
        this.nodeTopicSaved ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'),
        () => {
          this.sendNodeTopicAction(nodeName, 'saveNode')
        },
      ),
    ]
    let menu: Record<string, Object> = { 'value': items, 'maxCount': 2 }
    const text = IndexTitleBarCoordinator.nodeTopicText(
      nodeName,
      nodeTitle,
      this.nodeTopicTitle,
      this.nodeTopicSubtitle
    )
    return this.navDestTitleBarOpts(text.title, menu, text.subtitle)
  }

  private userProfileTitleBarOpts(username: string): Record<string, Object> {
    const identity = IndexTitleBarCoordinator.userProfileIdentity(
      username,
      this.userProfileAppbarTitleRouteUsername,
      this.userProfileAppbarTitleUsername,
      this.userProfileAppbarTitleAvatarUrl,
      this.userProfileAppbarTitleStates,
      this.userProfileAppbarAvatarStates
    )
    const profileMenu = this.userProfileTitleMenu(username)
    if (identity.title.trim()) {
      const stats = IndexTitleBarCoordinator.menuStats(profileMenu)
      let cc = new ComponentContent<UserProfileAppbarIdentityParams>(
        this.getUIContext(),
        wrapBuilder(UserProfileIdentityCCBuilder),
        {
          titleUsername: identity.title,
          avatarUrl: identity.avatarUrl,
          menuMaxCount: stats.maxCount,
          menuItemCount: stats.itemCount,
        },
      )
      return this.navDestTitleBarOpts(' ', profileMenu, undefined, undefined, cc, identity.title)
    }
    return this.navDestTitleBarOpts(identity.title, profileMenu)
  }

  private userProfileTitleMenu(username: string): Record<string, Object> {
    if (!IndexTitleBarCoordinator.userProfileActionsAvailable(
      username,
      this.userProfileActionsUsername,
      this.userProfileActionsAvailable
    )) {
      return IndexTitleBarCoordinator.emptyMenu()
    }
    let items: Record<string, Object>[] = []
    if (this.userProfileFollowLabel) {
      items.push(
        this.topicActionItem(
          this.userProfileFollowLabel,
          this.userProfileFollowing
            ? $r('sys.symbol.person_xmark')
            : $r('sys.symbol.person_badge_plus'),
          () => {
            this.sendUserProfileAction('follow')
          },
        ),
      )
    }
    if (this.userProfileBlockLabel) {
      items.push(
        this.topicActionItem(this.userProfileBlockLabel, this.userProfileBlockIcon(), () => {
          this.sendUserProfileAction('block')
        }),
      )
    }
    return { 'value': items, 'maxCount': 1 }
  }

  private userProfileBlockIcon(): SymbolGlyphModifier {
    return new SymbolGlyphModifier(
      this.userProfileBlocked ? $r('sys.symbol.eye_slash') : $r('sys.symbol.nosign'),
    ).fontColor([Color.Red])
  }

  private sendTopicAction(topicId: number, action: string): void {
    // Payload format: `${ts}:${topicId}:${action}` so each TopicDetailPage
    // instance can filter by its own topicId. Without this, the global
    // AppStorage @Watch broadcasts the action to every live TopicDetailPage
    // in the nav stack — both top and underneath — causing duplicate
    // dialogs (e.g. opening detail B from a link in detail A and tapping
    // 收藏 fired the toggle on both topics).
    AppStorage.setOrCreate<string>(
      StorageKeys.TOPIC_DETAIL_ACTION,
      IndexRouteCoordinator.topicActionCommand(topicId, action, Date.now()),
    )
  }

  private refreshLocalData(): void {
    const updatedAt = Date.now()
    if (!AppStorage.set<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)) {
      AppStorage.setOrCreate<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)
    }
  }

  private sendNodeTopicAction(nodeName: string, action: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.NODE_TOPIC_ACTION,
      IndexRouteCoordinator.nodeTopicActionCommand(nodeName, action, Date.now()),
    )
  }

  private sendUserProfileAction(action: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.USER_PROFILE_ACTION,
      IndexRouteCoordinator.simpleCommand(action, Date.now()),
    )
  }

  private notifyUserProfileShown(username: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.USER_PROFILE_SHOWN,
      IndexRouteCoordinator.userProfileShownCommand(username, Date.now()),
    )
  }

  private sendNotificationAction(action: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.NOTIFICATION_ACTION,
      IndexRouteCoordinator.simpleCommand(action, Date.now()),
    )
  }

  private sendSearchAction(action: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.SEARCH_ACTION,
      IndexRouteCoordinator.simpleCommand(action, Date.now()),
    )
  }

  private sendImagePreviewAction(action: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.IMAGE_PREVIEW_ACTION,
      IndexRouteCoordinator.simpleCommand(action, Date.now()),
    )
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
    context.startAbility(want).catch((error: Error) => {
      promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => {})
    })
  }

  private consumePendingV2exUrl(): void {
    const url = IndexRouteCoordinator.commandPayload(this.pendingV2exUrl)
    if (!url) {
      return
    }
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
    const topicParams = IndexRouteCoordinator.topicParams(route)
    if (topicParams) {
      this.ns.pushPathByName('TopicDetail', topicParams as Object)
      return
    }
    const userProfileParams = IndexRouteCoordinator.userProfileParams(route)
    if (userProfileParams) {
      this.ns.pushPathByName('UserProfile', userProfileParams as Object)
      return
    }
    const nodeTopicParams = IndexRouteCoordinator.nodeTopicParams(route)
    if (nodeTopicParams) {
      this.ns.pushPathByName('NodeTopicList', nodeTopicParams as Object)
      return
    }
    const searchQuery = IndexRouteCoordinator.searchQuery(route)
    if (searchQuery) {
      AppStorage.setOrCreate<string>(
        StorageKeys.PENDING_SEARCH_QUERY,
        IndexRouteCoordinator.pendingSearchQueryCommand(searchQuery, Date.now()),
      )
      this.ns.pushPathByName('Search', null)
    }
  }

  private topicActionItem(
    label: string,
    icon: IconType,
    action: () => void,
  ): Record<string, Object> {
    let content: Record<string, Object> = {
      'label': label,
      'icon': icon,
      'isEnabled': true,
      'action': action,
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
        'showType': BottomBuilderShowType.DIRECTLY_SHOW,
      }
      content = { 'title': titleInfo, 'bottomBuilder': bb }
    } else if (this.ct === 1) {
      let cc = new ComponentContent(this.getUIContext(), wrapBuilder(DiscoverSearchCCBuilder))
      let bb: Record<string, Object> = {
        'builderComponent': cc,
        'height': 48,
        'showType': BottomBuilderShowType.DIRECTLY_SHOW,
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
      content['menu'] = IndexTitleBarCoordinator.emptyMenu()
    }
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style,
    }
  }

  private meTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.meMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) => this.topicActionItem(
        descriptor.label,
        this.mainTitleMenuIcon(descriptor.icon),
        () => {
          if (descriptor.action === 'settings') {
            this.ns.pushPathByName('Settings', null)
          }
        },
      )
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private notificationTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.notificationMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) => this.topicActionItem(
        descriptor.label,
        this.mainTitleMenuIcon(descriptor.icon),
        () => {
          this.sendNotificationAction(descriptor.action)
        },
      )
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private searchTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.searchMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) => this.topicActionItem(
        descriptor.label,
        this.mainTitleMenuIcon(descriptor.icon),
        () => {
          this.sendSearchAction(descriptor.action)
        },
      )
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private webLoginTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.webLoginMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) => this.topicActionItem(
        descriptor.label,
        this.mainTitleMenuIcon(descriptor.icon),
        () => {
          this.sendWebLoginAction(descriptor.action)
        },
      )
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.WEB_LOGIN_MENU_MAX_COUNT }
  }

  private imagePreviewTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.imagePreviewMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) => this.topicActionItem(
        descriptor.label,
        this.mainTitleMenuIcon(descriptor.icon),
        () => {
          this.sendImagePreviewAction(descriptor.action)
        },
      )
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private mainTitleMenuIcon(icon: string): Resource {
    if (icon === 'settings') {
      return $r('sys.symbol.gearshape')
    }
    if (icon === 'filter') {
      return $r('sys.symbol.funnel')
    }
    if (icon === 'confirm') {
      return $r('sys.symbol.checkmark_circle')
    }
    if (icon === 'download') {
      return $r('sys.symbol.arrow_down_to_line')
    }
    if (icon === 'refresh') {
      return $r('sys.symbol.arrow_clockwise')
    }
    return $r('sys.symbol.search_things')
  }

  private sendWebLoginAction(action: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.WEB_LOGIN_ACTION,
      IndexRouteCoordinator.simpleCommand(action, Date.now()),
    )
  }

  @Builder
  TabIcon(title: string, idx: number) {
    MainTabIcon({
      title: title,
      idx: idx,
      currentIndex: this.ct,
    })
  }
}
