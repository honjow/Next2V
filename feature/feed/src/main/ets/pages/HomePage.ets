import { FeedViewModel } from '../viewmodel/FeedViewModel'
import {
  V2exTopic, TopicCard, LoadingFooter, TopicDetailParams, ThemeConstants,
  StorageKeys, PullRefreshListScaffold, ApiConstants, TabItem, ApiService, NodeTopicListParams,
  UserProfileParams, CacheSettings, FeedTabSettings, BlockedMemberSettings, BlockedTopicFilter
} from 'shared'
import type { TopicReadState } from 'shared'
import { common } from '@kit.AbilityKit'

@Component
export struct HomePage {
  @Consume('ns') ns: NavPathStack
  @StorageLink(StorageKeys.FEED_TAB) @Watch('onFeedTabChanged') feedTab: string = 'tech'
  @StorageLink(StorageKeys.FEED_TAB_KEYS) @Watch('onFeedTabKeysChanged') feedTabKeys: string = FeedTabSettings.defaultKeysJson()
  @StorageLink(StorageKeys.FEED_TAB_VISUAL_INDEX) feedTabVisualIndex: number = 0
  @State private currentTabIndex: number = 0
  @State private swiperWidth: number = 0
  private swiperController: SwiperController = new SwiperController()
  private horizontalPan: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Horizontal,
    distance: 1
  })
  private isHorizontalSwiping: boolean = false

  aboutToAppear(): void {
    AppStorage.setOrCreate('listScrollEnabled', true)
    this.correctFeedTabIfNeeded()
    const nextIndex = this.tabKeyToIndex(this.feedTab)
    if (nextIndex < 0) {
      return
    }
    this.currentTabIndex = nextIndex
    this.setVisualTabIndex(nextIndex)
  }

  private setListScrollEnabled(enabled: boolean): void {
    AppStorage.setOrCreate('listScrollEnabled', enabled)
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
    const index = this.tabKeyToIndex(this.feedTab)
    return index < 0 ? 0 : index
  }

  private correctFeedTabIfNeeded(): boolean {
    const tabs = this.visibleTabs()
    if (tabs.length <= 0 || this.tabKeyToIndex(this.feedTab) >= 0) {
      return false
    }
    this.feedTab = tabs[0].key
    this.persistSelectedTab(tabs[0].key)
    return true
  }

  private onFeedTabChanged(_propName: string): void {
    const nextIndex = this.tabKeyToIndex(this.feedTab)
    if (nextIndex < 0) {
      return
    }
    this.persistSelectedTab(this.feedTab)
    if (nextIndex === this.currentTabIndex) {
      return
    }
    this.currentTabIndex = nextIndex
    this.animateVisualTabIndex(nextIndex)
    this.swiperController.changeIndex(nextIndex, true)
  }

  private persistSelectedTab(key: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    FeedTabSettings.saveSelectedKey(context, key).catch((error: Error) => {
      console.error('save selected feed tab failed: ' + error.message)
    })
  }

  private onFeedTabKeysChanged(_propName: string): void {
    if (this.correctFeedTabIfNeeded()) {
      return
    }
    const nextIndex = this.tabKeyToIndex(this.feedTab)
    if (nextIndex < 0) {
      return
    }
    this.currentTabIndex = nextIndex
    this.setVisualTabIndex(nextIndex)
    this.swiperController.changeIndex(nextIndex, false)
  }

  private visibleTabs(): TabItem[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedTabKeys)
  }

  private clampVisualIndex(index: number): number {
    const count = this.visibleTabs().length
    if (count <= 0) {
      return 0
    }
    return Math.max(0, Math.min(count - 1, index))
  }

  private setVisualTabIndex(index: number): void {
    this.feedTabVisualIndex = this.clampVisualIndex(index)
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
            tabKey: tab.key
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
        if (key !== this.feedTab) {
          this.feedTab = key
        }
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

@Component
struct FeedListPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink('listScrollEnabled') listScrollEnabled: boolean = true
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]'
  @StorageLink(StorageKeys.BLOCKED_MEMBERS_UPDATED_AT) @Watch('onBlockedMembersChanged') blockedMembersUpdatedAt: number = 0
  @Prop tabKey: string = 'tech'
  @State vm: FeedViewModel = new FeedViewModel()
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly GAP: number = ThemeConstants.SPACE_SM - 2
  private readonly PULL_THRESHOLD: number = 60
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly BB_H: number = ApiConstants.TAB_BAR_HEIGHT
  private scroller: Scroller = new Scroller()
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (this.tabKey === 'latest') {
      this.vm.setPagedLoader((page: number) => this.api.getRecentTopics(page))
    } else {
      this.vm.setLoader(() => this.api.getTabTopics(this.tabKey))
    }
    this.vm.setCacheHandlers(
      async () => {
        const topics = await CacheSettings.loadTopicList(context, `tab:${this.tabKey}`)
        const blockedUsernames = await BlockedMemberSettings.loadUsernames(context)
        return BlockedTopicFilter.filterTopicsByBlockedAuthors(topics, blockedUsernames)
      },
      (topics: V2exTopic[]) => CacheSettings.saveTopicList(context, `tab:${this.tabKey}`, topics)
    )
    this.vm.loadCachedData()
    this.vm.loadData()
  }

  private onBlockedMembersChanged(_propName: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    BlockedMemberSettings.loadUsernames(context)
      .then((blockedUsernames: string[]) => {
        this.vm.dataSource.filterBlockedAuthors(blockedUsernames)
      })
      .catch((error: Error) => {
        console.error('apply blocked member feed filter failed: ' + error.message)
      })
  }

  build() {
    Column() {
      if (this.vm.dataSource.totalCount() > 0) {
        Column() {
          PullRefreshListScaffold({
            scroller: this.scroller,
            listSpace: this.GAP,
            topPadding: this.BB_H,
            bottomPadding: this.FLOAT_H,
            indicatorTop: this.TBH + this.BB_H,
            refreshThreshold: this.PULL_THRESHOLD,
            scrollEnabled: this.listScrollEnabled,
            onRefresh: async () => { await this.vm.refresh() },
            onBottomRefresh: async () => { await this.vm.loadMore() },
            canStartBottomRefresh: () => this.vm.canLoadMore(),
            onReachEnd: () => { this.vm.loadMore() }
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
              }, (item: V2exTopic) => item.id.toString())

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
          Text(this.vm.errorMessage ? this.vm.errorMessage : '加载中...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_SM })
          if (this.vm.errorMessage) Button('重试')
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
      const parsed = JSON.parse(this.topicReadStates || '[]') as TopicReadState[]
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
}
