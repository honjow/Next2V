import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  AuthSettings,
  CacheSettings,
  CardEmptyState,
  CollectionSettings,
  SavedNode,
  ApiService,
  CookieJarSettings,
  IgnoredNodesSettings,
  connectLayoutSafeArea,
  connectNavStack,
  connectNodeTopicAction,
  connectNodeTopicAppbar,
  connectTopicReadStates,
  LayoutSafeAreaState,
  NodeTopicActionState,
  NodeTopicAppbarState,
  PagedListScaffold,
  PageErrorState,
  PageLoadingState,
  publishNodeTopicSaved,
  publishNodeTopicSiteFavorited,
  publishNodeTopicIgnored,
  publishNodeTopicTitle,
  publishNodeTopicSubtitle,
  publishNodeTopicAppbarTitleNodeName,
  publishNodeTopicAppbarTitleNodeAvatarUrl,
  publishNodeTopicAppbarTitleRouteNodeName,
  publishNodeTopicAppbarTitleNameStates,
  publishNodeTopicAppbarTitleAvatarStates,
  StorageKeys,
  ThemeConstants,
  TopicCard,
  TopicReadStatesState,
  TopicDetailParams,
  UserProfileParams,
  V2exNode,
  V2exToggleAction,
  V2exTopic,
  V2exRouteNavigator,
  AppStrings,
  DiagnosticLogger,
  translateApiError,
  publishAccountWebViewUrl,
} from 'shared'
import type { TopicReadState } from 'shared'
import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { NodeInfoCard } from '../components/NodeInfoCard'
import { NodeTopicPageCoordinator } from '../model/NodeTopicPageCoordinator'
@ComponentV2
export struct NodeTopicPage {
  @Param nodeName: string = '';
  @Param nodeTitle: string = '';
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack;
  // Window safe-area metrics (AppStorageV2 mirror; EntryAbility publishes V2-only).
  private layout: LayoutSafeAreaState = connectLayoutSafeArea();
  @Local vm: NodeViewModel = new NodeViewModel();
  // Per-topic read-state ledger (V2 mirror; LocalDataPublisher dual-writes). Read in build() via
  // isTopicUnread → subscribes this page to unread-dot refreshes.
  private readStates: TopicReadStatesState = connectTopicReadStates();
  // V2 mirror of the one-directional NODE_TOPIC_ACTION appbar command (Index dual-writes).
  @Local private nodeAction: NodeTopicActionState = connectNodeTopicAction();
  @Local private isNodeSaved: boolean = false;
  @Local private isSavedNodeLoading: boolean = false;
  @Local private isSiteNodeFavorited: boolean = false;
  @Local private isSiteNodeFavoriteLoading: boolean = false;
  // Node-ignore state shown in the title-bar menu. Source of truth is V2EX (the authed /go/{node} page,
  // same two-URL toggle as site favorite); the device-global IgnoredNodesSettings holder is an optimistic
  // cache kept in lockstep with the server result for instant feed-hide + logged-out fallback. The node's
  // OWN page is never node-filtered (an ignored node stays readable) — only the aggregate feeds react.
  @Local private isNodeIgnored: boolean = false;
  @Local private isNodeIgnoreLoading: boolean = false;
  @Local private token: string = '';
  private api: ApiService = new ApiService();
  private nodeTopicsRequestId: number = 0;
  // Scroll-reveal app bar identity mirror (Index reads it to render the icon+name title). This page is
  // the sole writer; the *States ledgers are keyed by routeNodeName so stacked node pages don't clash.
  private nodeAppbar: NodeTopicAppbarState = connectNodeTopicAppbar();
  @Local private nodeNameContentBottom: number = 0;
  @Local private currentScrollOffset: number = 0;
  @Local private isNodeNameCoveredByAppbar: boolean = false;
  private readonly titleVisibilityHysteresis: number = 4;

  aboutToAppear(): void {
    this.currentScrollOffset = 0
    this.nodeNameContentBottom = 0
    this.isNodeNameCoveredByAppbar = false
    this.syncNodeTitleState(false, false)
    this.syncAppbarIdentity()
    this.publishAppbarReveal(false)
    this.vm.isLoading = true
    this.setupNodeCache()
    this.primeFromCache()
    this.loadData()
    this.loadSavedState()
    this.loadSiteNodeFavoriteState()
    this.loadNodeIgnoreState()
  }

