import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  ApiService, FilterChip, PullRefresh, StorageKeys, V2exNode, V2exTopic, NodeTopicListParams, TopicDetailParams,
  ThemeConstants, CollectionSettings
} from 'shared'
import type { SavedNode, ViewedTopic } from 'shared'
import { common } from '@kit.AbilityKit'
import { LengthMetrics } from '@kit.ArkUI'

type DiscoverTopicMode = 'hot' | 'rank' | 'latest' | 'recent'

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
        this.ErrorView()
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
        this.TopicModeButton('hot', '热议')
        this.TopicModeButton('rank', '热榜')
        this.TopicModeButton('latest', '最新')
        this.TopicModeButton('recent', '最近')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.topicSectionTitle())
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')

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
    FilterChip({
      label,
      selected: this.topicMode === mode,
      action: () => { this.setTopicMode(mode) }
    })
  }

  @Builder HotTopicRow(topic: V2exTopic) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(topic.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: ThemeConstants.SPACE_XS }) {
          Text(topic.node.title)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('·')
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
          Text(topic.member.username)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${topic.replies}`)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 4, bottom: 4 })
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .onClick(() => {
      let p: TopicDetailParams = { topicId: topic.id }
      this.ns.pushPathByName('TopicDetail', p as Object)
    })
  }

  @Builder NodeResultsSection() {
    if (this.vm.nodeDataSource.totalCount() === 0) {
      this.EmptyView()
    } else {
      this.SectionTitle('节点')
      GridRow({ columns: { sm: 2, md: 4, lg: 6 }, gutter: { x: ThemeConstants.SPACE_SM, y: ThemeConstants.SPACE_SM } }) {
        LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
          GridCol({ span: { sm: 1, md: 2, lg: 2 } }) {
            Column() {
              Text(node.title)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${node.topics} 主题`)
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
                .margin({ top: ThemeConstants.SPACE_XS })
            }
            .alignItems(HorizontalAlign.Center)
            .padding(ThemeConstants.SPACE_MD)
            .width('100%')
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
            .onClick(() => {
              let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title }
              this.ns.pushPathByName('NodeTopicList', p as Object)
            })
          }
        }, (node: V2exNode) => node.id.toString())
      }
    }
  }

  @Builder SectionTitle(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_TITLE)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
  }

  @Builder LocalNodeSections() {
    if (this.savedNodes.length > 0 || this.recentNodes.length > 0) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        if (this.savedNodes.length > 0) {
          this.SectionTitle('关注节点')
          this.NodeChipWrap(this.savedNodes.slice(0, 12), 'saved')
        }
        if (this.recentNodes.length > 0) {
          this.SectionTitle('最近浏览节点')
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
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(node.title || node.name)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (node.topics > 0) {
        Text(`${node.topics}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .alignItems(VerticalAlign.Center)
    .height(34)
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .onClick(() => {
      let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title || node.name }
      this.ns.pushPathByName('NodeTopicList', p as Object)
    })
  }

  @Builder EmptyView() {
    Column() {
      Text('没有匹配的节点')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
  }

  @Builder ErrorView() {
    Column() {
      Text(this.vm.errorMessage)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.vm.loadAllNodes() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: this.topH + this.TBH + this.BBH, bottom: this.discoverBottomPadding() })
  }

  private discoverBottomPadding(): number {
    return this.bottomH + this.FLOAT_H + ThemeConstants.SPACE_XL
  }

  private hasNodeSearchQuery(): boolean {
    return (this.nodeKeyword || '').trim().length > 0
  }

  private topicSurfaceItems(): V2exTopic[] {
    if (this.topicMode === 'hot') {
      return this.hotTopics
    }
    if (this.topicMode === 'rank') {
      return this.rankTopics
    }
    if (this.topicMode === 'recent') {
      return this.recentTopics
    }
    return this.latestTopics
  }

  private topicSectionTitle(): string {
    if (this.topicMode === 'hot') {
      return '今日热议'
    }
    if (this.topicMode === 'rank') {
      return '全站热榜'
    }
    if (this.topicMode === 'recent') {
      return '最近更新'
    }
    return '最新主题'
  }

  private setTopicMode(mode: DiscoverTopicMode): void {
    if (this.topicMode === mode) {
      return
    }
    this.topicMode = mode
    this.loadTopicSurface()
  }

  private reloadTopicSurface(): void {
    if (this.topicMode === 'hot') {
      this.hotTopics = []
    } else if (this.topicMode === 'rank') {
      this.rankTopics = []
    } else if (this.topicMode === 'recent') {
      this.recentTopics = []
    } else {
      this.latestTopics = []
    }
    this.loadTopicSurface()
  }

  private async refreshDiscover(): Promise<void> {
    await this.vm.loadAllNodes()
    this.loadLocalNodeSections()
    this.reloadTopicSurface()
  }

  private loadTopicSurface(): void {
    if (this.isHotLoading) {
      return
    }
    if (this.topicSurfaceItems().length > 0) {
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
        if (requestedMode === 'hot') {
          this.hotTopics = topics || []
        } else if (requestedMode === 'rank') {
          this.rankTopics = topics || []
        } else if (requestedMode === 'recent') {
          this.recentTopics = topics || []
        } else {
          this.latestTopics = topics || []
        }
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
        this.recentNodes = this.recentNodesFromViewedTopics(result[1], this.savedNodes)
      })
      .catch((_error: Error) => {
        this.savedNodes = []
        this.recentNodes = []
      })
  }

  private recentNodesFromViewedTopics(viewedTopics: ViewedTopic[], savedNodes: SavedNode[]): SavedNode[] {
    const saved = new Set(savedNodes.map((node: SavedNode) => node.name))
    const seen: Set<string> = new Set()
    const nodes: SavedNode[] = []
    for (const topic of viewedTopics) {
      const name = (topic.nodeName || '').trim()
      if (!name || seen.has(name) || saved.has(name)) {
        continue
      }
      nodes.push({
        name: name,
        title: topic.nodeTitle || name,
        topics: 0,
        savedAt: topic.viewedAt || 0
      })
      seen.add(name)
      if (nodes.length >= 12) {
        break
      }
    }
    return nodes
  }
}
