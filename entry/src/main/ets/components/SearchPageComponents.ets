import { AppActionButton, AppStrings, ThemeConstants } from 'shared'

export type SearchResultFilter = 'all' | 'topics' | 'nodes'
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
@ComponentV2
export struct ExternalWebSearchCard {
  @Param keyword: string = '';
  @Event openAction?: () => void;

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(
        this.keyword.trim()
          ? $r('app.string.search_browser_v2ex_topics')
          : $r('app.string.search_enter_keyword_to_start'),
      )
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
        },
      })
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .layoutWeight(1)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
@ComponentV2
export struct SearchHistoryStrip {
  @Param history: string[] = [];
  @Event clearAction?: () => void;
  @Event selectAction?: (query: string) => void;

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
      }.width('100%')
      Scroll() {
        Row({ space: ThemeConstants.SPACE_XS }) {
          ForEach(
            this.history,
            (q: string) => {
              Text(q)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor($r('sys.color.font_primary'))
                .padding({
                  left: ThemeConstants.SPACE_SM,
                  right: ThemeConstants.SPACE_SM,
                  top: 6,
                  bottom: 6,
                })
                .borderRadius(ThemeConstants.RADIUS_ROUND)
                .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                .onClick(() => {
                  if (this.selectAction) {
                    this.selectAction(q)
                  }
                })
            },
            (q: string) => q,
          )
        }.width('100%')
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
    .width('100%')
  }
}
@ComponentV2
export struct SearchTopicRow {
  @Param item: SearchTopicItem = {
    id: 0,
    title: '',
    nodeName: '',
    nodeTitle: '',
    username: '',
    source: '',
    updatedAt: 0,
  };

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
@ComponentV2
export struct SearchNodeRow {
  @Param item: SearchNodeItem = {
    name: '',
    title: '',
    topics: 0,
    source: '',
    updatedAt: 0,
    score: 0,
  };

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
        Text(
          AppStrings.format(AppStrings.text($r('app.string.search_N_topics'), '{0} topics'), [
            String(this.item.topics),
          ]),
        )
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.End)
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
@ComponentV2
export struct RemoteTopicRow {
  @Param item: RemoteTopicItem = {
    id: 0,
    title: '',
    username: '',
    content: '',
    created: '',
    replies: 0,
    nodeId: 0,
  };
  @Event openUserAction?: (username: string) => void;

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
        Text(
          AppStrings.format(AppStrings.text($r('app.string.search_N_replies'), '{0} replies'), [
            String(this.item.replies),
          ]),
        )
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.item.created)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }.width('100%')
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
