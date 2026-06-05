import { NodeIndexViewModel } from '../viewmodel/NodeIndexViewModel'
import {
  ApiService, AppStrings, connectDiscoverKeyword, connectLayoutSafeArea, connectNavStack, DiagnosticLogger,
  DiscoverKeywordState, LayoutSafeAreaState, PullRefresh, V2exNode, V2exTopic, NodeTopicListParams, TopicDetailParams,
  ThemeConstants, CollectionSettings, translateApiError
} from 'shared'
import type { SavedNode, V2exNodeNavigationSection } from 'shared'
import { common } from '@kit.AbilityKit'
import { LengthMetrics } from '@kit.ArkUI'
import {
  DiscoverEmptyState,
  DiscoverErrorState,
  DiscoverHotTopicRow,
  DiscoverNodeCard,
  DiscoverNodeChip,
  DiscoverSectionTitle,
  DiscoverTopicMode,
  DiscoverTopicModeButton
} from '../components/DiscoverPageComponents'
import { DiscoverPageCoordinator, DiscoverTopicBuckets } from '../model/DiscoverPageCoordinator'

@ComponentV2
export struct DiscoverPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private ns: NavPathStack = connectNavStack().stack
  @Local vm: NodeIndexViewModel = new NodeIndexViewModel()
  @Local private topicMode: DiscoverTopicMode = 'hot'
  @Local private hotTopics: V2exTopic[] = []
  @Local private latestTopics: V2exTopic[] = []
  @Local private recentTopics: V2exTopic[] = []
  @Local private hotError: string = ''
  @Local private isHotLoading: boolean = false
  @Local private scrollEnabled: boolean = true
  @Local private nodeNavigationSections: V2exNodeNavigationSection[] = []
  // Discover node-search keyword, shared with the title-bar search field via AppStorageV2.
  @Local private kwState: DiscoverKeywordState = connectDiscoverKeyword()
  @Local private savedNodes: SavedNode[] = []
  @Local private recentNodes: SavedNode[] = []
  // Window safe-area metrics (AppStorageV2 mirror; EntryAbility publishes V2-only).
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly BBH: number = 48
  private readonly GAP: number = ThemeConstants.SPACE_MD
  private readonly PULL_REFRESH_THRESHOLD: number = 84
  @Param scroller: Scroller = new Scroller()
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  private api: ApiService = new ApiService()
  private hasStartedInitialLoad: boolean = false
  @Param currentTab: number = 0

  @Monitor('kwState.keyword')
  private onKeywordChanged(): void {
    this.vm.setNodeFilter(this.kwState.keyword)
    if (this.hasNodeSearchQuery() && this.vm.nodeIndexPhase !== 'loading' && this.vm.nodeIndexPhase !== 'loaded') {
      this.vm.loadAllNodes({ publishDefaultNodes: true })
    }
  }

  @Monitor('currentTab')
  private onCurrentTabChanged(): void {
    this.requestInitialLoad('currentTabChanged')
  }

  aboutToAppear(): void {
    this.kwState.keyword = this.vm.keyword
    this.requestInitialLoad('aboutToAppear')
  }

  private requestInitialLoad(reason: string): void {
    if (this.hasStartedInitialLoad) {
      DiagnosticLogger.info('ui_lifecycle', 'discover_initial_load_skip_started', {
        reason: reason,
        currentTab: this.currentTab,
        started: this.hasStartedInitialLoad,
        skipped: true
      })
      return
    }
    if (this.currentTab !== 1) {
      DiagnosticLogger.info('ui_lifecycle', 'discover_initial_load_skip_off_tab', {
        reason: reason,
        currentTab: this.currentTab,
        started: this.hasStartedInitialLoad,
        skipped: true
      })
      return
    }
    this.hasStartedInitialLoad = true
    DiagnosticLogger.info('ui_lifecycle', 'discover_initial_load_start', {
      reason: reason,
      currentTab: this.currentTab,
      started: this.hasStartedInitialLoad,
      skipped: false
    })
    this.loadLocalNodeSections()
    this.loadNodeNavigationSections()
    this.loadTopicSurface()
  }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0) {
        Column() {
          LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width('100%')
        .height('100%')
      } else if (this.vm.errorMessage && this.vm.nodeDataSource.totalCount() === 0) {
        DiscoverErrorState({
          message: this.vm.errorMessage,
          topPadding: this.layout.topAvoidHeight + this.TBH + this.BBH,
          bottomPadding: this.discoverBottomPadding(),
          retryAction: () => { this.vm.loadAllNodes({ forceRefresh: true, publishDefaultNodes: true }) }
        })
      } else {
        Column() {
          PullRefresh({
            scroller: this.scroller,
            indicatorTop: this.layout.topAvoidHeight + this.TBH + this.BBH,
            threshold: this.PULL_REFRESH_THRESHOLD,
            onRefresh: async () => { await this.refreshDiscover() },
            onScrollEnableChange: (enabled: boolean) => { this.scrollEnabled = enabled }
          }) {
            Scroll(this.scroller) {
              Column({ space: ThemeConstants.SPACE_MD }) {
                if (this.hasNodeSearchQuery()) {
                  this.NodeResultsSection()
                } else {
                  this.LocalNodeSections()
                  this.HotTopicsSection()
                  this.NodeNavigationSections()
                }
              }
                .padding({
                  left: this.GAP, right: this.GAP,
                  top: this.discoverTopPadding(),
                  bottom: this.discoverBottomPadding()
                })
                .width('100%')
            }
              .enableScrollInteraction(this.scrollEnabled)
              .onDidScroll((_scrollOffset: number, scrollState: ScrollState) => {
                if (this.onDidScroll) {
                  this.onDidScroll(this.scroller.currentOffset().yOffset, scrollState)
                }
              })
              .scrollBar(BarState.Off)
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder HotTopicsSection() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.TopicModeButton('hot', AppStrings.text($r('app.string.discover_hot'), 'Hot'))
        this.TopicModeButton('latest', AppStrings.text($r('app.string.discover_latest'), 'Latest'))
        this.TopicModeButton('recent', AppStrings.text($r('app.string.discover_recent'), 'Recent'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      DiscoverSectionTitle({ title: this.topicSectionTitle() })

      if (this.isHotLoading && this.topicSurfaceItems().length === 0) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE)
          .height(ThemeConstants.LOADING_SIZE)
          .margin({ top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
      } else if (this.hotError && this.topicSurfaceItems().length === 0) {
        Text(this.hotError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .padding(ThemeConstants.SPACE_MD)
          .width('100%')
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      } else {
        ForEach(this.topicSurfaceItems().slice(0, 10), (topic: V2exTopic) => {
          this.HotTopicRow(topic)
        }, (topic: V2exTopic) => `${this.topicMode}-${topic.id}`)
      }
    }
    .width('100%')
  }

  @Builder TopicModeButton(mode: DiscoverTopicMode, label: string) {
    DiscoverTopicModeButton({
      label: label,
      selected: this.topicMode === mode,
      action: () => { this.setTopicMode(mode) }
    })
  }

  @Builder HotTopicRow(topic: V2exTopic) {
    DiscoverHotTopicRow({
      topic: topic,
      openAction: () => {
        let p: TopicDetailParams = { topicId: topic.id }
        this.ns.pushPathByName('TopicDetail', p as Object)
      }
    })
  }

  @Builder NodeResultsSection() {
    if (this.vm.nodeDataSource.totalCount() === 0 && this.vm.hasNodeIndexSettled()) {
      DiscoverEmptyState()
    } else if (this.vm.nodeDataSource.totalCount() === 0) {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
        .margin({ top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
    } else {
      DiscoverSectionTitle({ title: AppStrings.text($r('app.string.common_nodes'), 'Nodes') })
      GridRow({ columns: { sm: 2, md: 4, lg: 6 }, gutter: { x: ThemeConstants.SPACE_SM, y: ThemeConstants.SPACE_SM } }) {
        LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
          GridCol({ span: { sm: 1, md: 2, lg: 2 } }) {
            DiscoverNodeCard({
              node: node,
              openAction: () => {
                let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title }
                this.ns.pushPathByName('NodeTopicList', p as Object)
              }
            })
          }
        }, (node: V2exNode) => node.id.toString())
      }
    }
  }

  @Builder NodeNavigationSections() {
    if (this.nodeNavigationSections.length > 0) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        DiscoverSectionTitle({ title: AppStrings.text($r('app.string.discover_node_navigation'), 'Node navigation') })
        ForEach(this.nodeNavigationSections, (section: V2exNodeNavigationSection) => {
          Column({ space: ThemeConstants.SPACE_SM }) {
            Text(this.navigationSectionTitle(section))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
            this.NodeChipWrap(this.navigationNodes(section), `navigation-${section.title}`)
          }
          .width('100%')
        }, (section: V2exNodeNavigationSection) => section.title)
      }
      .width('100%')
    }
  }

  @Builder LocalNodeSections() {
    if (this.savedNodes.length > 0 || this.recentNodes.length > 0) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        if (this.savedNodes.length > 0) {
          DiscoverSectionTitle({ title: AppStrings.text($r('app.string.discover_section_saved_nodes'), 'Followed nodes') })
          this.NodeChipWrap(this.savedNodes.slice(0, 12), 'saved')
        }
        if (this.recentNodes.length > 0) {
          DiscoverSectionTitle({ title: AppStrings.text($r('app.string.discover_section_recent_nodes'), 'Recently viewed nodes') })
          this.NodeChipWrap(this.recentNodes.slice(0, 12), 'recent')
        }
      }
      .width('100%')
    }
  }

  @Builder NodeChipWrap(nodes: SavedNode[], prefix: string) {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(ThemeConstants.SPACE_SM), cross: LengthMetrics.vp(ThemeConstants.SPACE_SM) } }) {
      ForEach(nodes, (node: SavedNode) => {
        this.NodeChip(node)
      }, (node: SavedNode) => `${prefix}-${node.name}`)
    }
    .width('100%')
  }

  @Builder NodeChip(node: SavedNode) {
    DiscoverNodeChip({
      node: node,
      openAction: () => {
        let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title || node.name }
        this.ns.pushPathByName('NodeTopicList', p as Object)
      }
    })
  }

  private discoverBottomPadding(): number {
    return this.layout.bottomAvoidHeight + this.FLOAT_H + ThemeConstants.SPACE_XL
  }

  private discoverTopPadding(): number {
    return this.layout.topAvoidHeight + this.TBH + this.BBH
  }

  private hasNodeSearchQuery(): boolean {
    return DiscoverPageCoordinator.hasNodeSearchQuery(this.kwState.keyword)
  }

  private topicSurfaceItems(): V2exTopic[] {
    return DiscoverPageCoordinator.topicItems(this.topicMode, this.topicBuckets())
  }

  private topicSectionTitle(): string {
    return DiscoverPageCoordinator.topicModeLabel(this.topicMode)
  }

  private setTopicMode(mode: DiscoverTopicMode): void {
    if (this.topicMode === mode) {
      return
    }
    this.topicMode = mode
    this.loadTopicSurface()
  }

  private async refreshDiscover(): Promise<void> {
    this.loadLocalNodeSections()
    this.loadNodeNavigationSections()
    await this.loadTopicSurface(true)
    // Re-throw so the shared PullRefresh shows a single "刷新失败" toast. loadTopicSurface() swallows the
    // fetch error into this.hotError (cleared at each load start; still shown inline when the list is
    // empty) and resolves normally. Initial load / tab switch call it un-awaited and keep swallowing, so
    // an empty first load shows the inline error and never toasts.
    if (this.hotError) {
      throw new Error(this.hotError)
    }
  }

  private navigationSectionTitle(section: V2exNodeNavigationSection): string {
    if (section.titleKey === 'discover_node_navigation_hottest') {
      return AppStrings.text($r('app.string.discover_node_navigation_hottest'), section.title || 'Hottest Nodes')
    }
    if (section.titleKey === 'discover_node_navigation_recently_created') {
      return AppStrings.text($r('app.string.discover_node_navigation_recently_created'), section.title || 'Recently Created')
    }
    return section.title
  }

  private navigationNodes(section: V2exNodeNavigationSection): SavedNode[] {
    return (section.nodes || []).map((node): SavedNode => {
      return { name: node.name, title: node.title || node.name, topics: 0, savedAt: 0 }
    })
  }

  private loadNodeNavigationSections(): void {
    this.api.getNodeNavigationSections()
      .then((sections: V2exNodeNavigationSection[]) => {
        this.nodeNavigationSections = sections
      })
      .catch((_error: Error) => {
        this.nodeNavigationSections = []
      })
  }

  private loadTopicSurface(forceRefresh: boolean = false): Promise<void> {
    if (!forceRefresh && !DiscoverPageCoordinator.shouldLoadTopicSurface(this.topicMode, this.topicBuckets(), this.isHotLoading)) {
      return Promise.resolve()
    }
    this.isHotLoading = true
    this.hotError = ''
    const requestedMode = this.topicMode
    const request = requestedMode === 'hot'
      ? this.api.getHotTopics()
      : requestedMode === 'recent'
        ? this.api.getRecentTopics()
        : this.api.getLatestTopics()
    return request
      .then((topics: V2exTopic[]) => {
        this.applyTopicBuckets(DiscoverPageCoordinator.withTopics(requestedMode, this.topicBuckets(), topics))
      })
      .catch((error: Error) => {
        this.hotError = translateApiError(error)
      })
      .finally(() => {
        this.isHotLoading = false
        if (this.topicMode !== requestedMode && this.topicSurfaceItems().length === 0) {
          this.loadTopicSurface()
        }
      })
  }

  private loadLocalNodeSections(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    Promise.all([
      CollectionSettings.loadSavedNodes(context),
      CollectionSettings.loadViewedTopics(context)
    ])
      .then((result) => {
        this.savedNodes = result[0]
        this.recentNodes = DiscoverPageCoordinator.recentNodesFromViewedTopics(result[1], this.savedNodes)
      })
      .catch((_error: Error) => {
        this.savedNodes = []
        this.recentNodes = []
      })
  }

  private topicBuckets(): DiscoverTopicBuckets {
    return {
      hot: this.hotTopics,
      latest: this.latestTopics,
      recent: this.recentTopics
    }
  }

  private applyTopicBuckets(buckets: DiscoverTopicBuckets): void {
    this.hotTopics = buckets.hot
    this.latestTopics = buckets.latest
    this.recentTopics = buckets.recent
  }
}
