import { FeedViewModel } from '../viewmodel/FeedViewModel'
import {
  V2exTopic, TopicCard, LoadingFooter, TopicDetailParams, ThemeConstants,
  PullRefreshListScaffold, ApiConstants, TabItem, ApiService, NodeTopicListParams,
  UserProfileParams, CacheSettings, FeedTabSettings, CollectionSettings,
  connectNavStack, connectFeedTab, FeedTabBridge, connectListScroll, connectTopicReadStates,
  FeedTabState, ListScrollState, PullRefreshController, TopicReadStatesState
} from 'shared'
import type { TopicReadState } from 'shared'
import { common } from '@kit.AbilityKit'

@ComponentV2
export struct HomePage {
  // V2 mirror of the feed-tab group (FeedTabBridge dual-writes feedTab/feedTabKeys; HomePage owns
  // feedTabVisualIndex). @Monitor-watched below for tab/keys changes; read in build() to drive the swiper.
  @Local private feedTabState: FeedTabState = connectFeedTab()
  @Local private currentTabIndex: number = 0
  @Local private swiperWidth: number = 0
  private swiperController: SwiperController = new SwiperController()
  private horizontalPan: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Horizontal,
    distance: 1
  })
  private isHorizontalSwiping: boolean = false
  private feedScrollers: Map<string, Scroller> = new Map<string, Scroller>()
  private feedRootRefreshActions: Map<string, () => void> = new Map<string, () => void>()
  // Pure-V2 list-scroll lock; the inner FeedListPage reads .enabled. Write-only from HomePage.
  private listScroll: ListScrollState = connectListScroll()
  @Event onRootRefreshReady?: (action: () => void) => void
  @Event onScrollerReady?: (scroller: Scroller) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

  aboutToAppear(): void {
    this.listScroll.enabled = true
    this.correctFeedTabIfNeeded()
    const nextIndex = this.tabKeyToIndex(this.feedTabState.feedTab)
    if (nextIndex < 0) {
      return
    }
    this.currentTabIndex = nextIndex
    this.setVisualTabIndex(nextIndex)
    this.notifyMainScrollerReady()
    this.notifyRootRefreshReady()
  }

  private scrollerForTab(tabKey: string): Scroller {
    const existing = this.feedScrollers.get(tabKey)
    if (existing) {
      return existing
    }
    const scroller = new Scroller()
    this.feedScrollers.set(tabKey, scroller)
    return scroller
  }

  private notifyMainScrollerReady(): void {
    if (!this.onScrollerReady) {
      return
    }
    const scroller = this.feedScrollers.get(this.feedTabState.feedTab)
    if (scroller) {
      this.onScrollerReady(scroller)
    }
  }

  private onFeedScrollerReady(tabKey: string, scroller: Scroller): void {
    this.feedScrollers.set(tabKey, scroller)
    if (tabKey === this.feedTabState.feedTab) {
      this.notifyMainScrollerReady()
    }
  }

  private onFeedRootRefreshReady(tabKey: string, action: () => void): void {
    this.feedRootRefreshActions.set(tabKey, action)
    if (tabKey === this.feedTabState.feedTab) {
      this.notifyRootRefreshReady()
    }
  }

  private notifyRootRefreshReady(): void {
    if (this.onRootRefreshReady) {
      this.onRootRefreshReady(() => {
        this.triggerActiveFeedRootRefresh()
      })
    }
  }

  private triggerActiveFeedRootRefresh(): void {
    const action = this.feedRootRefreshActions.get(this.feedTabState.feedTab)
    if (action) {
      action()
    }
  }

  private onFeedDidScroll(tabKey: string, offset: number, state: ScrollState): void {
    if (tabKey !== this.feedTabState.feedTab || !this.onDidScroll) {
      return
    }
    this.onDidScroll(offset, state)
  }

  private setListScrollEnabled(enabled: boolean): void {
    this.listScroll.enabled = enabled
  }

  private lockListScrollIfHorizontal(event: GestureEvent): void {
    if (Math.abs(event.offsetX) <= Math.abs(event.offsetY)) {
      return
    }
    this.isHorizontalSwiping = true
    this.setListScrollEnabled(false)
  }

  private unlockListScrollAfterHorizontalPan(): void {
    if (!this.isHorizontalSwiping) {
      return
    }
    this.isHorizontalSwiping = false
    this.setListScrollEnabled(true)
  }

  private tabKeyToIndex(key: string): number {
    let idx = this.visibleTabs().findIndex(t => t.key === key)
    return idx
  }

  private feedTabIndexOrFallback(): number {
    const index = this.tabKeyToIndex(this.feedTabState.feedTab)
    return index < 0 ? 0 : index
  }

  private correctFeedTabIfNeeded(): boolean {
    const tabs = this.visibleTabs()
    if (tabs.length <= 0 || this.tabKeyToIndex(this.feedTabState.feedTab) >= 0) {
      return false
    }
    FeedTabBridge.publishSelectedKey(tabs[0].key)
    this.persistSelectedTab(tabs[0].key)
    return true
  }

  @Monitor('feedTabState.feedTab')
  onFeedTabChanged(): void {
    const nextIndex = this.tabKeyToIndex(this.feedTabState.feedTab)
    if (nextIndex < 0) {
      return
    }
    this.persistSelectedTab(this.feedTabState.feedTab)
    if (nextIndex === this.currentTabIndex) {
      return
    }
    this.currentTabIndex = nextIndex
    this.animateVisualTabIndex(nextIndex)
    this.notifyMainScrollerReady()
    this.notifyRootRefreshReady()
    this.swiperController.changeIndex(nextIndex, true)
  }

  private persistSelectedTab(key: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    FeedTabSettings.saveSelectedKey(context, key).catch((error: Error) => {
      console.error('save selected feed tab failed: ' + error.message)
    })
  }

  @Monitor('feedTabState.feedTabKeys')
  onFeedTabKeysChanged(): void {
    if (this.correctFeedTabIfNeeded()) {
      return
    }
    const nextIndex = this.tabKeyToIndex(this.feedTabState.feedTab)
    if (nextIndex < 0) {
      return
    }
    this.currentTabIndex = nextIndex
    this.setVisualTabIndex(nextIndex)
    this.notifyMainScrollerReady()
    this.notifyRootRefreshReady()
    this.swiperController.changeIndex(nextIndex, false)
  }

  private visibleTabs(): TabItem[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedTabState.feedTabKeys)
  }

  private clampVisualIndex(index: number): number {
    const count = this.visibleTabs().length
    if (count <= 0) {
      return 0
    }
    return Math.max(0, Math.min(count - 1, index))
  }

  private setVisualTabIndex(index: number): void {
    FeedTabBridge.publishVisualIndex(this.clampVisualIndex(index))
  }

  private animateVisualTabIndex(index: number): void {
    this.getUIContext().animateTo({ duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut }, () => {
      this.setVisualTabIndex(index)
    })
  }

  private visualTabIndexFromOffset(index: number, extraInfo: SwiperAnimationEvent): number {
    if (this.swiperWidth <= 0) {
      return index
    }
    const progress = -extraInfo.currentOffset / this.swiperWidth
    return index + progress
  }

  private syncVisualTabFromOffset(index: number, extraInfo: SwiperAnimationEvent): void {
    this.setVisualTabIndex(this.visualTabIndexFromOffset(index, extraInfo))
  }

  private animateVisualTabFromRelease(index: number, targetIndex: number, extraInfo: SwiperAnimationEvent): void {
    this.setVisualTabIndex(this.visualTabIndexFromOffset(index, extraInfo))
    this.animateVisualTabIndex(targetIndex)
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        ForEach(this.visibleTabs(), (tab: TabItem) => {
          FeedListPage({
            tabKey: tab.key,
            scroller: this.scrollerForTab(tab.key),
            onScrollerReady: (tabKey: string, scroller: Scroller) => {
              this.onFeedScrollerReady(tabKey, scroller)
            },
            onRootRefreshReady: (tabKey: string, action: () => void) => {
              this.onFeedRootRefreshReady(tabKey, action)
            },
            onDidScroll: (tabKey: string, offset: number, state: ScrollState) => {
              this.onFeedDidScroll(tabKey, offset, state)
            },
          })
        }, (tab: TabItem) => tab.key)
      }
      .index(this.feedTabIndexOrFallback())
      .cachedCount(1)
      .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
      .indicator(false)
      .onAnimationStart((index: number, targetIndex: number, extraInfo: SwiperAnimationEvent) => {
        this.setListScrollEnabled(false)
        this.animateVisualTabFromRelease(index, targetIndex, extraInfo)
      })
      .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
        this.setListScrollEnabled(false)
        this.syncVisualTabFromOffset(index, extraInfo)
      })
      .onAnimationEnd((index: number, extraInfo: SwiperAnimationEvent) => {
        this.setListScrollEnabled(true)
        this.setVisualTabIndex(index)
      })
      .onChange((i: number) => {
        const tab = this.visibleTabs()[i]
        if (!tab) {
          return
        }
        const key = tab.key
        this.currentTabIndex = i
        this.setVisualTabIndex(i)
        if (key !== this.feedTabState.feedTab) {
          FeedTabBridge.publishSelectedKey(key)
        }
        this.notifyMainScrollerReady()
        this.persistSelectedTab(key)
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.swiperWidth = (newValue?.width as number) || 0
      })
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    .parallelGesture(
      PanGesture(this.horizontalPan)
        .onActionStart((event: GestureEvent) => {
          this.lockListScrollIfHorizontal(event)
        })
        .onActionUpdate((event: GestureEvent) => {
          this.lockListScrollIfHorizontal(event)
        })
        .onActionEnd((event: GestureEvent) => {
          this.unlockListScrollAfterHorizontalPan()
        })
        .onActionCancel(() => {
          this.unlockListScrollAfterHorizontalPan()
        })
    )
  }
}

