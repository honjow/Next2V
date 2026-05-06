import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  CacheSettings,
  type CacheKeyIndex,
  CollectionSettings,
  ApiService,
  NodeSearchUtils,
  type NodeTopicListParams,
  type SavedNode,
  type SavedTopic,
  SearchSettings,
  type SearchSourceMode,
  SectionHeader as SharedSectionHeader,
  ListDivider as SharedListDivider,
  EmptyState,
  StorageKeys,
  Sov2exService,
  type Sov2exHit,
  type Sov2exOrderMode,
  type Sov2exSortMode,
  ThemeConstants,
  type TopicDetailParams,
  type V2exNode,
  type ViewedTopic
} from 'shared'

interface SearchTopicItem {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  source: string
  updatedAt: number
}

interface SearchNodeItem {
  name: string
  title: string
  topics: number
  source: string
  updatedAt: number
  score: number
}

interface RemoteTopicItem {
  id: number
  title: string
  username: string
  content: string
  created: string
  replies: number
  nodeId: number
}

type SearchResultFilter = 'all' | 'topics' | 'nodes' | 'users'

@Component
export struct SearchPage {
  @Consume('ns') stack: NavPathStack

  @State private keyword: string = ''
  @State private errorMessage: string = ''

  @State private savedTopics: SavedTopic[] = []
  @State private viewedTopics: ViewedTopic[] = []
  @State private savedNodes: SavedNode[] = []
  @State private allNodes: V2exNode[] = []
  @State private isNodeIndexLoading: boolean = false

  @State private cacheTopicLists: SearchTopicItem[] = []
  @State private cacheTopicDetails: SearchTopicItem[] = []
  @State private isCacheLoading: boolean = false

  @State private history: string[] = []
  @State private sourceMode: SearchSourceMode = 'localWithNodes'
  @State private resultFilter: SearchResultFilter = 'all'

  @State private topicResults: SearchTopicItem[] = []
  @State private nodeResults: SearchNodeItem[] = []
  @State private remoteResults: RemoteTopicItem[] = []
  @State private remoteTotal: number = 0
  @State private remoteFrom: number = 0
  @State private remoteLoading: boolean = false
  @State private remoteError: string = ''
  @State private remoteSort: Sov2exSortMode = 'created'
  @State private remoteOrder: Sov2exOrderMode = '0'
  @State private remoteUsername: string = ''
  @State private remoteNode: string = ''
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0

  private api: ApiService = new ApiService()
  private sov2ex: Sov2exService = new Sov2exService()

  aboutToAppear(): void {
    this.keyword = ''
    this.errorMessage = ''
    this.loadLocalCollections()
    this.loadCacheCollections()
    this.loadSourceMode()
    this.loadHistory()
  }

  aboutToDisappear(): void {
    this.recordHistory()
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      this.SearchPanel()
      this.HistorySection()

      if (this.sourceMode !== 'externalWeb' && this.sourceMode !== 'remote' && this.keyword.trim().length > 0) {
        this.ResultFilterControls()
      }

      if (this.sourceMode === 'externalWeb' && this.keyword.trim().length > 0) {
        this.ExternalWebSearchPanel()
      } else if (this.sourceMode === 'remote' && this.keyword.trim().length > 0) {
        this.RemoteSearchResultList()
      } else if (this.keyword.trim().length > 0) {
        this.LocalResultList()
      }

    }
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD,
      bottom: this.bottomH + ThemeConstants.SPACE_LG
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder SearchPanel() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      TextInput({ placeholder: '搜索主题、节点、用户', text: this.keyword })
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .height(44)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .onChange((value: string) => {
          this.keyword = value
          this.applyFilter()
          this.resetRemoteResults()
        })

      if (this.isCacheLoading || this.isNodeIndexLoading) {
        Text(this.loadingSummary())
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }

