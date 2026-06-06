import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AppStrings,
  type NodeTopicListParams,
  type SavedNode,
  type SavedTopic,
  SectionHeader as SharedSectionHeader,
  ListDivider as SharedListDivider,
  EmptyState,
  PullRefreshListScaffold,
  Sov2exService,
  type Sov2exOrderMode,
  type Sov2exSortMode,
  ThemeConstants,
  type TopicDetailParams,
  type V2exNode,
  type ViewedTopic,
  translateApiError,
  connectNavStack,
  connectSearchAction,
  SearchActionState,
  SearchQueryBus,
} from 'shared'
import { SearchLocalResultBuilder } from '../model/SearchLocalResultBuilder'
import { RemoteSearchCoordinator } from '../model/RemoteSearchCoordinator'
import { SearchPageStateCoordinator } from '../model/SearchPageStateCoordinator'
import { SearchLocalDataCoordinator } from '../model/SearchLocalDataCoordinator'
import { SearchSettingsAdapter } from '../model/SearchSettingsAdapter'
import {
  ExternalWebSearchCard,
  type RemoteDateRange,
  type RemoteTopicItem,
  RemoteTopicRow,
  type SearchNodeItem,
  SearchNodeRow,
  SearchHistoryStrip,
  type SearchResultFilter,
  type SearchTopicItem,
  SearchTopicRow,
} from '../components/SearchPageComponents'