@ComponentV2
struct FeedListPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private ns: NavPathStack = connectNavStack().stack
  // Pure-V2 list-scroll lock written by HomePage; read in build() for the scaffold's scrollEnabled.
  private listScroll: ListScrollState = connectListScroll()
  // Per-topic read-state ledger (V2 mirror; LocalDataPublisher dual-writes). Read in build() (unread dot).
  private readStates: TopicReadStatesState = connectTopicReadStates()
  @Param tabKey: string = 'tech'
  @Local vm: FeedViewModel = new FeedViewModel()
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly GAP: number = ThemeConstants.SPACE_SM - 2
  private readonly BB_H: number = ApiConstants.TAB_BAR_HEIGHT
  private rootRefreshController: PullRefreshController = new PullRefreshController()
  @Param scroller: Scroller = new Scroller()
  @Event onScrollerReady?: (tabKey: string, scroller: Scroller) => void
  @Event onRootRefreshReady?: (tabKey: string, action: () => void) => void
  @Event onDidScroll?: (tabKey: string, offset: number, state: ScrollState) => void
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    if (this.onScrollerReady) {
      this.onScrollerReady(this.tabKey, this.scroller)
    }
    if (this.onRootRefreshReady) {
      this.onRootRefreshReady(this.tabKey, () => {
        this.triggerRootRefresh()
      })
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (this.tabKey === 'latest') {
      this.vm.setPagedResultLoader((page: number) => this.api.getAllTopicsPage(page))
    } else {
      this.vm.setLoader(() => this.api.getTabTopics(this.tabKey))
    }
    this.vm.setCacheHandlers(
      async () => {
        const topics = await CacheSettings.loadTopicList(context, `tab:${this.tabKey}`)
        return topics
      },
      (topics: V2exTopic[]) => CacheSettings.saveTopicList(context, `tab:${this.tabKey}`, topics),
      () => CollectionSettings.syncTopicReadStates(context),
    )
    this.vm.loadCachedData()
    this.vm.loadData()
  }

  private triggerRootRefresh(): void {
    this.rootRefreshController.triggerTopRefresh()
  }

  build() {
    Column() {
      if (this.vm.itemCount > 0) {
        Column() {
          PullRefreshListScaffold({
            scroller: this.scroller,
            listSpace: this.GAP,
            topPadding: this.BB_H,
            bottomPadding: this.FLOAT_H,
            scrollEnabled: this.listScroll.enabled,
            controller: this.rootRefreshController,
            onRefresh: async () => { await this.vm.refresh() },
            onBottomRefresh: async () => { await this.vm.loadMore() },
            canStartBottomRefresh: () => this.vm.canLoadMore(),
            onReachEnd: () => { this.vm.loadMore() },
            onDidScroll: (offset: number, state: ScrollState) => {
              if (this.onDidScroll) {
                this.onDidScroll(this.tabKey, offset, state)
              }
            }
          }) {
              LazyForEach(this.vm.dataSource, (item: V2exTopic) => {
                ListItem() {
                  TopicCard({
                    item: item,
                    isUnread: this.isTopicUnread(item),
                    onUserClick: () => {
                      let p: UserProfileParams = { username: item.member.username }
                      this.ns.pushPathByName('UserProfile', p as Object)
                    },
                    onNodeClick: () => {
                      let p: NodeTopicListParams = { nodeName: item.node.name, nodeTitle: item.node.title }
                      this.ns.pushPathByName('NodeTopicList', p as Object)
                    }
                  })
                }
                  .onClick(() => {
                    let p: TopicDetailParams = { topicId: item.id }
                    this.ns.pushPathByName('TopicDetail', p as Object)
                  })
              }, (item: V2exTopic) => this.topicCardRenderKey(item))

              if (this.tabKey === 'latest') {
                ListItem() {
                  LoadingFooter({
                    isLoading: this.vm.isLoadingMore,
                    hasMore: this.vm.hasMore,
                    isError: !!this.vm.errorMessage && this.vm.hasMore,
                    onRetry: () => { this.vm.loadMore() }
                  })
                }
              }
          }
        }
        .width('100%').height('100%')
      } else {
        Column() {
          LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
          Text(this.vm.errorMessage ? this.vm.errorMessage : $r('app.string.common_loading'))
            .fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_SM })
          if (this.vm.errorMessage) Button($r('app.string.common_retry'))
            .margin({ top: ThemeConstants.SPACE_LG })
            .onClick(() => this.vm.loadData())
        }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      }
    }
    .width('100%').height('100%')
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

  private topicCardRenderKey(topic: V2exTopic): string {
    const pro = (topic.member.pro || 0) > 0 ? 'pro' : 'plain'
    const mod = (topic.member.mod || 0) > 0 ? 'mod' : 'member'
    const pinned = (topic.pinned || 0) > 0 ? 'pinned' : 'normal'
    const lastReplyBy = (topic.last_reply_by || '').trim()
    const lastTouched = topic.last_touched || topic.last_modified || topic.created
    return `${topic.id}-${pro}-${mod}-${pinned}-${topic.replies}-${lastTouched}-${lastReplyBy}`
  }
}
