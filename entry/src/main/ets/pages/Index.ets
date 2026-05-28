import {
  BlurStrategy,
  BottomBuilderShowType,
  DynamicHideParams,
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsAnimationMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HideMode,
  IconType,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { common, Want } from '@kit.AbilityKit'
import {
  AccountSessionCoordinator,
  AppStrings,
  ApiConstants,
  ApiService,
  AuthSettings,
  CookieJarSettings,
  FoldScreenUtil,
  HttpClient,
  HomeTabSettings,
  MotionHandStateService,
  StorageKeys,
  ThemeConstants,
  towFASheetOptions,
  TwoFactorChallengeService,
  V2exRoute,
  V2exUrlRouter,
  translateApiError,
} from 'shared'
import { HomePage } from 'feed'
import { ReplyEditorPage, TopicDetailPage } from 'detail'
import { DiscoverPage, NodePickerPage, NodeTopicPage } from 'node'
import { UserProfilePage, UserRepliesPage, UserTopicsPage } from 'user'
import {
  SettingsPage,
  StorageSettingsPage,
  DiagnosticsLogPage,
  ReadingSettingsPage,
  HomeNodeSettingsPage,
  NetworkProxySettingsPage,
  DomainSettingsPage,
} from 'settings'
import { ComponentContent, promptAction, SymbolGlyphModifier } from '@kit.ArkUI'
import { V2exWebLoginPage } from './V2exWebLoginPage'
import { V2exNativeLoginPage } from './V2exNativeLoginPage'
import { ImagePreviewPage } from './ImagePreviewPage'
import { SearchPage } from './SearchPage'
import { TopicEditorPage } from './TopicEditorPage'
import { MyTopicsPage } from './MyTopicsPage'
import { MyNodesPage } from './MyNodesPage'
import { AccountFollowingPage } from './AccountFollowingPage'
import { AccountDashboardPage } from './AccountPage'
import { AccountDetailPage } from './AccountDetailPage'
import { AccountManagementPage } from './AccountManagementPage'
import { AccountWebViewPage } from './AccountWebViewPage'
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
import { V2exTwoFactorPrompt } from '../components/V2exTwoFactorPrompt'
import {
  TopicDetailTitleAction,
  TopicDetailTitleActionDescriptor,
  TopicDetailTitleBarCoordinator,
} from '../model/TopicDetailTitleBarCoordinator'
import {
  IndexTitleBarCoordinator,
  IndexTitleMenuDescriptor,
} from '../model/IndexTitleBarCoordinator'
import {
  NotificationCenterViewModel,
} from '../viewmodel/NotificationCenterViewModel'
import type { IndexDestinationDescriptor } from '../model/IndexRouteCoordinator'
import { IndexRouteCoordinator } from '../model/IndexRouteCoordinator'

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack();
  private readonly HOME_TAB_SCROLL_DELTA_PX: number = 6
  private readonly HOME_TAB_ANIMATION_GUARD_MS: number = 180
  private tc: HdsTabsController = new HdsTabsController();
  private homeTabScrollers: Scroller[] = [
    new Scroller(),
    new Scroller(),
    new Scroller(),
    new Scroller(),
  ];
  private tabTitles: ResourceStr[] = [
    AppStrings.R_SETTINGS_HOME,
    AppStrings.R_TAB_DISCOVER,
    AppStrings.R_TAB_NOTIFICATIONS,
    AppStrings.R_TAB_ME,
  ];
  private homeTabLastScrollOffsets: number[] = [0, 0, 0, 0]
  private homeTabVisibleByScroll: boolean = true
  private homeTabAnimationGuardTimerId: number = -1
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
  @StorageLink(StorageKeys.NOTIFICATION_UNREAD_COUNT) notificationUnreadCount: number = 0;
  @StorageLink(StorageKeys.HOME_TAB_AUTO_HIDE)
  @Watch('onHomeTabAutoHideChanged')
  homeTabAutoHide: boolean = HomeTabSettings.DEFAULT_AUTO_HIDE;
  @StorageLink(StorageKeys.AUTH_SESSION_UPDATED_AT)
  @Watch('onAuthSessionUpdated')
  authSessionUpdatedAt: number = 0;
  @StorageLink(StorageKeys.TWO_FACTOR_VISIBLE) twoFactorVisible: boolean = false;
  @StorageLink(StorageKeys.TWO_FACTOR_COOKIE) twoFactorCookie: string = '';
  @StorageLink(StorageKeys.TWO_FACTOR_SOURCE) twoFactorSource: string = '';
  @StorageLink(StorageKeys.ACCOUNT_WEB_VIEW_URL) accountWebViewUrl: string = '';
  @State private notificationRefreshKey: number = 0;
  @State private accountRefreshKey: number = 0;
  @State private isFoldedAndUseOuterScreen: boolean = false;
  private http: HttpClient = HttpClient.getInstance();
  private notificationVm: NotificationCenterViewModel = new NotificationCenterViewModel(
    new ApiService(),
  );
  private notificationBadgeRequestId: number = 0;
  private foldScreenCallback: (value: boolean) => void = (value: boolean) => {
    this.isFoldedAndUseOuterScreen = value
  };

  aboutToAppear(): void {
    MotionHandStateService.start()
    this.consumePendingV2exUrl()
    this.refreshNotificationBadge()

    // Register foldable screen state change callback
    const foldScreenUtil = FoldScreenUtil.getInstance()
    this.isFoldedAndUseOuterScreen = foldScreenUtil.isFoldedAndUseOuterScreen()
    foldScreenUtil.registerCallback(this.foldScreenCallback)
  }

  aboutToDisappear(): void {
    // Unregister foldable screen state change callback
    FoldScreenUtil.getInstance().unregisterCallback(this.foldScreenCallback)
    this.clearHomeTabAnimationGuardTimer()
  }

  onPendingV2exUrlChanged(_propName: string): void {
    this.consumePendingV2exUrl()
  }

  onHomeTabAutoHideChanged(_propName: string): void {
    this.applyHomeTabAutoHide()
  }

  private setHomeTabScroller(index: number, scroller: Scroller): void {
    const oldScroller = this.homeTabScrollers[index]
    if (oldScroller === scroller) {
      if (this.homeTabAutoHide) {
        this.tc.bindScroller(index, scroller)
      }
      return
    }
    if (oldScroller) {
      this.tc.unbindScroller(oldScroller)
    }
    this.homeTabScrollers[index] = scroller
    if (this.homeTabAutoHide) {
      this.tc.bindScroller(index, scroller)
      this.restoreHomeTabIfHidden()
    }
  }

  private applyHomeTabAutoHide(): void {
    if (this.homeTabAutoHide) {
      for (let index = 0; index < this.homeTabScrollers.length; index++) {
        this.tc.bindScroller(index, this.homeTabScrollers[index])
      }
      this.restoreHomeTabIfHidden()
      return
    }
    for (let index = 0; index < this.homeTabScrollers.length; index++) {
      this.tc.unbindScroller(this.homeTabScrollers[index])
    }
    this.restoreHomeTabIfHidden()
  }

  private restoreHomeTabIfHidden(): void {
    if (this.homeTabVisibleByScroll) {
      return
    }
    this.homeTabVisibleByScroll = true
    this.tc.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
  }

  private clearHomeTabAnimationGuardTimer(): void {
    if (this.homeTabAnimationGuardTimerId === -1) {
      return
    }
    clearTimeout(this.homeTabAnimationGuardTimerId)
    this.homeTabAnimationGuardTimerId = -1
  }

  private startHomeTabAnimationGuardTimer(): void {
    this.clearHomeTabAnimationGuardTimer()
    this.homeTabAnimationGuardTimerId = setTimeout((): void => {
      this.homeTabAnimationGuardTimerId = -1
    }, this.HOME_TAB_ANIMATION_GUARD_MS)
  }

  private applyHomeTabScrollAnimation(visible: boolean): void {
    if (!this.homeTabAutoHide || this.homeTabAnimationGuardTimerId !== -1 || this.homeTabVisibleByScroll === visible) {
      return
    }
    this.homeTabVisibleByScroll = visible
    if (visible) {
      this.tc.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    } else {
      this.tc.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    }
    this.startHomeTabAnimationGuardTimer()
  }

  private onHomeTabDidScroll(index: number, offset: number, state: ScrollState): void {
    if (index !== this.ct || !this.homeTabAutoHide) {
      this.homeTabLastScrollOffsets[index] = offset
      return
    }
    if (offset <= this.HOME_TAB_SCROLL_DELTA_PX) {
      this.homeTabLastScrollOffsets[index] = offset
      this.restoreHomeTabIfHidden()
      return
    }
    if (state === ScrollState.Idle) {
      this.homeTabLastScrollOffsets[index] = offset
      return
    }
    const lastOffset = this.homeTabLastScrollOffsets[index]
    this.homeTabLastScrollOffsets[index] = offset
    const delta = offset - lastOffset
    const isReverseScroll = delta < -this.HOME_TAB_SCROLL_DELTA_PX
    const isForwardScroll = delta > this.HOME_TAB_SCROLL_DELTA_PX
    if (isReverseScroll) {
      this.applyHomeTabScrollAnimation(true)
      return
    }
    if (isForwardScroll) {
      this.applyHomeTabScrollAnimation(false)
    }
  }

  onAuthSessionUpdated(_propName: string): void {
    if (this.authSessionUpdatedAt <= 0) {
      return
    }
    this.notificationRefreshKey = Date.now()
    this.accountRefreshKey = Date.now()
    this.refreshNotificationBadge()
  }

  @Builder
  pm(name: string, param: Object) {
    this.destination(IndexRouteCoordinator.destination(name, param))
  }

  @Builder
  private destination(descriptor: IndexDestinationDescriptor | null) {
    if (descriptor) {
      HdsNavDestination() {
        this.destinationContent(descriptor)
      }
      .titleBar(this.destinationTitleBarOpts(descriptor))
      .dynamicHideTitleBar(this.destinationHideTitleBarOpts(descriptor))
      .onShown(() => {
        this.onDestinationShown(descriptor)
      })
    }
  }

  @Builder
  private destinationContent(descriptor: IndexDestinationDescriptor) {
    if (descriptor.family === 'topicDetail') {
      TopicDetailPage({
        topicId: descriptor.topicDetailParams.topicId,
        targetFloor: descriptor.topicDetailParams.targetFloor || 0,
      })
    }
    if (descriptor.family === 'replyEditor') {
      ReplyEditorPage({
        topicId: descriptor.replyEditorParams.topicId,
        topicTitle: descriptor.replyEditorParams.topicTitle,
        initialContent: descriptor.replyEditorParams.initialContent,
      })
    }
    if (descriptor.family === 'webLogin') {
      V2exWebLoginPage()
    }
    if (descriptor.family === 'nativeLogin') {
      V2exNativeLoginPage()
    }
    if (descriptor.family === 'nodePicker') {
      NodePickerPage()
    }
    if (descriptor.family === 'search') {
      SearchPage()
    }
    if (descriptor.family === 'topicEditor') {
      TopicEditorPage()
    }
    if (descriptor.family === 'myTopics') {
      MyTopicsPage()
    }
    if (descriptor.family === 'myNodes') {
      MyNodesPage()
    }
    if (descriptor.family === 'accountFollowing') {
      AccountFollowingPage()
    }
    if (descriptor.family === 'settings') {
      SettingsPage()
    }
    if (descriptor.family === 'storage') {
      StorageSettingsPage()
    }
    if (descriptor.family === 'diagnosticsLog') {
      DiagnosticsLogPage()
    }
    if (descriptor.family === 'homeNodeSettings') {
      HomeNodeSettingsPage()
    }
    if (descriptor.family === 'readingSettings') {
      ReadingSettingsPage()
    }
    if (descriptor.family === 'networkProxySettings') {
      NetworkProxySettingsPage()
    }
    if (descriptor.family === 'domainSettings') {
      DomainSettingsPage()
    }
    if (descriptor.family === 'account') {
      AccountManagementPage()
    }
    if (descriptor.family === 'accountDetail') {
      AccountDetailPage()
    }
    if (descriptor.family === 'accountWebView') {
      AccountWebViewPage()
    }
    if (descriptor.family === 'savedTopics') {
      SavedTopicsPage()
    }
    if (descriptor.family === 'viewedTopics') {
      ViewedTopicsPage()
    }
    if (descriptor.family === 'savedNodes') {
      SavedNodesPage()
    }
    if (descriptor.family === 'about') {
      AboutPage()
    }
    if (descriptor.family === 'imagePreview') {
      ImagePreviewPage({ url: descriptor.imagePreviewParams.url })
    }
    if (descriptor.family === 'nodeTopic') {
      NodeTopicPage({
        nodeName: descriptor.nodeTopicParams.nodeName,
        nodeTitle: descriptor.nodeTopicParams.nodeTitle,
      })
    }
    if (descriptor.family === 'userProfile') {
      UserProfilePage({ username: descriptor.userProfileParams.username })
    }
    if (descriptor.family === 'userTopics') {
      UserTopicsPage({ username: descriptor.userProfileParams.username })
    }
    if (descriptor.family === 'userReplies') {
      UserRepliesPage({ username: descriptor.userProfileParams.username })
    }
  }

  build() {
    HdsNavigation(this.ns) {
      HdsTabs({ controller: this.tc, index: this.ct }) {
        TabContent() {
          HomePage({
            onScrollerReady: (scroller: Scroller) => {
              this.setHomeTabScroller(0, scroller)
            },
            onDidScroll: (offset: number, state: ScrollState) => {
              this.onHomeTabDidScroll(0, offset, state)
            },
          })
        }.tabBar(this.TabIcon(AppStrings.R_SETTINGS_HOME, 0))
        TabContent() {
          DiscoverPage({
            currentTab: this.ct,
            scroller: this.homeTabScrollers[1],
            onDidScroll: (offset: number, state: ScrollState) => {
              this.onHomeTabDidScroll(1, offset, state)
            },
          })
        }.tabBar(this.TabIcon(AppStrings.R_TAB_DISCOVER, 1))
        TabContent() {
          NotificationPage({
            refreshKey: this.notificationRefreshKey,
            currentTab: this.ct,
            scroller: this.homeTabScrollers[2],
            onDidScroll: (offset: number, state: ScrollState) => {
              this.onHomeTabDidScroll(2, offset, state)
            },
          })
        }.tabBar(this.TabIcon(AppStrings.R_TAB_NOTIFICATIONS, 2))
        TabContent() {
          AccountDashboardPage({
            refreshKey: this.accountRefreshKey,
            scroller: this.homeTabScrollers[3],
            onDidScroll: (offset: number, state: ScrollState) => {
              this.onHomeTabDidScroll(3, offset, state)
            },
          })
        }.tabBar(this.TabIcon(AppStrings.R_TAB_ME, 3))
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
      .onAppear(() => {
        this.applyHomeTabAutoHide()
      })
      .onChange((i: number) => {
        this.ct = i
        if (i === 2) {
          this.notificationBadgeRequestId++
          this.notificationRefreshKey = Date.now()
        }
        if (i !== 2) {
          this.refreshNotificationBadge()
        }
        if (i === 3) {
          this.accountRefreshKey = Date.now()
        }
        if (this.homeTabAutoHide) {
          this.restoreHomeTabIfHidden()
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
    .bindSheet(
      $$this.twoFactorVisible,
      this.GlobalTwoFactorSheet(),
      towFASheetOptions(SheetSize.MEDIUM, () => {
        TwoFactorChallengeService.cancel()
      }),
    )
  }

  @Builder
  private GlobalTwoFactorSheet() {
    V2exTwoFactorPrompt({
      visible: $twoFactorVisible,
      cookie: this.twoFactorCookie,
      onSuccess: () => {
        const source = this.twoFactorSource
        TwoFactorChallengeService.complete()
        if (source === 'nativeLogin') {
          try {
            this.ns.pop()
          } catch (error) {
            const caught = error as Error
            console.error('pop native login after global 2fa failed: ' + caught.message)
          }
        }
        this.notificationRefreshKey = Date.now()
        this.accountRefreshKey = Date.now()
        this.refreshNotificationBadge()
        this.refreshLocalData()
      },
      onCancel: () => {
        TwoFactorChallengeService.cancel()
      },
    })
  }

  private destinationTitleBarOpts(descriptor: IndexDestinationDescriptor): Record<string, Object> {
    if (descriptor.family === 'account') {
      return this.navDestTitleBarOpts(descriptor.title, this.accountManagementTitleMenu())
    }
    if (IndexRouteCoordinator.usesStandardTitleBar(descriptor.family)) {
      return this.navDestTitleBarOpts(descriptor.title)
    }
    if (descriptor.family === 'topicDetail') {
      return this.topicDetailTitleBarOpts(descriptor.topicDetailParams.topicId)
    }
    if (descriptor.family === 'webLogin') {
      return this.navDestTitleBarOpts(descriptor.title, this.webLoginTitleMenu())
    }
    if (descriptor.family === 'accountWebView') {
      return this.navDestTitleBarOpts(this.accountWebViewTitle(), this.accountWebViewTitleMenu())
    }
    if (descriptor.family === 'search') {
      return this.navDestTitleBarOpts(descriptor.title, this.searchTitleMenu())
    }
    if (descriptor.family === 'imagePreview') {
      return this.navDestTitleBarOpts(undefined, this.imagePreviewTitleMenu())
    }
    if (descriptor.family === 'nodeTopic') {
      return this.nodeTopicTitleBarOpts(
        descriptor.nodeTopicParams.nodeName,
        descriptor.nodeTopicParams.nodeTitle,
      )
    }
    if (descriptor.family === 'userProfile') {
      return this.userProfileTitleBarOpts(descriptor.userProfileParams.username)
    }
    return this.navDestTitleBarOpts(descriptor.title)
  }

  private destinationHideTitleBarOpts(descriptor: IndexDestinationDescriptor): DynamicHideParams {
    const hideForTopicDetail = descriptor.family === 'topicDetail' && this.isFoldedAndUseOuterScreen
    return {
      hideTitleArea: hideForTopicDetail,
      hideStatusBar: hideForTopicDetail,
      mode: HideMode.SCROLL_UP,
    }
  }

  private onDestinationShown(descriptor: IndexDestinationDescriptor): void {
    if (descriptor.family === 'userProfile') {
      this.notifyUserProfileShown(descriptor.userProfileParams.username)
    }
    if (descriptor.family === 'nativeLogin') {
      this.notifyNativeLoginShown()
    }
  }

  private navDestTitleBarOpts<T extends Object>(
    title?: ResourceStr,
    menu?: Record<string, Object>,
    subTitle?: ResourceStr,
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
      (descriptor: TopicDetailTitleActionDescriptor) =>
        this.topicActionItem(
          descriptor.label,
          this.topicDetailTitleActionIcon(descriptor.action),
          () => {
            this.sendTopicAction(topicId, descriptor.action)
          },
        ),
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
        $r('app.string.topic_action_site_favorite'),
        this.nodeTopicSiteFavorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
        () => {
          this.sendNodeTopicAction(nodeName, 'siteFavorite')
        },
      ),
      this.topicActionItem(
        $r('app.string.topic_action_follow_node'),
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
      this.nodeTopicSubtitle,
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
      this.userProfileAppbarAvatarStates,
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
    if (
      !IndexTitleBarCoordinator.userProfileActionsAvailable(
        username,
        this.userProfileActionsUsername,
        this.userProfileActionsAvailable,
      )
    ) {
      return IndexTitleBarCoordinator.emptyMenu()
    }
    let items: Record<string, Object>[] = []
    if (this.userProfileFollowLabel) {
      items.push(
        this.topicActionItem(
          this.userProfileFollowing
            ? AppStrings.R_USER_ACTION_UNFOLLOW
            : AppStrings.R_USER_ACTION_FOLLOW,
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
        this.topicActionItem(
          this.userProfileBlocked
            ? AppStrings.R_USER_ACTION_UNBLOCK
            : AppStrings.R_USER_ACTION_BLOCK,
          this.userProfileBlockIcon(),
          () => {
            this.sendUserProfileAction('block')
          },
        ),
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
    // Favorite fired the toggle on both topics).
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

  private notifyNativeLoginShown(): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.NATIVE_LOGIN_SHOWN,
      IndexRouteCoordinator.simpleCommand('resume', Date.now()),
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
      promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
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
    label: ResourceStr,
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
    if (this.ct === 2) {
      content['menu'] = this.notificationTitleMenu()
    } else if (this.ct === 3) {
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
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          if (descriptor.action === 'settings') {
            this.ns.pushPathByName('Settings', null)
          }
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private notificationTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.notificationMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          this.sendNotificationAction(descriptor.action)
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private searchTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.searchMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          this.sendSearchAction(descriptor.action)
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private accountManagementTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.accountManagementMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          if (descriptor.action === 'addAccount') {
            this.startAddAccount()
          }
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private webLoginTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.webLoginMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          this.sendWebLoginAction(descriptor.action)
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.WEB_LOGIN_MENU_MAX_COUNT }
  }

  private accountWebViewTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.accountWebViewMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          this.sendAccountWebViewAction(descriptor.action)
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private accountWebViewTitle(): ResourceStr {
    const path = (this.accountWebViewUrl || '').trim().toLowerCase()
    if (path.indexOf('/balance') >= 0) {
      return AppStrings.R_BALANCE_DETAILS
    }
    if (path.indexOf('/settings') >= 0) {
      return AppStrings.R_WEB_ACCOUNT_SETTINGS
    }
    return AppStrings.R_NAV_WEB_LOGIN
  }

  private imagePreviewTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.imagePreviewMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          this.sendImagePreviewAction(descriptor.action)
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
  }

  private mainTitleMenuIcon(icon: string): Resource {
    if (icon === 'settings') {
      return $r('sys.symbol.gearshape')
    }
    if (icon === 'add') {
      return $r('sys.symbol.plus')
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

  private sendAccountWebViewAction(action: string): void {
    AppStorage.setOrCreate<string>(
      StorageKeys.ACCOUNT_WEB_VIEW_ACTION,
      IndexRouteCoordinator.simpleCommand(action, Date.now()),
    )
  }

  private startAddAccount(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountSessionCoordinator.prepareAddAccount(context)
      .then(() => {
        this.ns.pushPathByName('V2exNativeLogin', null)
      })
      .catch((error: Error) => {
        console.error('prepareAddAccount failed: ' + error.message)
      })
  }

  private refreshNotificationBadge(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const requestId = ++this.notificationBadgeRequestId
    const restoreCookieJar = CookieJarSettings.getCurrentCookie()
      ? Promise.resolve()
      : CookieJarSettings.load(context).catch((_error: Error) => {})
    restoreCookieJar
      .then(() => AuthSettings.load(context))
      .then((snapshot) => {
        if (requestId !== this.notificationBadgeRequestId) {
          return
        }
        const cookie = CookieJarSettings.getCurrentCookie()
        if (cookie) {
          this.notificationVm
            .unreadCountFromCookie(cookie)
            .then((count: number) => {
              if (this.canApplyNotificationBadgeRequest(requestId)) {
                this.notificationUnreadCount = count
              }
            })
            .catch((_error: Error) => {})
          return
        }
        if (this.canApplyNotificationBadgeRequest(requestId) && !snapshot.token) {
          this.notificationUnreadCount = 0
        }
      })
      .catch((_error: Error) => {})
  }

  private canApplyNotificationBadgeRequest(requestId: number): boolean {
    return requestId === this.notificationBadgeRequestId && this.ct !== 2
  }

  @Builder
  TabIcon(title: ResourceStr, idx: number) {
    MainTabIcon({
      title: title,
      idx: idx,
      currentIndex: this.ct,
      badgeCount: idx === 2 ? this.notificationUnreadCount : 0,
    })
  }
}
