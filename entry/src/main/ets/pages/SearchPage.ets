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
  PullRefresh,
  StorageKeys,
  Sov2exService,
  AppActionButton,
  AppModalScaffold,
  type Sov2exOrderMode,
  type Sov2exSortMode,
  ThemeConstants,
  type TopicDetailParams,
  type V2exNode,
  type ViewedTopic,
  defaultSheetOptions,
} from 'shared'
import { SearchLocalResultBuilder } from '../model/SearchLocalResultBuilder'
import {
  SearchPageStateCoordinator,
} from '../model/SearchPageStateCoordinator'
import {
  ExternalWebSearchCard,
  LocalSearchFilterSheetContent,
  type RemoteDateRange,
  type RemoteTopicItem,
  RemoteTopicRow,
  RemoteSearchFilterSheetContent,
  type SearchNodeItem,
  SearchNodeRow,
  SearchHistoryStrip,
  SearchPanelHeader,
  type SearchResultFilter,
  type SearchTopicItem,
  SearchTopicRow,
} from '../components/SearchPageComponents'

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
  @State private remoteDateRange: RemoteDateRange = 'all'
  @State private filterSheetVisible: boolean = false
  @State private listScrollEnabled: boolean = true
  @StorageLink(StorageKeys.SEARCH_ACTION) @Watch('onSearchActionCommand') searchActionCommand: string = ''
  @StorageLink(StorageKeys.PENDING_SEARCH_QUERY) @Watch('onPendingSearchQueryChanged') pendingSearchQuery: string = ''
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0

  private api: ApiService = new ApiService()
  private sov2ex: Sov2exService = new Sov2exService()
  private scroller: Scroller = new Scroller()
  private readonly PULL_REFRESH_THRESHOLD: number = 84

  aboutToAppear(): void {
    this.keyword = ''
    this.errorMessage = ''
    this.loadLocalCollections()
    this.loadCacheCollections()
    this.loadSourceMode()
    this.loadHistory()
    this.consumePendingSearchQuery()
  }

  aboutToDisappear(): void {
    this.recordHistory()
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        this.SearchPanel()
        Column() {
          PullRefresh({
            scroller: this.scroller,
            indicatorTop: this.topH + ThemeConstants.TITLE_BAR_HEIGHT,
            threshold: this.PULL_REFRESH_THRESHOLD,
            onRefresh: async () => {
              await this.refreshSearchSurface()
            },
            onScrollEnableChange: (enabled: boolean) => {
              this.listScrollEnabled = enabled
            }
          }) {
            this.SearchResultSurface()
          }
        }
        .layoutWeight(1)
      }
      .padding({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_MD,
        top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD
      })
      .width('100%')
      .height('100%')

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .bindSheet($$this.filterSheetVisible, this.SearchFilterSheet(), defaultSheetOptions(SheetSize.MEDIUM, () => { this.filterSheetVisible = false }))
  }

  @Builder SearchResultSurface() {
    if (!this.keyword.trim()) {
      this.HistorySection()
    } else if (this.sourceMode === 'externalWeb') {
      this.ExternalWebSearchPanel()
    } else if (this.sourceMode === 'remote') {
      this.RemoteSearchResultList()
    } else {
      this.LocalResultList()
    }
  }

  @Builder SearchPanel() {
    SearchPanelHeader({
      keyword: $keyword,
      loadingText: this.isCacheLoading || this.isNodeIndexLoading ? this.loadingSummary() : '',
      errorMessage: this.errorMessage,
      sourceMode: this.sourceMode,
      onTextChange: (value: string) => {
        this.keyword = value
        this.applyFilter()
        this.resetRemoteResults()
      },
      onSubmit: (_value: string) => { this.runPrimarySearchAction() },
      updateSourceMode: (mode: SearchSourceMode) => { this.updateSourceMode(mode) }
    })
  }

  @Builder HistorySection() {
    if (!this.keyword.trim() && this.history.length > 0) {
      SearchHistoryStrip({
        history: this.history,
        clearAction: () => { this.clearHistory() },
        selectAction: (q: string) => { this.applyHistory(q) }
      })
    }
  }

  @Builder LocalResultList() {
    List({ space: ThemeConstants.SPACE_SM, scroller: this.scroller }) {
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
          ListItem() { SearchTopicRow({ item: item }) }
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
          ListItem() { SearchNodeRow({ item: item }) }
            .onClick(() => {
              let p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
              this.stack.pushPathByName('NodeTopicList', p as Object)
            })
        }, (item: SearchNodeItem) => `n:${item.name}`)
      }

      ListItem() {
        Column() {
          Blank().height(this.bottomH + ThemeConstants.SPACE_XL)
        }
      }
    }
    .enableScrollInteraction(this.listScrollEnabled)
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder ExternalWebSearchPanel() {
    ExternalWebSearchCard({
      keyword: this.keyword,
      openAction: () => { this.openExternalTopicSearch() }
    })
  }

  @Builder RemoteSearchResultList() {
    List({ space: ThemeConstants.SPACE_SM, scroller: this.scroller }) {
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
            EmptyState({ message: '输入关键词后按搜索，筛选在右上角', stateHeight: 96 })
              .borderRadius(ThemeConstants.RADIUS_MD)
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
              .margin({ top: ThemeConstants.SPACE_XS })
          }
        }
        .width('100%')
      }

      ForEach(this.remoteResults, (item: RemoteTopicItem) => {
        ListItem() {
          RemoteTopicRow({
            item: item,
            openUserAction: (username: string) => { this.openUserProfile(username) }
          })
        }
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.stack.pushPathByName('TopicDetail', p as Object)
          })
      }, (item: RemoteTopicItem) => `r:${item.id}`)

      if (this.remoteLoading) {
        ListItem() { EmptyState({ message: '搜索中', stateHeight: 88 }) }
      } else if (this.remoteResults.length < this.remoteTotal) {
        ListItem() {
          AppActionButton({
            label: '加载更多',
            primary: false,
            action: () => { this.executeRemoteSearch(false) }
          })
        }
      }

      ListItem() {
        Column() {
          Blank().height(this.bottomH + ThemeConstants.SPACE_XL)
        }
      }
    }
    .enableScrollInteraction(this.listScrollEnabled)
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder SearchFilterSheet() {
    AppModalScaffold({
      title: '搜索筛选',
      closeAction: () => {
        this.filterSheetVisible = false
      }
    }) {
      if (this.sourceMode === 'remote') {
        ListItem() { this.RemoteFilterSheetContent() }
      } else if (this.sourceMode === 'externalWeb') {
        ListItem() {
          Text('网页搜索会在系统浏览器中打开，不额外提供站内筛选。')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .padding({ top: ThemeConstants.SPACE_SM })
        }
      } else {
        ListItem() { this.LocalFilterSheetContent() }
      }
    }
  }

  @Builder LocalFilterSheetContent() {
    LocalSearchFilterSheetContent({
      keyword: this.keyword,
      resultFilter: this.resultFilter,
      updateResultFilter: (filter: SearchResultFilter) => { this.updateResultFilter(filter) },
      applyAction: () => {
        this.applyFilter()
        this.filterSheetVisible = false
      }
    })
  }

  @Builder RemoteFilterSheetContent() {
    RemoteSearchFilterSheetContent({
      remoteUsername: $remoteUsername,
      remoteNode: $remoteNode,
      keyword: this.keyword,
      remoteSort: this.remoteSort,
      remoteOrder: this.remoteOrder,
      remoteDateRange: this.remoteDateRange,
      remoteLoading: this.remoteLoading,
      hasRemoteFilters: this.hasRemoteFilters(),
      selectSort: (sort: Sov2exSortMode) => {
        this.remoteSort = sort
        this.resetRemoteResults()
      },
      toggleOrder: () => {
        this.remoteOrder = this.remoteOrder === '0' ? '1' : '0'
        this.resetRemoteResults()
      },
      remoteTextChange: () => { this.resetRemoteResults() },
      selectDateRange: (range: RemoteDateRange) => {
        if (this.remoteDateRange === range) {
          return
        }
        this.remoteDateRange = range
        this.executeRemoteSearch(true)
      },
      clearFilters: () => { this.clearRemoteFilters() },
      applySearch: () => {
        this.executeRemoteSearch(true)
        this.filterSheetVisible = false
      }
    })
  }

  private onSearchActionCommand(_propName: string): void {
    const action = SearchPageStateCoordinator.parseActionCommand(this.searchActionCommand)
    if (action === 'filter') {
      this.filterSheetVisible = true
      return
    }
    if (action === 'refresh') {
      if (this.sourceMode === 'externalWeb' && this.keyword.trim().length > 0) {
        this.openExternalTopicSearch()
      } else {
        this.refreshSearchSurface()
      }
    }
  }

  private onPendingSearchQueryChanged(_propName: string): void {
    this.consumePendingSearchQuery()
  }

  private consumePendingSearchQuery(): void {
    const query = SearchPageStateCoordinator.parsePendingQuery(this.pendingSearchQuery)
    if (!query) {
      return
    }
    this.applyHistory(query)
    AppStorage.setOrCreate<string>(StorageKeys.PENDING_SEARCH_QUERY, '')
  }

  private async refreshSearchSurface(): Promise<void> {
    if (this.sourceMode === 'remote') {
      this.executeRemoteSearch(true)
      return
    }
    if (this.usesNodeIndex()) {
      this.allNodes = []
      this.loadNodeIndex()
    }
    this.loadLocalCollections()
    this.loadCacheCollections()
    this.applyFilter()
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

    const results = SearchLocalResultBuilder.build({
      keyword: q,
      resultFilter: this.resultFilter,
      includeTopics: this.showTopicResults(),
      includeNodes: this.showNodeResults(),
      usesNodeIndex: this.usesNodeIndex(),
      savedTopics: this.savedTopics,
      viewedTopics: this.viewedTopics,
      savedNodes: this.savedNodes,
      allNodes: this.allNodes,
      cacheTopicLists: this.cacheTopicLists,
      cacheTopicDetails: this.cacheTopicDetails,
    })
    this.topicResults = results.topicResults
    this.nodeResults = results.nodeResults
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

  private openUserProfile(username: string): void {
    const clean = (username ?? '').trim()
    if (!clean) {
      return
    }
    const p: Record<string, Object> = { 'username': clean }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private runPrimarySearchAction(): void {
    const q = this.keyword.trim()
    if (!q) {
      return
    }
    if (this.sourceMode === 'remote') {
      this.executeRemoteSearch(true)
      return
    }
    if (this.sourceMode === 'externalWeb') {
      this.openExternalTopicSearch()
      return
    }
    this.applyFilter()
    this.recordHistory()
  }

  private showTopicResults(): boolean {
    return SearchPageStateCoordinator.shouldShowTopicResults(this.resultFilter)
  }

  private showNodeResults(): boolean {
    return SearchPageStateCoordinator.shouldShowNodeResults(this.resultFilter)
  }

  private topicSectionTitle(): string {
    return SearchPageStateCoordinator.topicSectionTitle(this.resultFilter)
  }

  private emptyTopicHint(): string {
    return SearchPageStateCoordinator.emptyTopicHint(this.resultFilter)
  }

  private usesNodeIndex(): boolean {
    return SearchPageStateCoordinator.usesNodeIndex(this.sourceMode)
  }

  private sourceModeSummary(): string {
    return SearchPageStateCoordinator.sourceModeSummary(this.sourceMode)
  }

  private loadingSummary(): string {
    return SearchPageStateCoordinator.loadingSummary(this.isCacheLoading, this.isNodeIndexLoading)
  }

  private emptyNodeHint(): string {
    return SearchPageStateCoordinator.emptyNodeHint(this.sourceMode)
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
    const url = SearchPageStateCoordinator.buildExternalTopicSearchUrl(q)
    const want: Want = { action: 'ohos.want.action.viewData', uri: url }
    context.startAbility(want)
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => { })
      })
  }

  private resetRemoteResults(): void {
    const state = SearchPageStateCoordinator.resetRemoteState()
    this.remoteResults = state.results
    this.remoteTotal = state.total
    this.remoteFrom = state.from
    this.remoteError = state.error
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
    this.sov2ex.search({
      q: q,
      from: from,
      size: 20,
      sort: this.remoteSort,
      order: this.remoteOrder,
      username: this.remoteUsername.trim(),
      node: this.remoteNode.trim(),
      gte: this.remoteGte()
    })
      .then((response) => {
        const hits = response.hits || []
        const next = hits.map((hit) => SearchPageStateCoordinator.remoteHitToItem(hit))
          .filter((item: RemoteTopicItem) => item.id > 0)
        this.remoteResults = reset ? next : this.remoteResults.concat(next)
        this.remoteTotal = response.total || this.remoteResults.length
        this.remoteFrom = this.remoteResults.length
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        SearchSettings.recordQuery(context, q)
          .then((items: string[]) => {
            this.history = items
          })
          .catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        this.remoteError = error.message || '远程搜索失败'
      })
      .finally(() => {
        this.remoteLoading = false
      })
  }

  private hasRemoteFilters(): boolean {
    return SearchPageStateCoordinator.hasRemoteFilters(
      this.remoteUsername,
      this.remoteNode,
      this.remoteDateRange,
    )
  }

  private clearRemoteFilters(): void {
    this.remoteUsername = ''
    this.remoteNode = ''
    this.remoteDateRange = 'all'
    this.resetRemoteResults()
    this.executeRemoteSearch(true)
  }

  private remoteGte(): number {
    return SearchPageStateCoordinator.remoteGte(this.remoteDateRange)
  }

}
