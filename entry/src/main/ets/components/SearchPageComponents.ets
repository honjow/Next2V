import {
  AppActionButton,
  AppSearchField,
  FilterChip,
  type SearchSourceMode,
  ThemeConstants,
} from 'shared'

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
export struct SearchPanelHeader {
  @Link keyword: string
  @Prop loadingText: string = ''
  @Prop errorMessage: string = ''
  @Prop sourceMode: SearchSourceMode = 'localWithNodes'
  onTextChange?: (value: string) => void
  onSubmit?: (value: string) => void
  updateSourceMode?: (mode: SearchSourceMode) => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      AppSearchField({
        text: $keyword,
        placeholder: '搜索主题、节点、用户',
        onTextChange: (value: string) => {
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
        this.SourceModeButton('local', '本地')
        this.SourceModeButton('localWithNodes', '节点库')
        this.SourceModeButton('remote', 'SOV2EX')
        this.SourceModeButton('externalWeb', '网页')
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
      Text(this.keyword.trim() ? '使用浏览器搜索 V2EX 主题' : '输入关键词开始搜索')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
      AppActionButton({
        label: '打开网页搜索',
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
        Text('搜索历史')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text('清空')
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
        Text(`${this.item.topics} 主题`)
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
      if (this.item.content) {
        Text(this.item.content)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        Text(`${this.item.replies} 回复`)
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
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
