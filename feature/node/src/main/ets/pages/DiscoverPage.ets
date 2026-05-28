import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  ApiService, AppStrings, DiagnosticLogger, PullRefresh, StorageKeys, V2exNode, V2exTopic, NodeTopicListParams, TopicDetailParams,
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

@Component
export struct DiscoverPage {
  @Consume('ns') ns: NavPathStack
  @State vm: NodeViewModel = new NodeViewModel()
  @State private topicMode: DiscoverTopicMode = 'hot'
  @State private hotTopics: V2exTopic[] = []
  @State private latestTopics: V2exTopic[] = []
  @State private recentTopics: V2exTopic[] = []
  @State private hotError: string = ''
  @State private isHotLoading: boolean = false
  @State private scrollEnabled: boolean = true
  @State private nodeNavigationSections: V2exNodeNavigationSection[] = []
  @StorageLink(StorageKeys.DISCOVER_NODE_KEYWORD) @Watch('onKeywordChanged') nodeKeyword: string = ''
  @State private savedNodes: SavedNode[] = []
  @State private recentNodes: SavedNode[] = []
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly BBH: number = 48
  private readonly GAP: number = ThemeConstants.SPACE_MD
  private readonly PULL_REFRESH_THRESHOLD: number = 84
  scroller: Scroller = new Scroller()
  onDidScroll?: (offset: number, state: ScrollState) => void
  private api: ApiService = new ApiService()
  private hasStartedInitialLoad: boolean = false
  @Prop @Watch('onCurrentTabChanged') currentTab: number = 0

  private onKeywordChanged(): void {
    this.vm.setNodeFilter(this.nodeKeyword)
    if (this.hasNodeSearchQuery() && this.vm.nodeIndexPhase !== 'loading' && this.vm.nodeIndexPhase !== 'loaded') {
      this.vm.loadAllNodes({ publishDefaultNodes: true })
    }
  }

  private onCurrentTabChanged(_propName: string): void {
    this.requestInitialLoad('currentTabChanged')
  }

  aboutToAppear(): void {
    AppStorage.setOrCreate(StorageKeys.DISCOVER_NODE_KEYWORD, this.vm.keyword)
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
          topPadding: this.topH + this.TBH + this.BBH,
          bottomPadding: this.discoverBottomPadding(),
          retryAction: () => { this.vm.loadAllNodes({ forceRefresh: true, publishDefaultNodes: true }) }
        })
      } else {
        Column() {
          PullRefresh({
            scroller: this.scroller,
            indicatorTop: this.topH + this.TBH + this.BBH,
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
        DiscoverSectionTitle({ title: '节点导航' })
        ForEach(this.nodeNavigationSections, (section: V2exNodeNavigationSection) => {
          Column({ space: ThemeConstants.SPACE_SM }) {
            Text(section.title)
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
    return this.bottomH + this.FLOAT_H + ThemeConstants.SPACE_XL
  }

  private discoverTopPadding(): number {
    return this.topH + this.TBH + this.BBH
  }

  private hasNodeSearchQuery(): boolean {
    return DiscoverPageCoordinator.hasNodeSearchQuery(this.nodeKeyword)
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