      this.SourceModeControls()
      if (this.sourceMode === 'remote') {
        this.RemoteSearchControls()
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder HistorySection() {
    if (!this.keyword.trim() && this.history.length > 0) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Row() {
          Text('搜索历史')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
          Blank()
          Text('清空')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .onClick(() => { this.clearHistory() })
        }
        .width('100%')

        Scroll() {
          Row({ space: ThemeConstants.SPACE_XS }) {
            ForEach(this.history, (q: string) => {
              Text(q)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor($r('sys.color.font_primary'))
                .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 6, bottom: 6 })
                .borderRadius(ThemeConstants.RADIUS_ROUND)
                .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                .onClick(() => { this.applyHistory(q) })
            }, (q: string) => q)
          }
          .width('100%')
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
      .width('100%')
    }
  }

  @Builder LocalResultList() {
    List({ space: ThemeConstants.SPACE_SM }) {
      if (this.showTopicResults()) {
        ListItem() {
          Column() {
            SharedSectionHeader({ title: `${this.topicSectionTitle()} ${this.topicResults.length}` })
            if (this.topicResults.length === 0) {
              EmptyState({
                message: this.keyword.trim() ? this.emptyTopicHint() : '输入关键词开始搜索',
                stateHeight: 96
              })
                .borderRadius(ThemeConstants.RADIUS_MD)
                .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
                .margin({ top: ThemeConstants.SPACE_XS })
            }
          }
          .width('100%')
        }

        ForEach(this.topicResults.slice(0, 80), (item: SearchTopicItem) => {
          ListItem() { this.TopicRow(item) }
            .onClick(() => {
              let p: TopicDetailParams = { topicId: item.id }
              this.stack.pushPathByName('TopicDetail', p as Object)
            })
        }, (item: SearchTopicItem) => `t:${item.id}`)
      }

      if (this.showTopicResults() && this.showNodeResults()) {
        ListItem() {
          SharedListDivider({ inset: 0 })
        }
      }

      if (this.showNodeResults()) {
        ListItem() {
          Column() {
            SharedSectionHeader({ title: `节点结果 ${this.nodeResults.length}` })
            if (this.nodeResults.length === 0) {
              EmptyState({
                message: this.keyword.trim() ? '没有匹配的节点' : this.emptyNodeHint(),
                stateHeight: 96
              })
                .borderRadius(ThemeConstants.RADIUS_MD)
                .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
                .margin({ top: ThemeConstants.SPACE_XS })
            }
          }
          .width('100%')
        }

        ForEach(this.nodeResults.slice(0, 80), (item: SearchNodeItem) => {
          ListItem() { this.NodeRow(item) }
            .onClick(() => {
              let p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
              this.stack.pushPathByName('NodeTopicList', p as Object)
            })
        }, (item: SearchNodeItem) => `n:${item.name}`)
      }
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder ExternalWebSearchPanel() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.keyword.trim() ? '使用浏览器搜索 V2EX 主题' : '输入关键词开始搜索')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
      Button('打开网页搜索')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .height(44)
        .width('100%')
        .borderRadius(ThemeConstants.RADIUS_MD)
        .enabled(this.keyword.trim().length > 0)
        .onClick(() => { this.openExternalTopicSearch() })
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .layoutWeight(1)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder RemoteSearchResultList() {
    List({ space: ThemeConstants.SPACE_SM }) {
      ListItem() {
        Column() {
          SharedSectionHeader({ title: `SOV2EX ${this.remoteTotal}` })
          if (this.remoteError) {
            Text(this.remoteError)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(Color.Red)
              .padding(ThemeConstants.SPACE_MD)
              .width('100%')
              .borderRadius(ThemeConstants.RADIUS_MD)
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
          } else if (!this.remoteLoading && this.remoteResults.length === 0) {
            EmptyState({ message: '点击搜索获取远程结果', stateHeight: 96 })
              .borderRadius(ThemeConstants.RADIUS_MD)
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
              .margin({ top: ThemeConstants.SPACE_XS })
          }
        }
        .width('100%')
      }

      ForEach(this.remoteResults, (item: RemoteTopicItem) => {
        ListItem() { this.RemoteTopicRow(item) }
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.stack.pushPathByName('TopicDetail', p as Object)
          })
      }, (item: RemoteTopicItem) => `r:${item.id}`)

      if (this.remoteLoading) {
        ListItem() { EmptyState({ message: '搜索中', stateHeight: 88 }) }
      } else if (this.remoteResults.length < this.remoteTotal) {
        ListItem() {
          Button('加载更多')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .height(44)
            .width('100%')
            .borderRadius(ThemeConstants.RADIUS_MD)
            .onClick(() => { this.executeRemoteSearch(false) })
        }
      }
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder RemoteTopicRow(item: RemoteTopicItem) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(item.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.content) {
        Text(item.content)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(`@${item.username}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
        Text(`${item.replies} 回复`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
        Text(item.created)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder TopicRow(item: SearchTopicItem) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(item.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(`${item.nodeTitle} / ${item.nodeName} · @${item.username}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(item.source)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder NodeRow(item: SearchNodeItem) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.name)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.source)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
        Text(`${item.topics} 主题`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder SourceModeControls() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        this.SourceModeButton('local', '本地')
        this.SourceModeButton('localWithNodes', '本地+节点库')
        this.SourceModeButton('remote', 'SOV2EX')
        this.SourceModeButton('externalWeb', '网页搜索')
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder SourceModeButton(mode: SearchSourceMode, label: string) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(this.sourceMode === mode ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_primary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(this.sourceMode === mode ? '#EAF2FF' : $r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => { this.updateSourceMode(mode) })
  }

  @Builder RemoteSearchControls() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.RemoteOptionButton('时间', this.remoteSort === 'created', () => {
          this.remoteSort = 'created'
          this.executeRemoteSearch(true)
        })
        this.RemoteOptionButton('相关', this.remoteSort === 'sumup', () => {
          this.remoteSort = 'sumup'
          this.executeRemoteSearch(true)
        })
        this.RemoteOptionButton(this.remoteOrder === '0' ? '倒序' : '正序', true, () => {
          this.remoteOrder = this.remoteOrder === '0' ? '1' : '0'
          this.executeRemoteSearch(true)
        })
        Button(this.remoteLoading ? '搜索中' : '搜索')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(34)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .enabled(!this.remoteLoading && this.keyword.trim().length > 0)
          .layoutWeight(1)
          .onClick(() => { this.executeRemoteSearch(true) })
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_XS }) {
        TextInput({ placeholder: '作者', text: this.remoteUsername })
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(34)
          .layoutWeight(1)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onChange((value: string) => {
            this.remoteUsername = value
            this.resetRemoteResults()
          })
        TextInput({ placeholder: '节点', text: this.remoteNode })
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(34)
          .layoutWeight(1)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onChange((value: string) => {
            this.remoteNode = value
            this.resetRemoteResults()
          })
        if (this.hasRemoteFilters()) {
          this.RemoteOptionButton('清除', false, () => { this.clearRemoteFilters() })
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder RemoteOptionButton(label: string, selected: boolean, action: () => void) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(selected ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_primary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(selected ? '#EAF2FF' : $r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => { action() })
  }

  @Builder ResultFilterControls() {
    Row() {
      Text('结果')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
      Blank()
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ResultFilterButton('all', '全部')
        this.ResultFilterButton('topics', '主题')
        this.ResultFilterButton('nodes', '节点')
        this.ResultFilterButton('users', '用户')
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
  }

  @Builder ResultFilterButton(filter: SearchResultFilter, label: string) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(this.resultFilter === filter ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_primary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(this.resultFilter === filter ? '#EAF2FF' : $r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => { this.updateResultFilter(filter) })
  }

  private loadLocalCollections(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    Promise.all([
      CollectionSettings.loadSavedTopics(context),
      CollectionSettings.loadViewedTopics(context),
      CollectionSettings.loadSavedNodes(context)
    ])
      .then((results: Object[]) => {
        this.savedTopics = (results[0] as SavedTopic[]) || []
        this.viewedTopics = (results[1] as ViewedTopic[]) || []
        this.savedNodes = (results[2] as SavedNode[]) || []
        this.applyFilter()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '读取本地数据失败'
      })
  }

  private loadCacheCollections(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.isCacheLoading = true
    CacheSettings.loadKeyIndex(context)
      .then(async (index: CacheKeyIndex) => {
        const listTopics = new Map<number, SearchTopicItem>()
        const detailTopics = new Map<number, SearchTopicItem>()

        for (const key of index.topicLists) {
          const topics = await CacheSettings.loadTopicList(context, key)
          for (const topic of topics) {
            const item: SearchTopicItem = {
              id: topic.id,
              title: topic.title,
              nodeName: topic.node.name,
              nodeTitle: topic.node.title,
              username: topic.member.username,
              source: '缓存(列表)',
              updatedAt: index.updatedAt
            }
            listTopics.set(item.id, item)
          }
        }

        for (const topicId of index.topicDetails) {
          const detail = await CacheSettings.loadTopicDetail(context, topicId)
          if (!detail || !detail.topic) {
            continue
          }
          const topic = detail.topic
          const item: SearchTopicItem = {
            id: topic.id,
            title: topic.title,
            nodeName: topic.node.name,
            nodeTitle: topic.node.title,
            username: topic.member.username,
            source: '缓存(详情)',
            updatedAt: detail.cachedAt || index.updatedAt
          }
          detailTopics.set(item.id, item)
        }

        this.cacheTopicLists = Array.from(listTopics.values())
        this.cacheTopicDetails = Array.from(detailTopics.values())
        this.applyFilter()
      })
      .catch((_error: Error) => {
        this.cacheTopicLists = []
        this.cacheTopicDetails = []
      })
      .finally(() => {
        this.isCacheLoading = false
      })
  }

  private loadNodeIndex(): void {
    if (!this.usesNodeIndex()) {
      return
    }
    if (this.allNodes.length > 0) {
      this.applyFilter()
      return
    }
    this.isNodeIndexLoading = true
    this.api.getAllNodes()
      .then((nodes: V2exNode[]) => {
        this.allNodes = NodeSearchUtils.sortByPopularity(nodes)
        this.applyFilter()
      })
      .catch((_error: Error) => {
        this.allNodes = []
      })
      .finally(() => {
        this.isNodeIndexLoading = false
      })
  }

  private loadSourceMode(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.loadSourceMode(context)
      .then((mode: SearchSourceMode) => {
        this.sourceMode = mode
        if (this.usesNodeIndex()) {
          this.loadNodeIndex()
        } else {
          this.applyFilter()
        }
      })
      .catch((_error: Error) => {
        this.sourceMode = 'localWithNodes'
        this.loadNodeIndex()
      })
  }

  private loadHistory(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.loadHistory(context)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => {
        this.history = []
      })
  }

  private recordHistory(): void {
    const q = this.keyword.trim()
    if (!q) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.recordQuery(context, q)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => { })
  }

  private clearHistory(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.clearHistory(context)
      .then(() => {
        this.history = []
      })
      .catch((_error: Error) => { })
  }

  private applyHistory(q: string): void {
    const clean = (q ?? '').trim()
    if (!clean) {
      return
    }
    this.keyword = clean
    this.applyFilter()
    this.resetRemoteResults()
    if (this.sourceMode === 'remote') {
      this.executeRemoteSearch(true)
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.recordQuery(context, clean)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => { })
  }

  private applyFilter(): void {
    const q = this.keyword.trim().toLowerCase()
    if (!q) {
      this.topicResults = []
      this.nodeResults = []
      return
    }
    if (this.sourceMode === 'externalWeb') {
      this.topicResults = []
      this.nodeResults = []
      return
    }

    const includeTopics = this.showTopicResults()
    const includeNodes = this.showNodeResults()
    const bag = new Map<number, SearchTopicItem>()

    if (includeTopics) {
      for (const item of this.savedTopics) {
        const t: SearchTopicItem = {
          id: item.id,
          title: item.title,
          nodeName: item.nodeName,
          nodeTitle: item.nodeTitle,
          username: item.username,
          source: '收藏',
          updatedAt: item.savedAt || 0
        }
        if (SearchPage.topicMatches(t, q, this.resultFilter)) {
          bag.set(t.id, t)
        }
      }

      for (const item of this.viewedTopics) {
        const existing = bag.get(item.id)
        const t: SearchTopicItem = existing ? existing : {
          id: item.id,
          title: item.title,
          nodeName: item.nodeName,
          nodeTitle: item.nodeTitle,
          username: item.username,
          source: '最近',
          updatedAt: item.viewedAt || 0
        }
        if (!SearchPage.topicMatches(t, q, this.resultFilter)) {
          continue
        }
        if (!existing) {
          bag.set(t.id, t)
        } else {
          existing.source = SearchPage.mergeSource(existing.source, '最近')
          existing.updatedAt = Math.max(existing.updatedAt, item.viewedAt || 0)
        }
      }

      for (const item of this.cacheTopicDetails) {
        if (!SearchPage.topicMatches(item, q, this.resultFilter)) {
          continue
        }
        const existing = bag.get(item.id)
        if (!existing) {
          bag.set(item.id, item)
        } else {
          existing.source = SearchPage.mergeSource(existing.source, item.source)
          existing.updatedAt = Math.max(existing.updatedAt, item.updatedAt)
        }
      }

      for (const item of this.cacheTopicLists) {
        if (!SearchPage.topicMatches(item, q, this.resultFilter)) {
          continue
        }
        const existing = bag.get(item.id)
        if (!existing) {
          bag.set(item.id, item)
        } else {
          existing.source = SearchPage.mergeSource(existing.source, item.source)
          existing.updatedAt = Math.max(existing.updatedAt, item.updatedAt)
        }
      }
    }

    this.topicResults = Array.from(bag.values())
      .sort((a: SearchTopicItem, b: SearchTopicItem) => b.updatedAt - a.updatedAt)

    const nodeBag = new Map<string, SearchNodeItem>()

    if (includeNodes) {
      for (const item of this.savedNodes) {
        const node = SearchPage.savedNodeToV2exNode(item)
        const score = NodeSearchUtils.scoreNode(node, q)
        if (score <= 0) {
          continue
        }
        const n: SearchNodeItem = {
          name: item.name,
          title: item.title,
          topics: item.topics,
          source: '关注',
          updatedAt: item.savedAt || 0,
          score: score + 1200
        }
        nodeBag.set(n.name, n)
      }

      if (this.usesNodeIndex()) {
        for (const match of NodeSearchUtils.search(this.allNodes, q).slice(0, 120)) {
          const node = match.node
          const existing = nodeBag.get(node.name)
          if (!existing) {
            nodeBag.set(node.name, {
              name: node.name,
              title: node.title,
              topics: node.topics,
              source: '节点库',
              updatedAt: 0,
              score: match.score
            })
          } else {
            existing.title = existing.title || node.title
            existing.topics = Math.max(existing.topics, node.topics)
            existing.source = SearchPage.mergeSource(existing.source, '节点库')
            existing.score = Math.max(existing.score, match.score + 1200)
          }
        }
      }
    }

    this.nodeResults = Array.from(nodeBag.values())
      .sort((a: SearchNodeItem, b: SearchNodeItem) => {
        if (b.score !== a.score) {
          return b.score - a.score
        }
        if (b.updatedAt !== a.updatedAt) {
          return b.updatedAt - a.updatedAt
        }
        return b.topics - a.topics
      })
  }

  private static topicMatches(item: SearchTopicItem, q: string, filter: SearchResultFilter): boolean {
    if (filter === 'users') {
      return item.username.toLowerCase().includes(q)
    }
    if (item.id.toString().includes(q)) {
      return true
    }
    if (item.title.toLowerCase().includes(q)) {
      return true
    }
    if (item.nodeName.toLowerCase().includes(q)) {
      return true
    }
    if (item.nodeTitle.toLowerCase().includes(q)) {
      return true
    }
    return item.username.toLowerCase().includes(q)
  }

  private static mergeSource(existing: string, incoming: string): string {
    const parts = existing.split(' · ').map(s => s.trim()).filter(s => s.length > 0)
    if (parts.indexOf(incoming) >= 0) {
      return existing
    }
    parts.push(incoming)
    return parts.join(' · ')
  }

  private updateSourceMode(mode: SearchSourceMode): void {
    if (this.sourceMode === mode) {
      return
    }
    this.sourceMode = mode
    this.resetRemoteResults()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.saveSourceMode(context, mode)
      .catch((error: Error) => {
        this.errorMessage = error.message || '保存搜索来源失败'
      })
    if (this.usesNodeIndex()) {
      this.loadNodeIndex()
    } else if (mode === 'remote' && this.keyword.trim().length > 0) {
      this.executeRemoteSearch(true)
    } else {
      this.applyFilter()
    }
  }

  private updateResultFilter(filter: SearchResultFilter): void {
    if (this.resultFilter === filter) {
      return
    }
    this.resultFilter = filter
    this.applyFilter()
  }

  private showTopicResults(): boolean {
    return this.resultFilter === 'all' || this.resultFilter === 'topics' || this.resultFilter === 'users'
  }

  private showNodeResults(): boolean {
    return this.resultFilter === 'all' || this.resultFilter === 'nodes'
  }

  private topicSectionTitle(): string {
    return this.resultFilter === 'users' ? '用户相关主题' : '主题结果'
  }

  private emptyTopicHint(): string {
    return this.resultFilter === 'users' ? '没有匹配该用户的本地主题' : '没有匹配的主题'
  }

  private usesNodeIndex(): boolean {
    return this.sourceMode === 'localWithNodes'
  }

  private sourceModeSummary(): string {
    if (this.sourceMode === 'remote') {
      return '使用 SOV2EX 站内搜索'
    }
    if (this.sourceMode === 'externalWeb') {
      return '官方 API 暂无主题搜索，使用系统浏览器搜索 V2EX 主题'
    }
    if (this.usesNodeIndex()) {
      return '在收藏 / 最近浏览 / 关注节点 / 离线缓存 / 节点库中搜索'
    }
    return '在收藏 / 最近浏览 / 关注节点 / 离线缓存中搜索'
  }

  private loadingSummary(): string {
    if (this.isCacheLoading && this.isNodeIndexLoading) {
      return '索引加载中'
    }
    if (this.isCacheLoading) {
      return '缓存加载中'
    }
    return '节点加载中'
  }

  private emptyNodeHint(): string {
    if (this.usesNodeIndex()) {
      return '节点库和你关注的节点会出现在这里'
    }
    return '你关注的节点会出现在这里'
  }

  private openExternalTopicSearch(): void {
    const q = this.keyword.trim()
    if (!q) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.recordQuery(context, q)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => { })
    const url = SearchPage.buildExternalTopicSearchUrl(q)
    const want: Want = { action: 'ohos.want.action.viewData', uri: url }
    context.startAbility(want)
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => { })
      })
  }

  private static buildExternalTopicSearchUrl(query: string): string {
    return `https://www.bing.com/search?q=${encodeURIComponent(`site:v2ex.com/t ${query}`)}`
  }

  private resetRemoteResults(): void {
    this.remoteResults = []
    this.remoteTotal = 0
    this.remoteFrom = 0
    this.remoteError = ''
  }

  private executeRemoteSearch(reset: boolean): void {
    const q = this.keyword.trim()
    if (!q || this.remoteLoading) {
      return
    }
    if (reset) {
      this.remoteResults = []
      this.remoteTotal = 0
      this.remoteFrom = 0
      this.remoteError = ''
    }
    const from = reset ? 0 : this.remoteFrom
    this.remoteLoading = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.recordQuery(context, q)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => { })
    this.sov2ex.search({
      q: q,
      from: from,
      size: 20,
      sort: this.remoteSort,
      order: this.remoteOrder,
      username: this.remoteUsername.trim(),
      node: this.remoteNode.trim()
    })
      .then((response) => {
        const hits = response.hits || []
        const next = hits.map((hit: Sov2exHit) => SearchPage.remoteHitToItem(hit))
          .filter((item: RemoteTopicItem) => item.id > 0)
        this.remoteResults = reset ? next : this.remoteResults.concat(next)
        this.remoteTotal = response.total || this.remoteResults.length
        this.remoteFrom = this.remoteResults.length
      })
      .catch((error: Error) => {
        this.remoteError = error.message || '远程搜索失败'
      })
      .finally(() => {
        this.remoteLoading = false
      })
  }

  private static remoteHitToItem(hit: Sov2exHit): RemoteTopicItem {
    const source = hit._source || {}
    const rawId = source.id || Number.parseInt(hit._id || '0')
    return {
      id: rawId || 0,
      title: SearchPage.cleanHighlightText(source.title || ''),
      username: source.member || '',
      content: SearchPage.cleanHighlightText(SearchPage.firstHighlight(hit) || source.content || ''),
      created: SearchPage.cleanCreated(source.created || ''),
      replies: source.replies || 0,
      nodeId: source.node || 0
    }
  }

  private static firstHighlight(hit: Sov2exHit): string {
    const highlight = hit.highlight
    if (!highlight) {
      return ''
    }
    const reply = highlight.replyListContent
    if (reply && reply.length > 0) {
      return reply[0]
    }
    if (highlight.content && highlight.content.length > 0) {
      return highlight.content[0]
    }
    if (highlight.title && highlight.title.length > 0) {
      return highlight.title[0]
    }
    return ''
  }

  private static cleanHighlightText(text: string): string {
    return (text ?? '')
      .replace(/<em>/g, '')
      .replace(/<\/em>/g, '')
      .replace(/\s+/g, ' ')
      .trim()
  }

  private static cleanCreated(created: string): string {
    return (created ?? '').replace('T', ' ').slice(0, 16)
  }

  private hasRemoteFilters(): boolean {
    return this.remoteUsername.trim().length > 0 || this.remoteNode.trim().length > 0
  }

  private clearRemoteFilters(): void {
    this.remoteUsername = ''
    this.remoteNode = ''
    this.resetRemoteResults()
    this.executeRemoteSearch(true)
  }

  private static savedNodeToV2exNode(item: SavedNode): V2exNode {
    return {
      id: 0,
      name: item.name,
      title: item.title,
      title_alternative: '',
      url: '',
      topics: item.topics,
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
  }
}
