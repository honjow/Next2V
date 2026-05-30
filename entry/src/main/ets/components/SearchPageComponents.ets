import {
  AppActionButton,
  AppSearchField,
  AppStrings,
  AppTextField,
  FilterChip,
  type Sov2exOrderMode,
  type Sov2exSortMode,
  type SearchSourceMode,
  ThemeConstants,
} from 'shared'

export type SearchResultFilter = 'all' | 'topics' | 'nodes' | 'users'
export type RemoteDateRange = 'all' | 'day' | 'week' | 'month' | 'year'

export interface SearchTopicItem {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  source: string
  updatedAt: number
}

export interface SearchNodeItem {
  name: string
  title: string
  topics: number
  source: string
  updatedAt: number
  score: number
}

export interface RemoteTopicItem {
  id: number
  title: string
  username: string
  content: string
  created: string
  replies: number
  nodeId: number
}

@Component
export struct LocalSearchFilterSheetContent {
  @Prop keyword: string = ''
  @Prop resultFilter: SearchResultFilter = 'all'
  updateResultFilter?: (filter: SearchResultFilter) => void
  applyAction?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text($r('app.string.search_result_type'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ResultFilterButton('all', AppStrings.text($r('app.string.common_all'), 'All'))
        this.ResultFilterButton('topics', AppStrings.text($r('app.string.common_topics'), 'Topics'))
        this.ResultFilterButton('nodes', AppStrings.text($r('app.string.common_nodes'), 'Nodes'))
        this.ResultFilterButton('users', AppStrings.text($r('app.string.common_user'), 'User'))
      }
      .width('100%')
      AppActionButton({
        label: $r('app.string.common_apply'),
        primary: true,
        isEnabled: this.keyword.trim().length > 0,
        action: () => {
          if (this.applyAction) {
            this.applyAction()
          }
        }
      })
    }
    .width('100%')
  }

  @Builder private ResultFilterButton(filter: SearchResultFilter, label: string) {
    FilterChip({
      label,
      selected: this.resultFilter === filter,
      action: () => {
        if (this.updateResultFilter) {
          this.updateResultFilter(filter)
        }
      }
    })
  }
}

@Component
export struct RemoteSearchFilterSheetContent {
  // One-way @Prop (not @Link) so a @ComponentV2 parent can host this V1 component: the author /
  // node text flow down here and back up through onUsernameChange / onNodeChange (which carry the
  // value, since the parent owns the @Local state).
  @Prop remoteUsername: string = ''
  @Prop remoteNode: string = ''
  @Prop keyword: string = ''
  @Prop remoteSort: Sov2exSortMode = 'created'
  @Prop remoteOrder: Sov2exOrderMode = '0'
  @Prop remoteDateRange: RemoteDateRange = 'all'
  @Prop remoteLoading: boolean = false
  @Prop hasRemoteFilters: boolean = false
  selectSort?: (sort: Sov2exSortMode) => void
  toggleOrder?: () => void
  onUsernameChange?: (value: string) => void
  onNodeChange?: (value: string) => void
  selectDateRange?: (range: RemoteDateRange) => void
  clearFilters?: () => void
  applySearch?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text($r('app.string.common_sort'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.RemoteOptionButton(AppStrings.text($r('app.string.common_time'), 'Time'), this.remoteSort === 'created', () => {
          if (this.selectSort) {
            this.selectSort('created')
          }
        })
        this.RemoteOptionButton(AppStrings.text($r('app.string.common_relevance'), 'Relevance'), this.remoteSort === 'sumup', () => {
          if (this.selectSort) {
            this.selectSort('sumup')
          }
        })
        this.RemoteOptionButton(this.remoteOrder === '0' ? AppStrings.text($r('app.string.common_descending'), 'Descending') : AppStrings.text($r('app.string.common_ascending'), 'Ascending'), true, () => {
          if (this.toggleOrder) {
            this.toggleOrder()
          }
        })
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_XS }) {
        AppTextField({
          text: this.remoteUsername,
          placeholder: $r('app.string.common_author'),
          onTextChange: (value: string) => {
            this.remoteUsername = value
            if (this.onUsernameChange) {
              this.onUsernameChange(value)
            }
          }
        })
          .layoutWeight(1)
        AppTextField({
          text: this.remoteNode,
          placeholder: $r('app.string.common_node'),
          onTextChange: (value: string) => {
            this.remoteNode = value
            if (this.onNodeChange) {
              this.onNodeChange(value)
            }
          }
        })
          .layoutWeight(1)
      }
      .width('100%')