  private nodeCacheKey(): string {
    return 'node:' + (this.currentNodeName() || this.nodeName || '').trim().toLowerCase()
  }

  // Register cache write-back: each successful network load refreshes this node's cached detail +
  // first page for the next entry (NodeViewModel invokes these savers on success).
  private setupNodeCache(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const nodeName = (this.currentNodeName() || this.nodeName || '').trim()
    if (!nodeName) {
      return
    }
    const cacheKey = this.nodeCacheKey()
    this.vm.setCacheSavers(
      (node: V2exNode | null) => {
        CacheSettings.saveNodeDetail(context, nodeName, node).catch((_error: Error) => {})
      },
      (topics: V2exTopic[]) => {
        CacheSettings.saveTopicList(context, cacheKey, topics).catch((_error: Error) => {})
      },
    )
  }

  // Cache-first: paint the last-known node header + first page immediately (no spinner) while the
  // concurrent loadData() network call revalidates. prefillFromCache only fills empty fields, so if
  // the network wins the race the cache application is a harmless no-op.
  private primeFromCache(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const nodeName = (this.currentNodeName() || this.nodeName || '').trim()
    if (!nodeName) {
      return
    }
    const cacheKey = this.nodeCacheKey()
    CacheSettings.loadNodeDetail(context, nodeName)
      .then((node: V2exNode | null) => {
        CacheSettings.loadTopicList(context, cacheKey)
          .then((topics: V2exTopic[]) => {
            this.vm.prefillFromCache(node, topics)
            this.syncAppbarIdentity()
          })
          .catch((_error: Error) => {})
      })
      .catch((_error: Error) => {})
  }

  build() {
    Stack() {
      PagedListScaffold({
        isLoadingMore: this.vm.isNodeTopicsLoadingMore,
        hasMore: this.vm.nodeTopicsHasMore,
        loadMoreErrorMessage: this.vm.nodeTopicsLoadMoreError,
        loadMoreRetryLabel: AppStrings.text($r('app.string.common_retry'), 'Retry'),
        showFooter: this.vm.nodeTopics.length > 0,
        onRefresh: async () => {
          await this.refreshData()
        },
        onReachEnd: () => {
          this.loadMore()
        },
        onLoadMoreRetry: () => {
          this.loadMore()
        },
        onDidScroll: (offset: number, _state: ScrollState) => {
          this.currentScrollOffset = Math.max(0, offset)
          this.evaluateAppbarReveal()
        },
      }) {
        ListItem() {
          this.NodeHeaderCard()
        }
        if (this.vm.isLoading && this.vm.nodeTopics.length === 0) {
          ListItem() {
            Column().height(0)
          }
        } else if (this.vm.errorMessage && this.vm.nodeTopics.length === 0) {
          ListItem() {
            this.ErrorView()
          }
        } else if (this.vm.nodeTopics.length === 0) {
          // True-empty placeholder keeps the refreshable list mounted; the centered EmptyView is
          // rendered as a full-height Stack overlay below (mirrors LoadingView) so 暂无主题 sits in
          // the middle of the content area rather than top-aligned in a bare list item.
          ListItem() {
            Column().height(0)
          }
        } else {
          ForEach(this.vm.nodeTopics, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({
                item: topic,
                isUnread: this.isTopicUnread(topic),
                showNodeTag: false,
                onUserClick: () => {
                  let p: UserProfileParams = { username: topic.member.username }
                  this.stack.pushPathByName('UserProfile', p as Object)
                },
              })
            }
            .onClick(() => {
              let p: TopicDetailParams = { topicId: topic.id }
              this.stack.pushPathByName('TopicDetail', p as Object)
            })
          })
        }
      }

