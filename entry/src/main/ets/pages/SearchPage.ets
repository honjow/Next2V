import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AppStrings,
  type NodeTopicListParams,
  type SavedNode,
  type SavedTopic,
  type SearchSourceMode,
  SectionHeader as SharedSectionHeader,
  ListDivider as SharedListDivider,
  EmptyState,
  PullRefresh,
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
  translateApiError,
  connectNavStack,
  connectLayoutSafeArea,
  LayoutSafeAreaState,
  connectSearchAction,
  SearchActionState,
  SearchQueryBus,
} from 'shared'
import { SearchLocalResultBuilder } from '../model/SearchLocalResultBuilder'
import {
  RemoteSearchCoordinator,
} from '../model/RemoteSearchCoordinator'
import {
  type RemoteFilterEffect,
  SearchFilterCoordinator,
} from '../model/SearchFilterCoordinator'
import {
  SearchPageStateCoordinator,
} from '../model/SearchPageStateCoordinator'
import {
  SearchLocalDataCoordinator,
} from '../model/SearchLocalDataCoordinator'
import {
  SearchSettingsAdapter,
} from '../model/SearchSettingsAdapter'
import {
  SearchSourceCoordinator,
} from '../model/SearchSourceCoordinator'
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

@ComponentV2
export struct SearchPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack

  @Local private keyword: string = ''
  @Local private errorMessage: string = ''

  @Local private savedTopics: SavedTopic[] = []
  @Local private viewedTopics: ViewedTopic[] = []
  @Local private savedNodes: SavedNode[] = []
  @Local private allNodes: V2exNode[] = []
  @Local private isNodeIndexLoading: boolean = false

  @Local private cacheTopicLists: SearchTopicItem[] = []
  @Local private cacheTopicDetails: SearchTopicItem[] = []
  @Local private isCacheLoading: boolean = false

  @Local private history: string[] = []
  @Local private sourceMode: SearchSourceMode = 'localWithNodes'
  @Local private resultFilter: SearchResultFilter = 'all'

  @Local private topicResults: SearchTopicItem[] = []
  @Local private nodeResults: SearchNodeItem[] = []
  @Local private remoteResults: RemoteTopicItem[] = []
  @Local private remoteTotal: number = 0
  @Local private remoteFrom: number = 0
  @Local private remoteLoading: boolean = false
  @Local private remoteError: string = ''
  @Local private remoteSort: Sov2exSortMode = 'created'
  @Local private remoteOrder: Sov2exOrderMode = '0'
  @Local private remoteUsername: string = ''
  @Local private remoteNode: string = ''
  @Local private remoteDateRange: RemoteDateRange = 'all'
  @Local private filterSheetVisible: boolean = false
  @Local private listScrollEnabled: boolean = true
  // V2 mirror of the one-directional SEARCH_ACTION + PENDING_SEARCH_QUERY appbar / cross-page
  // input buses (Index dual-writes SEARCH_ACTION; SearchQueryBus dual-writes PENDING_SEARCH_QUERY).
  // Reacted to via @Monitor below; never read in build().
  @Local private actionState: SearchActionState = connectSearchAction()
  // Window safe-area metrics (V2 mirror; EntryAbility dual-writes the V1 AppStorage keys + this).
  // Read in build() (top padding / pull-refresh indicator), so this subscribes to layout changes.
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()

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
            indicatorTop: this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT,
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
        top: this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD
      })
      .width('100%')
      .height('100%')

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .bindSheet(this.filterSheetVisible!!, this.SearchFilterSheet(), defaultSheetOptions(SheetSize.MEDIUM, () => { this.filterSheetVisible = false }))
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
      keyword: this.keyword,
      loadingText: this.isCacheLoading || this.isNodeIndexLoading ? this.loadingSummary() : '',
      errorMessage: this.errorMessage,
      sourceMode: this.sourceMode,
      onTextChange: (value: string) => {
        this.handleKeywordChange(value)
      },
      onSubmit: (_value: string) => { this.runPrimarySearchAction() },
      updateSourceMode: (mode: SearchSourceMode) => { this.updateSourceMode(mode) }
    })
  }

  @Builder HistorySection() {
    if (SearchSourceCoordinator.shouldShowHistory(this.keyword, this.history.length)) {
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
                message: this.keyword.trim() ? this.emptyTopicHint() : AppStrings.text($r('app.string.search_enter_keyword_to_start'), 'Enter keywords to start searching'),
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
            SharedSectionHeader({ title: AppStrings.format(AppStrings.text($r('app.string.search_node_results'), 'Node results {0}'), [String(this.nodeResults.length)]) })
            if (this.nodeResults.length === 0) {
              EmptyState({
                message: this.keyword.trim() ? AppStrings.text($r('app.string.search_no_nodes'), 'No matching nodes') : this.emptyNodeHint(),
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
          Blank().height(this.layout.bottomAvoidHeight + ThemeConstants.SPACE_XL)
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
            EmptyState({ message: AppStrings.text($r('app.string.search_filter_hint'), 'Enter keywords and tap Search; filter is in the top right'), stateHeight: 96 })
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
        ListItem() { EmptyState({ message: AppStrings.text($r('app.string.common_searching'), 'Searching'), stateHeight: 88 }) }
      } else if (this.remoteResults.length < this.remoteTotal) {
        ListItem() {
          AppActionButton({
            label: $r('app.string.common_load_more'),
            primary: false,
            action: () => { this.executeRemoteSearch(false) }
          })
        }
      }

      ListItem() {
        Column() {
          Blank().height(this.layout.bottomAvoidHeight + ThemeConstants.SPACE_XL)
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
      title: $r('app.string.search_filter_title'),
      closeAction: () => {
        this.filterSheetVisible = false
      }
    }) {
      if (this.sourceMode === 'remote') {
        ListItem() { this.RemoteFilterSheetContent() }
      } else if (this.sourceMode === 'externalWeb') {
        ListItem() {
          Text($r('app.string.search_web_filter_hint'))
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
      remoteUsername: this.remoteUsername,
      remoteNode: this.remoteNode,
      keyword: this.keyword,
      remoteSort: this.remoteSort,
      remoteOrder: this.remoteOrder,
      remoteDateRange: this.remoteDateRange,
      remoteLoading: this.remoteLoading,
      hasRemoteFilters: this.hasRemoteFilters(),
      selectSort: (sort: Sov2exSortMode) => {
        this.selectRemoteSort(sort)
      },
      toggleOrder: () => {
        this.toggleRemoteOrder()
      },
      onUsernameChange: (value: string) => {
        this.remoteUsername = value
        this.applyRemoteFilterEffect(SearchFilterCoordinator.remoteTextChanged())
      },
      onNodeChange: (value: string) => {
        this.remoteNode = value
        this.applyRemoteFilterEffect(SearchFilterCoordinator.remoteTextChanged())
      },
      selectDateRange: (range: RemoteDateRange) => {
        this.selectRemoteDateRange(range)
      },
      clearFilters: () => { this.clearRemoteFilters() },
      applySearch: () => {
        this.executeRemoteSearch(true)
        this.filterSheetVisible = false
      }
    })
  }

  @Monitor('actionState.command')
  onSearchActionCommand(): void {
    const action = SearchPageStateCoordinator.parseActionCommand(this.actionState.command)
    if (action === 'filter') {
      this.filterSheetVisible = true
      return
    }
    if (action === 'refresh') {
      const refreshAction = SearchSourceCoordinator.refreshAction(this.sourceMode, this.keyword)
      if (refreshAction === 'external') {
        this.openExternalTopicSearch()
      } else if (refreshAction === 'remote') {
        this.executeRemoteSearch(true)
      } else {
        this.refreshSearchSurface()
      }
    }
  }

  @Monitor('actionState.pendingQuery')
  onPendingSearchQueryChanged(): void {
    this.consumePendingSearchQuery()
  }

  private consumePendingSearchQuery(): void {
    const query = SearchPageStateCoordinator.parsePendingQuery(this.actionState.pendingQuery)
    if (!query) {
      return
    }
    this.applyHistory(query)
    SearchQueryBus.clearPending()
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
    SearchLocalDataCoordinator.loadLocalCollections(context)
      .then((collections) => {
        this.savedTopics = collections.savedTopics
        this.viewedTopics = collections.viewedTopics
        this.savedNodes = collections.savedNodes
        this.applyFilter()
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
      })
  }

  private loadCacheCollections(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.isCacheLoading = true
    SearchLocalDataCoordinator.loadCacheCollections(context)
      .then((collections) => {
        this.cacheTopicLists = collections.cacheTopicLists
        this.cacheTopicDetails = collections.cacheTopicDetails
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
    SearchLocalDataCoordinator.loadNodeIndex(this.api)
      .then((nodes: V2exNode[]) => {
        this.allNodes = nodes
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
    SearchSettingsAdapter.loadSourceMode(context)
      .then((mode: SearchSourceMode) => {
        this.sourceMode = mode
        const effect = SearchSourceCoordinator.loadedSourceModeEffect(mode, this.keyword)
        if (effect.shouldLoadNodeIndex) {
          this.loadNodeIndex()
        } else if (effect.shouldExecuteRemote) {
          this.executeRemoteSearch(true)
        } else if (effect.shouldApplyLocalFilter) {
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
    SearchSettingsAdapter.loadHistory(context)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => {
        this.history = []
      })
  }

  private recordHistory(): void {
    const q = SearchSourceCoordinator.recordableQuery(this.keyword)
    if (!q) {
      return
    }
    this.recordHistoryQuery(q)
  }

  private clearHistory(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettingsAdapter.clearHistory(context)
      .then(() => {
        this.history = []
      })
      .catch((_error: Error) => { })
  }

  private applyHistory(q: string): void {
    const selection = SearchSourceCoordinator.applyHistory(q, this.sourceMode)
    if (!selection.shouldApply) {
      return
    }
    this.keyword = selection.query
    this.applyFilter()
    this.resetRemoteResults()
    if (selection.shouldExecuteRemote) {
      this.executeRemoteSearch(true)
    }
    this.recordHistoryQuery(selection.query)
  }

  private handleKeywordChange(value: string): void {
    const effect = SearchSourceCoordinator.keywordChanged(value)
    this.keyword = effect.query
    if (effect.shouldApplyLocalFilter) {
      this.applyFilter()
    }
    if (effect.shouldResetRemote) {
      this.resetRemoteResults()
    }
  }

  private recordHistoryQuery(query: string): void {
    const q = SearchSourceCoordinator.recordableQuery(query)
    if (!q) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettingsAdapter.recordHistory(context, q)
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
    const transition = SearchSourceCoordinator.transitionSourceMode(this.sourceMode, mode, this.keyword)
    if (!transition.changed) {
      return
    }
    this.sourceMode = transition.mode
    if (transition.shouldResetRemote) {
      this.resetRemoteResults()
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettingsAdapter.saveSourceMode(context, transition.mode)
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
      })
    if (transition.shouldLoadNodeIndex) {
      this.loadNodeIndex()
    } else if (transition.shouldExecuteRemote) {
      this.executeRemoteSearch(true)
    } else if (transition.shouldApplyLocalFilter) {
      this.applyFilter()
    }
  }

  private updateResultFilter(filter: SearchResultFilter): void {
    const effect = SearchFilterCoordinator.updateLocalResultFilter(this.resultFilter, filter)
    if (!effect.changed) {
      return
    }
    this.resultFilter = effect.filter
    if (effect.shouldApplyLocalFilter) {
      this.applyFilter()
    }
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
    const action = SearchSourceCoordinator.primaryAction(this.sourceMode, this.keyword)
    if (action === 'remote') {
      this.executeRemoteSearch(true)
      return
    }
    if (action === 'external') {
      this.openExternalTopicSearch()
      return
    }
    if (action === 'local') {
      this.applyFilter()
      this.recordHistory()
    }
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
    this.recordHistoryQuery(q)
    const url = SearchPageStateCoordinator.buildExternalTopicSearchUrl(q)
    const want: Want = { action: 'ohos.want.action.viewData', uri: url }
    context.startAbility(want)
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => { })
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
    if (!RemoteSearchCoordinator.canExecute(q, this.remoteLoading)) {
      return
    }
    if (reset) {
      this.remoteResults = []
      this.remoteTotal = 0
      this.remoteFrom = 0
      this.remoteError = ''
    }
    this.remoteLoading = true
    this.sov2ex.search(RemoteSearchCoordinator.buildRequest({
      keyword: q,
      from: this.remoteFrom,
      sort: this.remoteSort,
      order: this.remoteOrder,
      username: this.remoteUsername,
      node: this.remoteNode,
      dateRange: this.remoteDateRange,
    }, reset))
      .then((response) => {
        const state = RemoteSearchCoordinator.mergeResponse(this.remoteResults, response, reset)
        this.remoteResults = state.results
        this.remoteTotal = state.total
        this.remoteFrom = state.from
        this.recordHistoryQuery(q)
      })
      .catch((error: Error) => {
        this.remoteError = translateApiError(error)
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
    const effect = SearchFilterCoordinator.clearRemoteFilters()
    this.remoteUsername = effect.username
    this.remoteNode = effect.node
    this.remoteDateRange = effect.dateRange
    this.applyRemoteFilterEffect(effect)
  }

  private selectRemoteSort(sort: Sov2exSortMode): void {
    const effect = SearchFilterCoordinator.selectRemoteSort(this.remoteSort, sort)
    this.remoteSort = effect.sort
    this.applyRemoteFilterEffect(effect)
  }

  private toggleRemoteOrder(): void {
    const effect = SearchFilterCoordinator.toggleRemoteOrder(this.remoteOrder)
    this.remoteOrder = effect.order
    this.applyRemoteFilterEffect(effect)
  }

  private selectRemoteDateRange(range: RemoteDateRange): void {
    const effect = SearchFilterCoordinator.selectRemoteDateRange(this.remoteDateRange, range)
    this.remoteDateRange = effect.dateRange
    this.applyRemoteFilterEffect(effect)
  }

  private applyRemoteFilterEffect(effect: RemoteFilterEffect): void {
    if (!effect.changed) {
      return
    }
    if (effect.shouldResetRemote) {
      this.resetRemoteResults()
    }
    if (
      effect.shouldExecuteRemote &&
      SearchFilterCoordinator.shouldApplyRemoteFilters(this.keyword, this.remoteLoading)
    ) {
      this.executeRemoteSearch(true)
    }
  }

}