// Method C: search is one unified surface. The query lives in the title-bar input (SearchTitleField,
// hosted by Index's HdsNavDestination title bar) — there is no separate search row in the page body.
// Local content (favorites / recently viewed / offline cache / node library) filters as you type; SOV2EX
// topics fetch on submit (Enter) with the default sort; "search in browser" is the fallback when the
// SOV2EX section is empty or errors. There are no source-mode chips, no per-user dimension, and no filter
// sheet — the advanced author/node/date/sort filters were removed in favour of a single simple box.
@ComponentV2
export struct SearchPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack;

  @Local private keyword: string = '';
  @Local private errorMessage: string = '';

  @Local private savedTopics: SavedTopic[] = [];
  @Local private viewedTopics: ViewedTopic[] = [];
  @Local private savedNodes: SavedNode[] = [];
  @Local private allNodes: V2exNode[] = [];

  @Local private cacheTopicLists: SearchTopicItem[] = [];
  @Local private cacheTopicDetails: SearchTopicItem[] = [];

  @Local private history: string[] = [];

  @Local private topicResults: SearchTopicItem[] = [];
  @Local private nodeResults: SearchNodeItem[] = [];
  @Local private remoteResults: RemoteTopicItem[] = [];
  @Local private remoteTotal: number = 0;
  @Local private remoteFrom: number = 0;
  @Local private remoteLoading: boolean = false;
  @Local private remoteError: string = '';
  @Local private listScrollEnabled: boolean = true;

  // The filter sheet is gone: result type is always "all" (topics + nodes) and the SOV2EX query uses these
  // fixed defaults. Kept as named fields so executeRemoteSearch / SearchLocalResultBuilder read intent, not
  // magic literals; none of them change at runtime anymore.
  private readonly resultFilter: SearchResultFilter = 'all';
  private readonly remoteSort: Sov2exSortMode = 'created';
  private readonly remoteOrder: Sov2exOrderMode = '0';
  private readonly remoteUsername: string = '';
  private readonly remoteNode: string = '';
  private readonly remoteDateRange: RemoteDateRange = 'all';

  // V2 mirror of the title-bar input + cross-page input buses (SearchTitleField writes keyword/submitSeq;
  // SearchQueryBus writes pendingQuery). Reacted to via @Monitor below; keyword is also written back here so
  // the title-bar field reflects a seeded query.
  @Local private actionState: SearchActionState = connectSearchAction();
  // Set just before SearchPage writes actionState.keyword itself, so its own keyword monitor does not
  // re-handle the change as if it were a fresh title-bar edit (the monitor clears the flag on the next fire).
  private suppressKeywordMonitor: boolean = false;

  private api: ApiService = new ApiService();
  private sov2ex: Sov2exService = new Sov2exService();
  private scroller: Scroller = new Scroller();
  private readonly PULL_REFRESH_THRESHOLD: number = 84;

  aboutToAppear(): void {
    this.keyword = ''
    this.errorMessage = ''
    // Reset the title-bar field for a fresh search each visit (no-op if it is already empty).
    this.setTitleBarKeyword('')
    this.loadLocalCollections()
    this.loadCacheCollections()
    this.loadNodeIndex()
    this.loadHistory()
    this.consumePendingSearchQuery()
  }

  aboutToDisappear(): void {
    this.recordHistory()
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Reuse the shared immersive list scaffold: it inserts the top/bottom safe-area spacers INSIDE the
      // List (so content scrolls under the translucent title bar like every other sub-page) and exposes
      // onReachEnd for scroll-triggered SOV2EX pagination. No hard top padding here — that would push the
      // whole page below the bar and kill immersion.
      PullRefreshListScaffold({
        scroller: this.scroller,
        refreshThreshold: this.PULL_REFRESH_THRESHOLD,
        scrollEnabled: this.listScrollEnabled,
        onRefresh: async () => {
          await this.refreshSearchSurface()
        },
        onScrollEnableChange: (enabled: boolean) => {
          this.listScrollEnabled = enabled
        },
        onReachEnd: () => {
          this.executeRemoteSearch(false)
        },
      }) {
        this.SearchContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // Emits the scaffold List's content rows (the scaffold wraps them between the safe-area spacers, so each
  // top-level child here must be a ListItem). A local-collection-load error (rare) shows as the first row.
  @Builder SearchContent() {
    if (this.errorMessage) {
      ListItem() {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .width('100%')
      }
    }
    if (!this.keyword.trim()) {
      this.HistorySection()
    } else {
      this.ResultSections()
    }
  }

  @Builder HistorySection() {
    if (SearchPageStateCoordinator.shouldShowHistory(this.keyword, this.history.length)) {
      ListItem() {
        SearchHistoryStrip({
          history: this.history,
          clearAction: () => {
            this.clearHistory()
          },
          selectAction: (q: string) => {
            this.applyHistory(q)
          },
        })
      }
    }
  }

  @Builder ResultSections() {
    if (this.showTopicResults()) {
      ListItem() {
        Column() {
          SharedSectionHeader({
            title: `${this.topicSectionTitle()} ${this.topicResults.length}`,
          })
          if (this.topicResults.length === 0) {
            EmptyState({
              message: this.keyword.trim()
                ? this.emptyTopicHint()
                : AppStrings.text(
                    $r('app.string.search_enter_keyword_to_start'),
                    'Enter keywords to start searching',
                  ),
              stateHeight: 96,
            })
              .borderRadius(ThemeConstants.RADIUS_MD)
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
              .margin({ top: ThemeConstants.SPACE_XS })
          }
        }.width('100%')
      }

      ForEach(
        this.topicResults.slice(0, 80),
        (item: SearchTopicItem) => {
          ListItem() {
            SearchTopicRow({ item: item })
          }
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.stack.pushPathByName('TopicDetail', p as Object)
          })
        },
        (item: SearchTopicItem) => `t:${item.id}`,
      )
    }

    if (this.showTopicResults() && this.showNodeResults()) {
      ListItem() {
        SharedListDivider({ inset: 0 })
      }
    }

    if (this.showNodeResults()) {
      ListItem() {
        Column() {
          SharedSectionHeader({
            title: AppStrings.format(
              AppStrings.text($r('app.string.search_node_results'), 'Node results {0}'),
              [String(this.nodeResults.length)],
            ),
          })
          if (this.nodeResults.length === 0) {
            EmptyState({
              message: this.keyword.trim()
                ? AppStrings.text($r('app.string.search_no_nodes'), 'No matching nodes')
                : this.emptyNodeHint(),
              stateHeight: 96,
            })
              .borderRadius(ThemeConstants.RADIUS_MD)
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
              .margin({ top: ThemeConstants.SPACE_XS })
          }
        }.width('100%')
      }

      ForEach(
        this.nodeResults.slice(0, 80),
        (item: SearchNodeItem) => {
          ListItem() {
            SearchNodeRow({ item: item })
          }
          .onClick(() => {
            let p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
            this.stack.pushPathByName('NodeTopicList', p as Object)
          })
        },
        (item: SearchNodeItem) => `n:${item.name}`,
      )
    }
    ListItem() {
      SharedListDivider({ inset: 0 })
    }

    this.RemoteSection()
  }

  @Builder RemoteSection() {
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
        }
      }.width('100%')
    }

    ForEach(
      this.remoteResults,
      (item: RemoteTopicItem) => {
        ListItem() {
          RemoteTopicRow({
            item: item,
            openUserAction: (username: string) => {
              this.openUserProfile(username)
            },
          })
        }
        .onClick(() => {
          let p: TopicDetailParams = { topicId: item.id }
          this.stack.pushPathByName('TopicDetail', p as Object)
        })
      },
      (item: RemoteTopicItem) => `r:${item.id}`,
    )

    // Pagination is automatic via the scaffold's onReachEnd -> executeRemoteSearch(false); this is just the
    // in-flight footer. Scrolling to the end fetches the next page — no manual "load more" tap.
    if (this.remoteLoading) {
      ListItem() {
        EmptyState({
          message: AppStrings.text($r('app.string.common_searching'), 'Searching'),
          stateHeight: 88,
        })
      }
    } else if (this.remoteResults.length === 0) {
      // SOV2EX returned nothing (or has not run yet): fall back to a browser search button.
      ListItem() {
        ExternalWebSearchCard({
          keyword: this.keyword,
          openAction: () => {
            this.openExternalTopicSearch()
          },
        })
      }
    }
  }

  @Monitor('actionState.keyword')
  onTitleBarKeywordChanged(): void {
    if (this.suppressKeywordMonitor) {
      this.suppressKeywordMonitor = false
      return
    }
    this.handleKeywordChange(this.actionState.keyword)
  }

  @Monitor('actionState.submitSeq')
  onTitleBarSubmit(): void {
    this.runPrimarySearchAction()
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

  // Write the keyword into the title-bar bus without re-triggering our own keyword monitor (we have already
  // handled the change locally). Only arm the guard when the value actually differs, otherwise the monitor
  // would not fire and the guard would leak into the next genuine title-bar edit.
  private setTitleBarKeyword(value: string): void {
    if (this.actionState.keyword === value) {
      return
    }
    this.suppressKeywordMonitor = true
    this.actionState.keyword = value
  }

  private async refreshSearchSurface(): Promise<void> {
    this.allNodes = []
    this.loadNodeIndex()
    this.loadLocalCollections()
    this.loadCacheCollections()
    this.applyFilter()
    if (this.keyword.trim().length > 0) {
      this.executeRemoteSearch(true)
    }
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
  }

  private loadNodeIndex(): void {
    if (this.allNodes.length > 0) {
      this.applyFilter()
      return
    }
    SearchLocalDataCoordinator.loadNodeIndex(this.api)
      .then((nodes: V2exNode[]) => {
        this.allNodes = nodes
        this.applyFilter()
      })
      .catch((_error: Error) => {
        this.allNodes = []
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
    const q = SearchPageStateCoordinator.recordableQuery(this.keyword)
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
      .catch((_error: Error) => {})
  }

  private applyHistory(q: string): void {
    const clean = (q ?? '').trim()
    if (!clean) {
      return
    }
    // Seed everything synchronously so runPrimarySearchAction sees the right keyword, then mirror into the
    // title-bar field (monitor suppressed) so the input shows the chosen query.
    this.handleKeywordChange(clean)
    this.setTitleBarKeyword(clean)
    this.runPrimarySearchAction()
  }

  private handleKeywordChange(value: string): void {
    this.keyword = value
    this.applyFilter()
    this.resetRemoteResults()
  }

  private recordHistoryQuery(query: string): void {
    const q = SearchPageStateCoordinator.recordableQuery(query)
    if (!q) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettingsAdapter.recordHistory(context, q)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => {})
  }

  private applyFilter(): void {
    const q = this.keyword.trim().toLowerCase()
    if (!q) {
      this.topicResults = []
      this.nodeResults = []
      return
    }

    const results = SearchLocalResultBuilder.build({
      keyword: q,
      resultFilter: this.resultFilter,
      includeTopics: this.showTopicResults(),
      includeNodes: this.showNodeResults(),
      usesNodeIndex: true,
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

  private openUserProfile(username: string): void {
    const clean = (username ?? '').trim()
    if (!clean) {
      return
    }
    const p: Record<string, Object> = { 'username': clean }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private runPrimarySearchAction(): void {
    if (this.keyword.trim().length === 0) {
      return
    }
    this.applyFilter()
    this.executeRemoteSearch(true)
    this.recordHistory()
  }

  private showTopicResults(): boolean {
    return SearchPageStateCoordinator.shouldShowTopicResults(this.resultFilter)
  }

  private showNodeResults(): boolean {
    return SearchPageStateCoordinator.shouldShowNodeResults(this.resultFilter)
  }

  private topicSectionTitle(): string {
    return SearchPageStateCoordinator.topicSectionTitle()
  }

  private emptyTopicHint(): string {
    return SearchPageStateCoordinator.emptyTopicHint()
  }

  private emptyNodeHint(): string {
    return SearchPageStateCoordinator.emptyNodeHint()
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
    context.startAbility(want).catch((error: Error) => {
      promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
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
    // canExecute already gates on a non-empty query + no in-flight request (remoteLoading), which doubles as
    // the concurrency lock for the scaffold's onReachEnd. For pagination (reset === false) also stop once the
    // last page is loaded, so reaching the end of a complete result set does not re-fetch.
    if (!RemoteSearchCoordinator.canExecute(q, this.remoteLoading)) {
      return
    }
    if (!reset && this.remoteResults.length >= this.remoteTotal) {
      return
    }
    if (reset) {
      this.remoteResults = []
      this.remoteTotal = 0
      this.remoteFrom = 0
      this.remoteError = ''
    }
    this.remoteLoading = true
    this.sov2ex
      .search(
        RemoteSearchCoordinator.buildRequest(
          {
            keyword: q,
            from: this.remoteFrom,
            sort: this.remoteSort,
            order: this.remoteOrder,
            username: this.remoteUsername,
            node: this.remoteNode,
            dateRange: this.remoteDateRange,
          },
          reset,
        ),
      )
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
}
