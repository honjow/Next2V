import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  ApiService, AppStrings, PullRefresh, StorageKeys, V2exNode, V2exTopic, NodeTopicListParams, TopicDetailParams,
  ThemeConstants, CollectionSettings
} from 'shared'
import type { SavedNode } from 'shared'
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
  @State private rankTopics: V2exTopic[] = []
  @State private latestTopics: V2exTopic[] = []
  @State private recentTopics: V2exTopic[] = []
  @State private hotError: string = ''
  @State private isHotLoading: boolean = false
  @State private scrollEnabled: boolean = true
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
  private scroller: Scroller = new Scroller()
  private api: ApiService = new ApiService()

  private onKeywordChanged(): void {
    this.vm.setNodeFilter(this.nodeKeyword)
  }

  aboutToAppear(): void {
    AppStorage.setOrCreate(StorageKeys.DISCOVER_NODE_KEYWORD, this.vm.keyword)
    this.vm.loadAllNodes()
    this.loadLocalNodeSections()
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
          retryAction: () => { this.vm.loadAllNodes() }
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
                  this.NodeResultsSection()
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
        this.TopicModeButton('rank', '热榜')
        this.TopicModeButton('latest', '最新')
        this.TopicModeButton('recent', '最近')
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
        ForEach(this.topicSurfaceItems().slice(0, 6), (topic: V2exTopic) => {
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
    if (this.vm.nodeDataSource.totalCount() === 0) {
      DiscoverEmptyState()
    } else {
      DiscoverSectionTitle({ title: '节点' })
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

  @Builder LocalNodeSections() {
    if (this.savedNodes.length > 0 || this.recentNodes.length > 0) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        if (this.savedNodes.length > 0) {
          DiscoverSectionTitle({ title: '关注节点' })
          this.NodeChipWrap(this.savedNodes.slice(0, 12), 'saved')
        }
        if (this.recentNodes.length > 0) {
          DiscoverSectionTitle({ title: '最近浏览节点' })
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

  private reloadTopicSurface(): void {
    this.applyTopicBuckets(DiscoverPageCoordinator.withoutTopics(this.topicMode, this.topicBuckets()))
    this.loadTopicSurface()
  }

  private async refreshDiscover(): Promise<void> {
    await this.vm.loadAllNodes()
    this.loadLocalNodeSections()
    this.reloadTopicSurface()
  }

  private loadTopicSurface(): void {
    if (!DiscoverPageCoordinator.shouldLoadTopicSurface(this.topicMode, this.topicBuckets(), this.isHotLoading)) {
      return
    }
    this.isHotLoading = true
    this.hotError = ''
    const requestedMode = this.topicMode
    const request = requestedMode === 'hot'
      ? this.api.getHotTopics()
      : requestedMode === 'rank'
        ? this.api.getHotTabTopics()
        : requestedMode === 'recent'
          ? this.api.getRecentTopics()
          : this.api.getLatestTopics()
    request
      .then((topics: V2exTopic[]) => {
        this.applyTopicBuckets(DiscoverPageCoordinator.withTopics(requestedMode, this.topicBuckets(), topics))
      })
      .catch((error: Error) => {
        this.hotError = error.message || '主题加载失败'
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
      rank: this.rankTopics,
      latest: this.latestTopics,
      recent: this.recentTopics
    }
  }

  private applyTopicBuckets(buckets: DiscoverTopicBuckets): void {
    this.hotTopics = buckets.hot
    this.rankTopics = buckets.rank
    this.latestTopics = buckets.latest
    this.recentTopics = buckets.recent
  }
}