      Text($r('app.string.common_time_range'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.RemoteDateButton('all', AppStrings.text($r('app.string.common_unlimited'), 'Any time'))
        this.RemoteDateButton('day', AppStrings.text($r('app.string.common_one_day'), '1 day'))
        this.RemoteDateButton('week', AppStrings.text($r('app.string.common_one_week'), '1 week'))
        this.RemoteDateButton('month', AppStrings.text($r('app.string.common_one_month'), '1 month'))
        this.RemoteDateButton('year', AppStrings.text($r('app.string.common_one_year'), '1 year'))
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_XS }) {
        if (this.hasRemoteFilters) {
          AppActionButton({
            label: $r('app.string.common_clear'),
            primary: false,
            action: () => {
              if (this.clearFilters) {
                this.clearFilters()
              }
            }
          })
            .layoutWeight(1)
        }
        AppActionButton({
          label: this.remoteLoading ? $r('app.string.common_searching') : $r('app.string.common_apply_search'),
          primary: true,
          isEnabled: !this.remoteLoading && this.keyword.trim().length > 0,
          action: () => {
            if (this.applySearch) {
              this.applySearch()
            }
          }
        })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder private RemoteOptionButton(label: string, selected: boolean, action: () => void) {
    FilterChip({
      label,
      selected,
      action
    })
  }

  @Builder private RemoteDateButton(range: RemoteDateRange, label: string) {
    FilterChip({
      label,
      selected: this.remoteDateRange === range,
      fill: true,
      action: () => {
        if (this.selectDateRange) {
          this.selectDateRange(range)
        }
      }
    })
  }
}

@Component
export struct SearchPanelHeader {
  // One-way @Prop (not @Link) so a @ComponentV2 parent can host this V1 component: the keyword
  // flows down here and back up through onTextChange (the parent sanitises + re-sets it).
  @Prop keyword: string = ''
  @Prop loadingText: string = ''
  @Prop errorMessage: string = ''
  @Prop sourceMode: SearchSourceMode = 'localWithNodes'
  onTextChange?: (value: string) => void
  onSubmit?: (value: string) => void
  updateSourceMode?: (mode: SearchSourceMode) => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      AppSearchField({
        text: this.keyword,
        placeholder: $r('app.string.search_topics_nodes_users_placeholder'),
        onTextChange: (value: string) => {
          this.keyword = value
          if (this.onTextChange) {
            this.onTextChange(value)
          }
        },
        onSubmit: (value: string) => {
          if (this.onSubmit) {
            this.onSubmit(value)
          }
        }
      })

      if (this.loadingText) {
        Text(this.loadingText)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }

      this.SourceModeControls()
    }
    .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
    .width('100%')
  }

  @Builder private SourceModeControls() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        this.SourceModeButton('local', AppStrings.text($r('app.string.common_local'), 'Local'))
        this.SourceModeButton('localWithNodes', AppStrings.text($r('app.string.search_filter_nodes_library'), 'Node library'))
        this.SourceModeButton('remote', 'SOV2EX')
        this.SourceModeButton('externalWeb', AppStrings.text($r('app.string.common_web'), 'Web'))
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder private SourceModeButton(mode: SearchSourceMode, label: string) {
    FilterChip({
      label,
      selected: this.sourceMode === mode,
      action: () => {
        if (this.updateSourceMode) {
          this.updateSourceMode(mode)
        }
      }
    })
  }
}

@Component
export struct ExternalWebSearchCard {
  @Prop keyword: string = ''
  openAction?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.keyword.trim() ? $r('app.string.search_browser_v2ex_topics') : $r('app.string.search_enter_keyword_to_start'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
      AppActionButton({
        label: $r('app.string.search_open_web_search'),
        primary: true,
        isEnabled: this.keyword.trim().length > 0,
        action: () => {
          if (this.openAction) {
            this.openAction()
          }
        }
      })
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .layoutWeight(1)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}

@Component
export struct SearchHistoryStrip {
  @Prop history: string[] = []
  clearAction?: () => void
  selectAction?: (query: string) => void

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Row() {
        Text($r('app.string.search_history'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text($r('app.string.common_clear'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .onClick(() => {
            if (this.clearAction) {
              this.clearAction()
            }
          })
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
              .onClick(() => {
                if (this.selectAction) {
                  this.selectAction(q)
                }
              })
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

@Component
export struct SearchTopicRow {
  item: SearchTopicItem = {
    id: 0,
    title: '',
    nodeName: '',
    nodeTitle: '',
    username: '',
    source: '',
    updatedAt: 0
  }

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(this.item.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(`${this.item.nodeTitle} / ${this.item.nodeName} · @${this.item.username}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.item.source)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}

@Component
export struct SearchNodeRow {
  item: SearchNodeItem = {
    name: '',
    title: '',
    topics: 0,
    source: '',
    updatedAt: 0,
    score: 0
  }

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.item.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.name)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.item.source)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
        Text(AppStrings.format(AppStrings.text($r('app.string.search_N_topics'), '{0} topics'), [String(this.item.topics)]))
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
}

@Component
export struct RemoteTopicRow {
  item: RemoteTopicItem = {
    id: 0,
    title: '',
    username: '',
    content: '',
    created: '',
    replies: 0,
    nodeId: 0
  }
  openUserAction?: (username: string) => void

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(this.item.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.item.content) {
        Text(this.item.content)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(`@${this.item.username}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .layoutWeight(1)
          .onClick(() => {
            if (this.openUserAction) {
              this.openUserAction(this.item.username)
            }
          })
        Text(AppStrings.format(AppStrings.text($r('app.string.search_N_replies'), '{0} replies'), [String(this.item.replies)]))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.item.created)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
