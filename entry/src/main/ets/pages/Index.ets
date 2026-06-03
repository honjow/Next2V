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
  AutoDailyCheckinService,
  connectAccountWebViewAction,
  connectAccountWebViewUrl,
  connectAuthSessionSignal,
  connectHomeTabAutoHide,
  connectImagePreviewAction,
  connectLocalDataSignal,
  connectNativeLoginShown,
  connectNavStack,
  connectNodeTopicAction,
  connectNodeTopicAppbar,
  connectNotificationAction,
  connectNotificationUnread,
  connectPendingV2exUrl,
  connectSearchAction,
  connectTopicDetailAction,
  connectTopicDetailAppbar,
  connectTopicEditorAppbar,
  connectTwoFactor,
  connectUserProfileAction,
  connectUserProfileAppbar,
  connectWebCheckinRunner,
  connectWebLoginAction,
  publishNotificationUnreadCount,
  publishPendingV2exUrl,
  AccountWebViewUrlState,
  AuthSessionSignalState,
  HomeTabAutoHideState,
  NodeTopicAppbarState,
  NotificationUnreadState,
  PendingV2exUrlState,
  TopicDetailAppbarState,
  TopicEditorAppbarState,
  sendTopicEditorSubmit,
  TwoFactorState,
  UserProfileAppbarState,
  WebCheckinRunnerState,
  CookieJarSettings,
  SearchQueryBus,
  FoldScreenUtil,
  HttpClient,
  HomeTabSettings,
  MotionHandStateService,
  ThemeConstants,
  towFASheetOptions,
  TwoFactorChallengeService,
  V2exRoute,
  V2exUrlRouter,
  translateApiError,
} from 'shared'
import { HomePage } from 'feed'
import { TopicDetailPage } from 'detail'
import { DiscoverPage, NodePickerPage, NodeTopicPage } from 'node'
import { UserProfilePage, UserRepliesPage, UserTopicsPage } from 'user'
import {
  SettingsPage,
  StorageSettingsPage,
  DiagnosticsLogPage,
  ReadingSettingsPage,
  HomeNodeSettingsPage,
  NetworkProxySettingsPage,
  ImageUploadSettingsPage,
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
import { BlockedListsPage } from './BlockedListsPage'
import { SavedNodesPage } from './SavedNodesPage'
import { NotificationPage } from './NotificationPage'
import { AboutPage } from './AboutPage'
import {
  BlockedListsTabsCCBuilder,
  DiscoverSearchCCBuilder,
  NodeTopicAppbarIdentityParams,
  NodeTopicIdentityCCBuilder,
  PillCCBuilder,
  TopicDetailAppbarIdentityParams,
  TopicDetailIdentityCCBuilder,
  UserProfileAppbarIdentityParams,
  UserProfileIdentityCCBuilder,
} from '../components/IndexTitleBarComponents'
import { MainTabIcon } from '../components/MainTabIcon'
import { DailyCheckinWebRunner } from '../components/DailyCheckinWebRunner'
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
import { NotificationCenterViewModel } from '../viewmodel/NotificationCenterViewModel'
import type { IndexDestinationDescriptor } from '../model/IndexRouteCoordinator'
import { IndexRouteCoordinator } from '../model/IndexRouteCoordinator'

@Entry
@ComponentV2
struct Index {
  // ns from the app-wide NavStackHolder (AppStorageV2); HdsNavigation binds this instance and the
  // migrated @ComponentV2 routed pages read the identical stack via connectNavStack().stack. With every
  // @Consume('ns') consumer migrated, Index no longer needs to @Provide it.
  private ns: NavPathStack = connectNavStack().stack;
  private readonly HOME_TAB_SCROLL_DELTA_PX: number = 6;
  private readonly HOME_TAB_ANIMATION_GUARD_MS: number = 180;
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
  private homeTabLastScrollOffsets: number[] = [0, 0, 0, 0];
  private homeTabVisibleByScroll: boolean = true;
  private homeTabAnimationGuardTimerId: number = -1;
  @Local ct: number = 0;
  // Appbar identity + command/flag state the migrated producer pages (TopicDetailPage / NodeTopicPage /
  // UserProfilePage) report UP, read reactively in the title-bar builders via these @ObservedV2 mirrors,
  // each dual-written at its producer's write-through helper. Home-tab/auth-session/notification-unread/
  // account-webview/pending-url are likewise mirror-backed (dual-written at their service chokepoints).
  private topicDetailAppbar: TopicDetailAppbarState = connectTopicDetailAppbar();
  private topicEditorAppbar: TopicEditorAppbarState = connectTopicEditorAppbar();
  private nodeTopicAppbar: NodeTopicAppbarState = connectNodeTopicAppbar();
  private userProfileAppbar: UserProfileAppbarState = connectUserProfileAppbar();
  private notificationUnread: NotificationUnreadState = connectNotificationUnread();
  private homeTab: HomeTabAutoHideState = connectHomeTabAutoHide();
  private authSession: AuthSessionSignalState = connectAuthSessionSignal();
  private twoFactor: TwoFactorState = connectTwoFactor();
  private accountWebView: AccountWebViewUrlState = connectAccountWebViewUrl();
  private pendingUrl: PendingV2exUrlState = connectPendingV2exUrl();
  // Two-way @Local for bindSheet; kept in sync with the TwoFactorState mirror via @Monitor below.
  @Local twoFactorVisible: boolean = false;
  // The home feed-pill bar (FeedPills) is hosted via a ComponentContent created ONCE and cached here, never
  // re-`new`-ed inside build(). FeedPills is a @ComponentV2 that reactively reads the per-frame feed-tab
  // visual index; re-creating its ComponentContent every Index.build() ties this build scope to that
  // per-frame signal, which device-verifiably re-creates FeedPills ~400x/s during a swipe and storms its
  // recenter scrollToIndex. Caching keeps the per-frame re-render contained inside FeedPills.
  private pillBarContent: ComponentContent<Object> | undefined = undefined;
  @Local private notificationRefreshKey: number = 0;
  @Local private accountRefreshKey: number = 0;
  @Local private isFoldedAndUseOuterScreen: boolean = false;
  // Drives the nav-shell hidden ArkWeb daily check-in runner (auto check-in handoff; see WebCheckinRunnerState).
  @Local private webCheckin: WebCheckinRunnerState = connectWebCheckinRunner();
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
    // Create the home feed-pill ComponentContent ONCE here (outside build()), so startup/feed-load
    // re-renders cannot recreate it and re-mount the @ComponentV2 FeedPills (which would churn its recenter).
    if (!this.pillBarContent) {
      this.pillBarContent = new ComponentContent<Object>(
        this.getUIContext(),
        wrapBuilder<[Object]>(PillCCBuilder),
        new Object(),
      )
    }
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

  @Monitor('pendingUrl.command')
  onPendingV2exUrlChanged(): void {
    this.consumePendingV2exUrl()
  }

  @Monitor('homeTab.autoHide')
  onHomeTabAutoHideChanged(): void {
    this.applyHomeTabAutoHide()
  }

  @Monitor('twoFactor.visible')
  onTwoFactorVisibleChanged(): void {
    // Drive the bindSheet @Local from the service-owned TwoFactorState mirror.
    this.twoFactorVisible = this.twoFactor.visible
  }

  private setHomeTabScroller(index: number, scroller: Scroller): void {
    const oldScroller = this.homeTabScrollers[index]
    if (oldScroller === scroller) {
      if (this.homeTab.autoHide) {
        this.tc.bindScroller(index, scroller)
      }
      return
    }
    if (oldScroller) {
      this.tc.unbindScroller(oldScroller)
    }
    this.homeTabScrollers[index] = scroller
    if (this.homeTab.autoHide) {
      this.tc.bindScroller(index, scroller)
      this.restoreHomeTabIfHidden()
    }
  }

  private applyHomeTabAutoHide(): void {
    if (this.homeTab.autoHide) {
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
    if (
      !this.homeTab.autoHide ||
      this.homeTabAnimationGuardTimerId !== -1 ||
      this.homeTabVisibleByScroll === visible
    ) {
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
    if (index !== this.ct || !this.homeTab.autoHide) {
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

  @Monitor('authSession.updatedAt')
  onAuthSessionUpdated(): void {
    if (this.authSession.updatedAt <= 0) {
      return
    }
    // Monotonic refresh-signal counters (replace the former Date.now() churn): the child pages only
    // react to a CHANGE, so ++ is semantics-equivalent and avoids a randomized refresh-key token.
    this.notificationRefreshKey++
    this.accountRefreshKey++
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
    if (descriptor.family === 'blockedLists') {
      BlockedListsPage()
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
    if (descriptor.family === 'imageUploadSettings') {
      ImageUploadSettingsPage()
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
    Stack() {
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
            this.notificationRefreshKey++
          }
          if (i !== 2) {
            this.refreshNotificationBadge()
          }
          if (i === 3) {
            this.accountRefreshKey++
          }
          if (this.homeTab.autoHide) {
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
      // Hidden 1×1 ArkWeb runner for AUTO daily check-in (V2EX's anti-bot blocks a headless redeem). Always
      // mounted so check-in can run at login / startup even before the Me tab is first created. Manual
      // check-in uses its own runner inside AccountPage.
      DailyCheckinWebRunner({
        trigger: this.webCheckin.requestId,
        baseUrl: this.webCheckin.baseUrl,
        onRunResult: (status: string, rewardCoins: number) => {
          this.onAutoCheckinWebResult(status, rewardCoins)
        },
      })
    }
    .width('100%')
    .height('100%')
  }

  private onAutoCheckinWebResult(status: string, rewardCoins: number): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AutoDailyCheckinService.handleWebResult(context, status, rewardCoins).catch(
      (_error: Error) => {},
    )
    if (status === 'success' || status === 'already') {
      // Refresh the account card so the freshly-claimed balance / 已签到 state shows.
      this.accountRefreshKey++
    }
  }

  @Builder
  private GlobalTwoFactorSheet() {
    V2exTwoFactorPrompt({
      // V2exTwoFactorPrompt is @ComponentV2: pass the value one-way and let it report close via the
      // event (replaces the former two-way `$twoFactorVisible` @Link). bindSheet still owns the sheet
      // visibility through `$$this.twoFactorVisible`.
      visible: this.twoFactorVisible,
      onVisibleChange: (value: boolean) => {
        this.twoFactorVisible = value
      },
      cookie: this.twoFactor.cookie,
      onSuccess: () => {
        const source = this.twoFactor.source
        TwoFactorChallengeService.complete()
        if (source === 'nativeLogin') {
          try {
            this.ns.pop()
          } catch (error) {
            const caught = error as Error
            console.error('pop native login after global 2fa failed: ' + caught.message)
          }
        }
        this.notificationRefreshKey++
        this.accountRefreshKey++
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
    if (descriptor.family === 'blockedLists') {
      let cc = new ComponentContent(this.getUIContext(), wrapBuilder(BlockedListsTabsCCBuilder))
      let bb: Record<string, Object> = {
        'builderComponent': cc,
        'height': ThemeConstants.TITLE_BAR_HEIGHT,
        'showType': BottomBuilderShowType.DIRECTLY_SHOW,
      }
      return this.navDestTitleBarOpts(AppStrings.R_NAV_BLOCKED_LISTS, undefined, undefined, bb)
    }
    if (descriptor.family === 'topicEditor') {
      return this.topicEditorTitleBarOpts(descriptor.title)
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

  private topicEditorTitleBarOpts(title: ResourceStr): Record<string, Object> {
    // Submit is a title-bar icon. isEnabled mirrors the editor's canSubmit() via the appbar @Trace
    // (read here so the bar re-renders as the form fills); the tap goes back over the action bus.
    let content: Record<string, Object> = {
      'label': AppStrings.R_EDITOR_SUBMIT,
      'icon': this.submitTitleBarIcon(),
      'isEnabled': this.topicEditorAppbar.submitEnabled,
      'action': () => {
        sendTopicEditorSubmit()
      },
    }
    let items: Record<string, Object>[] = [{ 'content': content }]
    let menu: Record<string, Object> = {
      'value': items,
      'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT,
    }
    return this.navDestTitleBarOpts(title, menu)
  }

  // paperplane_right_fill's visual mass sits left of its box center, so in the title-bar menu slot it
  // reads as shoved left. Nudge it right a couple vp to optically center it — same trick the reply
  // composer's send button uses (ReplyComposerBar). A SymbolGlyphModifier carries the offset because
  // it extends SymbolGlyphAttribute (HdsNavigation's IconType accepts a SymbolGlyphModifier).
  private submitTitleBarIcon(): SymbolGlyphModifier {
    return new SymbolGlyphModifier($r('sys.symbol.paperplane_right_fill')).offset({ x: 2 })
  }

  private topicDetailTitleBarOpts(topicId: number): Record<string, Object> {
    let items: Record<string, Object>[] = TopicDetailTitleBarCoordinator.actions().map(
      (descriptor: TopicDetailTitleActionDescriptor) =>
        this.topicActionItem(
          this.topicDetailTitleActionLabel(descriptor, topicId),
          this.topicDetailTitleActionIcon(descriptor.action, topicId),
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
      this.topicDetailAppbar.routeTopicId,
      this.topicDetailAppbar.title,
      this.topicDetailAppbar.avatarUrl,
      this.topicDetailAppbar.username,
      this.topicDetailAppbar.titleStates,
      this.topicDetailAppbar.avatarStates,
      this.topicDetailAppbar.usernameStates,
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

  private isTopicIgnoredForRoute(topicId: number): boolean {
    // Route-id guard so a stacked detail page can't show a stale ignore state for a topic
    // it isn't drawing (the appbar mirror is a shared singleton across the detail stack).
    const routeId = topicId > 0 ? topicId.toString() : ''
    return (
      this.topicDetailAppbar.topicIgnored && this.topicDetailAppbar.topicIgnoredRouteId === routeId
    )
  }

  private topicDetailTitleActionLabel(
    descriptor: TopicDetailTitleActionDescriptor,
    topicId: number,
  ): ResourceStr {
    if (descriptor.action === 'ignoreTopic' && this.isTopicIgnoredForRoute(topicId)) {
      return AppStrings.R_TOPIC_ACTION_UNIGNORE_TOPIC
    }
    return descriptor.label
  }

  private topicDetailTitleActionIcon(action: TopicDetailTitleAction, topicId: number): Resource {
    const active = TopicDetailTitleBarCoordinator.activeForState(action, {
      savedLater: this.topicDetailAppbar.savedLater,
      siteFavorited: this.topicDetailAppbar.siteFavorited,
      thanked: this.topicDetailAppbar.thanked,
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
      return this.isTopicIgnoredForRoute(topicId) ? $r('sys.symbol.eye') : $r('sys.symbol.xmark')
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
        this.nodeTopicAppbar.siteFavorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
        () => {
          this.sendNodeTopicAction(nodeName, 'siteFavorite')
        },
      ),
      this.topicActionItem(
        $r('app.string.topic_action_follow_node'),
        this.nodeTopicAppbar.saved ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'),
        () => {
          this.sendNodeTopicAction(nodeName, 'saveNode')
        },
      ),
    ]
    let menu: Record<string, Object> = { 'value': items, 'maxCount': 2 }
    // Scroll-reveal title: empty (back button + actions only) until the node-info card's name scrolls
    // under the app bar, then an icon+name ComponentContent (mirrors the user-profile title bar). The
    // favorite/follow actions above are preserved in both states.
    const identity = IndexTitleBarCoordinator.nodeTopicIdentity(
      nodeName,
      this.nodeTopicAppbar.titleRouteNodeName,
      this.nodeTopicAppbar.titleNodeName,
      this.nodeTopicAppbar.titleNodeAvatarUrl,
      this.nodeTopicAppbar.titleNameStates,
      this.nodeTopicAppbar.titleAvatarStates,
    )
    if (identity.title.trim()) {
      const stats = IndexTitleBarCoordinator.menuStats(menu)
      let cc = new ComponentContent<NodeTopicAppbarIdentityParams>(
        this.getUIContext(),
        wrapBuilder(NodeTopicIdentityCCBuilder),
        {
          titleNodeName: identity.title,
          avatarUrl: identity.avatarUrl,
          menuMaxCount: stats.maxCount,
          menuItemCount: stats.itemCount,
        },
      )
      return this.navDestTitleBarOpts(' ', menu, undefined, undefined, cc, identity.title)
    }
    return this.navDestTitleBarOpts(undefined, menu)
  }

  private userProfileTitleBarOpts(username: string): Record<string, Object> {
    const identity = IndexTitleBarCoordinator.userProfileIdentity(
      username,
      this.userProfileAppbar.titleRouteUsername,
      this.userProfileAppbar.titleUsername,
      this.userProfileAppbar.titleAvatarUrl,
      this.userProfileAppbar.titleStates,
      this.userProfileAppbar.avatarStates,
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
        this.userProfileAppbar.actionsUsername,
        this.userProfileAppbar.actionsAvailable,
      )
    ) {
      return IndexTitleBarCoordinator.emptyMenu()
    }
    let items: Record<string, Object>[] = []
    if (this.userProfileAppbar.followLabel) {
      items.push(
        this.topicActionItem(
          this.userProfileAppbar.following
            ? AppStrings.R_USER_ACTION_UNFOLLOW
            : AppStrings.R_USER_ACTION_FOLLOW,
          this.userProfileAppbar.following
            ? $r('sys.symbol.person_xmark')
            : $r('sys.symbol.person_badge_plus'),
          () => {
            this.sendUserProfileAction('follow')
          },
        ),
      )
    }
    if (this.userProfileAppbar.blockLabel) {
      items.push(
        this.topicActionItem(
          this.userProfileAppbar.blocked
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
      this.userProfileAppbar.blocked ? $r('sys.symbol.eye_slash') : $r('sys.symbol.nosign'),
    ).fontColor([Color.Red])
  }

  private sendTopicAction(topicId: number, action: string): void {
    // Payload format: `${ts}:${topicId}:${action}` so each TopicDetailPage
    // instance can filter by its own topicId. Without this, the global
    // command broadcasts the action to every live TopicDetailPage
    // in the nav stack — both top and underneath — causing duplicate
    // dialogs (e.g. opening detail B from a link in detail A and tapping
    // Favorite fired the toggle on both topics).
    // Publish the V2 command mirror (read by @ComponentV2 TopicDetailPage via @Monitor, replacing the
    // former V1 TopicDetailActionListener child adapter). The timestamp keeps each command unique so a
    // repeated identical action still re-fires the @Monitor.
    const command = IndexRouteCoordinator.topicActionCommand(topicId, action, Date.now())
    connectTopicDetailAction().command = command
  }

  private refreshLocalData(): void {
    // Pure-V2: bump the local-data-changed signal mirror (read via @Monitor by @ComponentV2 AccountPage).
    connectLocalDataSignal().updatedAt = Date.now()
  }

  private sendNodeTopicAction(nodeName: string, action: string): void {
    // Publish the V2 command mirror (read by @ComponentV2 NodeTopicPage via @Monitor) from this single
    // writer; the legacy AppStorage half was retired once NodeTopicPage stopped reading the V1 key.
    const command = IndexRouteCoordinator.nodeTopicActionCommand(nodeName, action, Date.now())
    connectNodeTopicAction().command = command
  }

  private sendUserProfileAction(action: string): void {
    // Publish the V2 command mirror (read by @ComponentV2 UserProfilePage via @Monitor) from this single
    // writer; the legacy AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.simpleCommand(action, Date.now())
    connectUserProfileAction().command = command
  }

  private notifyUserProfileShown(username: string): void {
    // Publish the V2 shown mirror (read by @ComponentV2 UserProfilePage via @Monitor) from this single
    // writer; the legacy AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.userProfileShownCommand(username, Date.now())
    connectUserProfileAction().shown = command
  }

  private notifyNativeLoginShown(): void {
    // Publish the V2 resume mirror (read by @ComponentV2 V2exNativeLoginPage) from this single writer;
    // the legacy AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.simpleCommand('resume', Date.now())
    connectNativeLoginShown().command = command
  }

  private sendNotificationAction(action: string): void {
    // Publish the V2 command mirror (read by @ComponentV2 NotificationPage via @Monitor) from this single
    // writer; the legacy AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.simpleCommand(action, Date.now())
    connectNotificationAction().command = command
  }

  private sendSearchAction(action: string): void {
    // Publish the V2 command mirror (read by @ComponentV2 SearchPage) from this single writer; the legacy
    // AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.simpleCommand(action, Date.now())
    connectSearchAction().command = command
  }

  private sendImagePreviewAction(action: string): void {
    // Publish the V2 command mirror (read by @ComponentV2 ImagePreviewPage) from this single writer; the
    // legacy AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.simpleCommand(action, Date.now())
    connectImagePreviewAction().command = command
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
    const url = IndexRouteCoordinator.commandPayload(this.pendingUrl.command)
    if (!url) {
      return
    }
    if (this.openV2exRoute(url)) {
      publishPendingV2exUrl('')
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
      // Single dual-write point for the pending-query bus (AppStorage + V2 mirror).
      SearchQueryBus.publishPending(searchQuery)
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
      if (!this.pillBarContent) {
        this.pillBarContent = new ComponentContent<Object>(
          this.getUIContext(),
          wrapBuilder<[Object]>(PillCCBuilder),
          new Object(),
        )
      }
      let cc = this.pillBarContent
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
    if (this.ct === 0) {
      content['menu'] = this.homeTitleMenu()
    } else if (this.ct === 2) {
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

  private homeTitleMenu(): Record<string, Object> {
    let items: Record<string, Object>[] = IndexTitleBarCoordinator.homeMenuItems().map(
      (descriptor: IndexTitleMenuDescriptor) =>
        this.topicActionItem(descriptor.label, this.mainTitleMenuIcon(descriptor.icon), () => {
          if (descriptor.action === 'createTopic') {
            this.ns.pushPathByName('TopicEditor', null)
          }
        }),
    )
    return { 'value': items, 'maxCount': IndexTitleBarCoordinator.SINGLE_ITEM_MENU_MAX_COUNT }
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
    const path = (this.accountWebView.url || '').trim().toLowerCase()
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
    if (icon === 'compose') {
      return $r('sys.symbol.square_and_pencil')
    }
    if (icon === 'submit') {
      return $r('sys.symbol.paperplane_right_fill')
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
    // Publish the V2 command mirror (read by @ComponentV2 V2exWebLoginPage) from this single writer; the
    // legacy AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.simpleCommand(action, Date.now())
    connectWebLoginAction().command = command
  }

  private sendAccountWebViewAction(action: string): void {
    // Publish the V2 command mirror (read by @ComponentV2 AccountWebViewPage) from this single writer; the
    // legacy AppStorage half was retired once no reader read the V1 key.
    const command = IndexRouteCoordinator.simpleCommand(action, Date.now())
    connectAccountWebViewAction().command = command
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
                publishNotificationUnreadCount(count)
              }
            })
            .catch((_error: Error) => {})
          return
        }
        if (this.canApplyNotificationBadgeRequest(requestId) && !snapshot.token) {
          publishNotificationUnreadCount(0)
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
      badgeCount: idx === 2 ? this.notificationUnread.count : 0,
    })
  }
}