      if (this.vm.isLoading && this.vm.nodeTopics.length === 0) {
        this.LoadingView()
      } else if (!this.vm.errorMessage && this.vm.nodeTopics.length === 0) {
        // Distinct from loading (above) and error (kept in the list): true-empty only.
        this.EmptyView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      // Re-publish the reveal identity when this node page returns to the top of the stack so the
      // shared singleton mirror reflects THIS route again (a stacked page may have overwritten it).
      if (isVisible) {
        this.publishAppbarReveal(this.isNodeNameCoveredByAppbar)
        // Re-assert THIS node's ignore flag: a stacked node page overwrote the shared appbar holder, so the
        // overflow menu label would otherwise show the other node's state when this page returns to top.
        publishNodeTopicIgnored(this.isNodeIgnored)
      }
    })
  }

  @Builder NodeHeaderCard() {
    NodeInfoCard({
      detail: this.vm.nodeDetail,
      fallbackName: this.nodeName,
      fallbackTitle: this.nodeTitle,
      onNodeNameAreaChange: (bottom: number) => {
        // Convert the name's viewport-relative bottom into a content-space offset so the reveal
        // threshold is stable while the list scrolls (same approach as UserProfilePage).
        this.nodeNameContentBottom = bottom + this.currentScrollOffset
        this.evaluateAppbarReveal()
      },
      onHeaderLinkClick: (url: string) => {
        this.openHeaderLink(url)
      },
    })
  }

  // Node-description links did nothing when handed to the system (relative/first-party V2EX URLs no
  // external app handles them). Route first-party V2EX links into the in-app cookie WebView (logged-in
  // view); only genuinely external links go to the system browser.
  private openHeaderLink(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    // Native-first: a link that maps to a built-in destination (topic /t/, node /go/, member /member/,
    // search) opens the native page — better than the web view. Only links without a native page (dict
    // /d/, /i, /settings sub-pages, external sites, …) fall back to the cookie-injected in-app WebView.
    if (V2exRouteNavigator.openInApp(this.stack, target)) {
      return
    }
    if (target.startsWith('/') || target.startsWith('http://') || target.startsWith('https://')) {
      publishAccountWebViewUrl(target)
      this.stack.pushPathByName('AccountWebView', null)
      return
    }
    // Non-http schemes (mailto:, tel:, …) fall through to the system.
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const want: Want = { action: 'ohos.want.action.viewData', uri: target }
      context.startAbility(want).catch((_error: Error) => {})
    } catch (_error) {
      // best-effort external open
    }
  }

  @Builder LoadingView() {
    Column() {
      PageLoadingState()
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({
      top: this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT,
      bottom: this.layout.bottomAvoidHeight,
    })
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder EmptyView() {
    // Center 暂无主题 within the content area (between the overlaid title bar and the bottom safe
    // area), mirroring LoadingView. HitTestMode.None lets pull-to-refresh reach the empty list
    // underneath. Layout is expressed via the shared safe-area state + TITLE_BAR_HEIGHT constant
    // (semantic insets for the overlaid HdsNavigation title bar + window safe areas), not a magic
    // fixed height.
    Column() {
      CardEmptyState({
        message: AppStrings.text($r('app.string.node_no_topics'), 'No topics'),
        expand: false,
      })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({
      top: this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT,
      bottom: this.layout.bottomAvoidHeight,
    })
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder ErrorView() {
    PageErrorState({
      message:
        this.vm.errorMessage ||
        AppStrings.text($r('app.string.node_load_failed'), 'Failed to load node topics'),
      expand: false,
      retryAction: () => {
        this.loadData()
      },
    })
  }

  private loadSavedState(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const nodeName = this.currentNodeName()
    if (!nodeName) {
      this.syncNodeTitleState(false, this.isSiteNodeFavorited)
      return
    }
    CollectionSettings.isNodeSaved(context, nodeName)
      .then((saved: boolean) => {
        this.isNodeSaved = saved
        publishNodeTopicSaved(saved)
      })
      .catch((error: Error) => {
        console.error('load saved node state failed: ' + error.message)
      })
  }

  private loadSiteNodeFavoriteState(): void {
    if (this.isSiteNodeFavoriteLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || !this.nodeName) {
      this.isSiteNodeFavorited = false
      publishNodeTopicSiteFavorited(false)
      return
    }
    this.isSiteNodeFavoriteLoading = true
    this.api
      .getNodeFavoriteToggleActionWithCookie(cookie, this.nodeName)
      .then((toggle: V2exToggleAction) => {
        this.isSiteNodeFavorited = toggle.currentlyOn
        publishNodeTopicSiteFavorited(toggle.currentlyOn)
      })
      .catch((error: Error) => {
        console.error('load site node favorite state failed: ' + error.message)
      })
      .finally(() => {
        this.isSiteNodeFavoriteLoading = false
      })
  }

  private prepareSiteNodeFavoriteToggle(): void {
    if (this.isSiteNodeFavoriteLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.api_error_auth_required'), 'Please sign in'),
        })
        .catch((_error: Error) => {})
      return
    }
    const cleanName = (this.nodeName || '').trim()
    if (!cleanName) {
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.node_info_missing'), 'Node info missing'),
        })
        .catch((_error: Error) => {})
      return
    }
    this.isSiteNodeFavoriteLoading = true
    this.api
      .getNodeFavoriteToggleActionWithCookie(cookie, cleanName)
      .then((toggle: V2exToggleAction) => {
        this.isSiteNodeFavorited = toggle.currentlyOn
        publishNodeTopicSiteFavorited(toggle.currentlyOn)
        this.confirmSiteNodeFavoriteToggle(cookie, cleanName, toggle)
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isSiteNodeFavoriteLoading = false
      })
  }

  private confirmSiteNodeFavoriteToggle(
    cookie: string,
    nodeName: string,
    toggle: V2exToggleAction,
  ): void {
    const title = (this.nodeTitle || this.nodeName || '').trim()
    const verb = this.isSiteNodeFavorited
      ? AppStrings.text($r('app.string.site_favorite_action_unfavorite'), 'Unfavorite')
      : AppStrings.text($r('app.string.site_favorite_action_favorite'), 'Favorite')
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.site_favorite_title'), 'Site Favorite'),
      message: title
        ? AppStrings.format(
            AppStrings.text($r('app.string.site_favorite_confirm'), 'Confirm {0} node "{1}"?'),
            [verb, title],
          )
        : `${verb} this node?`,
      primaryButton: {
        value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: verb,
        action: () => {
          this.executeSiteNodeFavoriteToggle(cookie, nodeName, toggle)
        },
      },
    })
  }

  private executeSiteNodeFavoriteToggle(
    cookie: string,
    nodeName: string,
    toggle: V2exToggleAction,
  ): void {
    if (this.isSiteNodeFavoriteLoading) {
      return
    }
    this.isSiteNodeFavoriteLoading = true
    this.api
      .executeNodeFavoriteToggleWithCookie(cookie, nodeName, toggle)
      .then((favorited: boolean) => {
        this.isSiteNodeFavorited = favorited
        publishNodeTopicSiteFavorited(favorited)
        promptAction
          .openToast({
            message: favorited ? $r('app.string.favorited') : $r('app.string.unfavorited'),
          })
          .catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isSiteNodeFavoriteLoading = false
      })
  }

  private async refreshData(): Promise<void> {
    await this.loadData()
    this.loadSavedState()
    this.loadSiteNodeFavoriteState()
    // Re-throw so the shared PullRefresh shows a single "刷新失败" toast. loadData() swallows the fetch
    // error into vm.errorMessage (cleared at each load start, set only when every source incl. the
    // api_v2→web fallback failed). The bare initial-load / error-retry callers use loadData() directly
    // and keep swallowing, so an empty first load shows the inline error and never toasts.
    if (this.vm.errorMessage) {
      throw new Error(this.vm.errorMessage)
    }
  }

  private async loadData(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const nodeName = this.currentNodeName() || this.nodeName
    const requestId = ++this.nodeTopicsRequestId
    let source = 'web'
    // Carry the authenticated cookie (if any) into web node-topic loads so login-gated nodes
    // (e.g. /go/sandbox) are fetched as the signed-in session instead of anonymous public HTML.
    // Used by the non-token web path AND the API-v2→web fallback, plus page 2+ load-more.
    this.vm.setNodeTopicsWebCookie(CookieJarSettings.getCurrentCookie())
    try {
      const snapshot = await AuthSettings.load(context)
      this.token = snapshot.token || ''
      if (this.token) {
        source = 'api_v2'
        this.vm.beginNodeTopicsPageOneLoad(nodeName, 'api_v2', requestId)
        this.logNodeTopicLoadStart(nodeName, source, requestId)
        await this.vm.loadNodeDetailV2(nodeName, this.token)
        const topicsLoaded = await this.vm.loadNodeTopicsV2(nodeName, this.token, {
          requestId: requestId,
          source: 'api_v2',
        })
        if (!topicsLoaded) {
          await this.loadNodeTopicsWebFallback(nodeName, requestId)
        }
      } else {
        source = 'web'
        this.vm.beginNodeTopicsPageOneLoad(nodeName, 'web', requestId)
        this.logNodeTopicLoadStart(nodeName, source, requestId)
        await this.vm.loadNodeDetail(nodeName)
        await this.vm.loadNodeTopics(nodeName, { requestId: requestId, source: 'web' })
      }
      this.syncAppbarIdentity()
    } catch (error) {
      const e = error as Error
      this.token = ''
      this.vm.nodeDetailError = translateApiError(error)
      this.vm.beginNodeTopicsPageOneLoad(nodeName, 'web', requestId)
      this.logNodeTopicLoadStart(nodeName, 'web', requestId)
      DiagnosticLogger.warn(
        'ui_lifecycle',
        'node_topic_source_fail',
        {
          nodeName: nodeName,
          source: source,
          page: 1,
          requestId: requestId,
          count: 0,
          firstIds: [],
          errorKind: e.name || 'Error',
        },
        e,
      )
      await this.vm.loadNodeDetail(nodeName)
      await this.vm.loadNodeTopics(nodeName, {
        requestId: requestId,
        source: 'web',
        fallback: true,
      })
      this.syncAppbarIdentity()
    }
  }

  private async loadNodeTopicsWebFallback(nodeName: string, requestId: number): Promise<void> {
    DiagnosticLogger.info('ui_lifecycle', 'node_topic_fallback', {
      nodeName: nodeName,
      source: 'web',
      page: 1,
      requestId: requestId,
      count: 0,
      firstIds: [],
    })
    if (!this.vm.switchNodeTopicsPageOneSource(nodeName, 'web', requestId)) {
      return
    }
    await this.vm.loadNodeTopics(nodeName, { requestId: requestId, source: 'web', fallback: true })
  }

  private logNodeTopicLoadStart(nodeName: string, source: string, requestId: number): void {
    DiagnosticLogger.info('ui_lifecycle', 'node_topic_page_load_start', {
      nodeName: nodeName,
      source: source,
      page: 1,
      requestId: requestId,
      count: 0,
      firstIds: [],
    })
  }

  private loadMore(): void {
    if (this.vm.isLoading || !this.vm.hasNodeTopicsPageOneSettled()) {
      return
    }
    if (this.vm.nodeTopicsUseV2 && this.token) {
      this.vm.loadMoreNodeTopicsV2(this.nodeName, this.token).finally(() => {
        this.syncAppbarIdentity()
      })
      return
    }
    this.vm.loadMoreNodeTopics(this.nodeName).finally(() => {
      this.syncAppbarIdentity()
    })
  }

  private toggleSavedNode(): void {
    if (this.isSavedNodeLoading) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const nodeName = this.currentNodeName()
    if (!nodeName) {
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.node_info_missing'), 'Node info missing'),
        })
        .catch((_error: Error) => {})
      return
    }
    const node: SavedNode = {
      name: nodeName,
      title: CollectionSettings.cleanNodeTitle(
        this.vm.nodeDetail?.title || this.nodeTitle || nodeName,
        this.vm.nodeDetail?.topics || 0,
      ),
      topics: this.vm.nodeDetail?.topics || 0,
      avatarMini: this.vm.nodeDetail?.avatar_mini,
      avatarNormal: this.vm.nodeDetail?.avatar_normal,
      avatarLarge: this.vm.nodeDetail?.avatar_large,
      // CollectionSettings.saveNode always re-stamps savedAt with its own server-time-aligned
      // value (see upsertSavedNode), so the caller's value is ignored — pass 0 rather than a
      // wall-clock timestamp the migrated leaf would otherwise carry (forbidden by the contract).
      savedAt: 0,
    }
    this.isSavedNodeLoading = true
    const request = this.isNodeSaved
      ? CollectionSettings.removeNode(context, nodeName)
      : CollectionSettings.saveNode(context, node)
    request
      .then((nodes: SavedNode[]) => {
        this.isNodeSaved = nodes.some((item: SavedNode) => item.name === nodeName)
        publishNodeTopicSaved(this.isNodeSaved)
      })
      .catch((error: Error) => {
        console.error('toggle saved node failed: ' + error.message)
      })
      .finally(() => {
        this.isSavedNodeLoading = false
      })
  }

  private isTopicUnread(topic: V2exTopic): boolean {
    if (topic.id <= 0) {
      return false
    }
    const lastTouched = topic.last_touched || topic.last_modified || topic.created
    const state = this.findReadState(topic.id)
    if (!state) {
      return true
    }
    return lastTouched > state.touchedAt
  }

  private findReadState(topicId: number): TopicReadState | null {
    try {
      const parsed = JSON.parse(this.readStates.statesJson || '[]') as TopicReadState[]
      if (!Array.isArray(parsed)) {
        return null
      }
      for (let i = 0; i < parsed.length; i++) {
        if (parsed[i].id === topicId) {
          return parsed[i]
        }
      }
      return null
    } catch (_e) {
      return null
    }
  }

  @Monitor('nodeAction.command')
  onNodeTopicActionCommand(): void {
    const raw = (this.nodeAction.command || '').trim()
    if (!raw) {
      return
    }
    const parts = raw.split(':')
    const action = parts.pop() || ''
    const targetNodeName = parts.length >= 2 ? (parts.pop() || '').trim() : ''
    if (targetNodeName && targetNodeName !== this.currentNodeName()) {
      return
    }
    if (action === 'siteFavorite') {
      this.prepareSiteNodeFavoriteToggle()
    } else if (action === 'saveNode') {
      this.toggleSavedNode()
    } else if (action === 'ignoreNode') {
      this.toggleNodeIgnore()
    }
  }

  // Load the node-ignore state. Source of truth is V2EX (authed /go/{node} page); the optimistic cache is
  // synced to the server result. Logged out, fall back to the cache so the menu still reflects local state.
  private loadNodeIgnoreState(): void {
    const nodeName = this.currentNodeName()
    if (!nodeName) {
      this.isNodeIgnored = false
      publishNodeTopicIgnored(false)
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      const ignored = IgnoredNodesSettings.isIgnored(nodeName)
      this.isNodeIgnored = ignored
      publishNodeTopicIgnored(ignored)
      return
    }
    if (this.isNodeIgnoreLoading) {
      return
    }
    this.isNodeIgnoreLoading = true
    this.api
      .getNodeIgnoreToggleActionWithCookie(cookie, nodeName)
      .then((toggle: V2exToggleAction) => {
        this.isNodeIgnored = toggle.currentlyOn
        publishNodeTopicIgnored(toggle.currentlyOn)
        // Mirror server truth into the optimistic feed-filter cache.
        IgnoredNodesSettings.setIgnored(nodeName, toggle.currentlyOn)
      })
      .catch((error: Error) => {
        // Passive load: don't toast; show the cached view so the menu is not blank.
        const ignored = IgnoredNodesSettings.isIgnored(nodeName)
        this.isNodeIgnored = ignored
        publishNodeTopicIgnored(ignored)
        console.error('load node ignore state failed: ' + error.message)
      })
      .finally(() => {
        this.isNodeIgnoreLoading = false
      })
  }

  // Toggle node-ignore. Logged in → write to V2EX (so it syncs with the web and the authed home/recent/hot
  // feeds drop the node server-side), then mirror the confirmed state into the optimistic cache. Logged out
  // → local-only optimistic toggle (the best achievable without a session). The node's OWN page is never
  // emptied either way.
  private toggleNodeIgnore(): void {
    if (this.isNodeIgnoreLoading) {
      return
    }
    const nodeName = this.currentNodeName()
    if (!nodeName) {
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.node_info_missing'), 'Node info missing'),
        })
        .catch((_error: Error) => {})
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      const ignored = IgnoredNodesSettings.toggle(nodeName)
      this.isNodeIgnored = ignored
      publishNodeTopicIgnored(ignored)
      this.toastIgnoreResult(ignored)
      return
    }
    this.isNodeIgnoreLoading = true
    this.api
      .toggleNodeIgnoreWithCookie(cookie, nodeName)
      .then((ignored: boolean) => {
        this.isNodeIgnored = ignored
        publishNodeTopicIgnored(ignored)
        // Keep the optimistic feed-filter cache in lockstep with the server.
        IgnoredNodesSettings.setIgnored(nodeName, ignored)
        this.toastIgnoreResult(ignored)
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isNodeIgnoreLoading = false
      })
  }

  private toastIgnoreResult(ignored: boolean): void {
    promptAction
      .openToast({
        message: ignored ? $r('app.string.node_ignored_toast') : $r('app.string.node_unignored_toast'),
      })
      .catch((_error: Error) => {})
  }

  private currentNodeName(): string {
    return (this.nodeName || this.vm.nodeDetail?.name || '').trim()
  }

  private syncNodeTitleState(saved: boolean, siteFavorited: boolean): void {
    this.isNodeSaved = saved
    this.isSiteNodeFavorited = siteFavorited
    publishNodeTopicSaved(saved)
    publishNodeTopicSiteFavorited(siteFavorited)
  }

  private syncAppbarIdentity(): void {
    const title = CollectionSettings.cleanNodeTitle(
      this.vm.nodeDetail?.title || this.nodeTitle || this.nodeName,
      this.vm.nodeDetail?.topics || 0,
    )
    publishNodeTopicTitle(title)
    const identityName = (this.nodeName || '').trim()
    const subtitleParts: string[] = []
    if (title && identityName && title !== identityName) {
      subtitleParts.push(identityName)
    }
    const topicCount = this.vm.nodeDetail?.topics || 0
    if (topicCount > 0) {
      subtitleParts.push(
        AppStrings.format(AppStrings.text($r('app.string.node_topics_count'), '{0} topics'), [
          String(topicCount),
        ]),
      )
    }
    publishNodeTopicSubtitle(subtitleParts.join(' · '))
    // Re-evaluate the scroll reveal: a freshly-resolved detail can change the display name / avatar
    // shown in the revealed title even if the scroll geometry is unchanged.
    this.evaluateAppbarReveal()
    this.publishAppbarReveal(this.isNodeNameCoveredByAppbar)
  }

  private displayNodeName(): string {
    return NodeTopicPageCoordinator.displayName(
      this.vm.nodeDetail?.title || '',
      this.nodeTitle,
      this.vm.nodeDetail?.name || this.nodeName,
    )
  }

  private nodeAvatarUrl(): string {
    return (this.vm.nodeDetail?.avatar_large || this.vm.nodeDetail?.avatar_normal || '').trim()
  }

  private evaluateAppbarReveal(): void {
    const shouldReveal = NodeTopicPageCoordinator.shouldShowAppbarTitle(
      this.displayNodeName(),
      this.nodeNameContentBottom,
      this.currentScrollOffset,
      this.layout.topAvoidHeight,
      ThemeConstants.TITLE_BAR_HEIGHT,
      this.isNodeNameCoveredByAppbar,
      this.titleVisibilityHysteresis,
    )
    if (shouldReveal === this.isNodeNameCoveredByAppbar) {
      return
    }
    this.isNodeNameCoveredByAppbar = shouldReveal
    this.publishAppbarReveal(shouldReveal)
  }

  private publishAppbarReveal(visible: boolean): void {
    const routeNodeName = (this.nodeName || '').trim()
    if (!routeNodeName) {
      return
    }
    const identity = NodeTopicPageCoordinator.appbarIdentity(
      visible,
      routeNodeName,
      this.displayNodeName(),
      this.nodeAvatarUrl(),
    )
    // OUTPUT-only fields: this page is the sole writer of the node appbar reveal mirror; Index reads it
    // to build the icon+name title. Change-guard against the live mirror so we only write on real changes.
    if (this.nodeAppbar.titleRouteNodeName !== identity.routeNodeName) {
      publishNodeTopicAppbarTitleRouteNodeName(identity.routeNodeName)
    }
    if (this.nodeAppbar.titleNodeName !== identity.titleNodeName) {
      publishNodeTopicAppbarTitleNodeName(identity.titleNodeName)
    }
    if (this.nodeAppbar.titleNodeAvatarUrl !== identity.avatarUrl) {
      publishNodeTopicAppbarTitleNodeAvatarUrl(identity.avatarUrl)
    }
    // Per-route ledgers keyed by routeNodeName so a stacked node page reads back its own reveal state.
    publishNodeTopicAppbarTitleNameStates(
      NodeTopicPageCoordinator.nextStringState(
        this.nodeAppbar.titleNameStates,
        routeNodeName,
        identity.titleNodeName,
      ),
    )
    publishNodeTopicAppbarTitleAvatarStates(
      NodeTopicPageCoordinator.nextStringState(
        this.nodeAppbar.titleAvatarStates,
        routeNodeName,
        identity.avatarUrl,
      ),
    )
  }
}
