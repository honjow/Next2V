import { FilterChip, ThemeConstants, V2exNode, V2exTopic } from 'shared'
import type { SavedNode } from 'shared'

export type DiscoverTopicMode = 'hot' | 'rank' | 'latest' | 'recent'

@Component
export struct DiscoverSectionTitle {
  @Prop title: string = ''

  build() {
    Text(this.title)
      .fontSize(ThemeConstants.FONT_SIZE_TITLE)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .padding({ top: ThemeConstants.SPACE_SM })
  }
}

@Component
export struct DiscoverTopicModeButton {
  @Prop label: string = ''
  @Prop selected: boolean = false
  action?: () => void

  build() {
    FilterChip({
      label: this.label,
      selected: this.selected,
      action: () => {
        if (this.action) {
          this.action()
        }
      }
    })
  }
}

@Component
export struct DiscoverHotTopicRow {
  @Prop topic: V2exTopic = {
    id: 0,
    title: '',
    url: '',
    content: '',
    content_rendered: '',
    replies: 0,
    member: {
      id: 0,
      username: '',
      tagline: '',
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    },
    node: {
      id: 0,
      name: '',
      title: '',
      title_alternative: '',
      url: '',
      topics: 0,
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    },
    created: 0,
    last_modified: 0,
    last_touched: 0
  }
  openAction?: () => void

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.topic.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: ThemeConstants.SPACE_XS }) {
          Text(this.topic.node.title)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('·')
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
          Text(this.topic.member.username)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${this.topic.replies}`)
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
      if (this.openAction) {
        this.openAction()
      }
    })
  }
}

@Component
export struct DiscoverNodeCard {
  @Prop node: V2exNode = {
    id: 0,
    name: '',
    title: '',
    title_alternative: '',
    url: '',
    topics: 0,
    avatar_mini: '',
    avatar_normal: '',
    avatar_large: ''
  }
  openAction?: () => void

  build() {
    Column() {
      Text(this.node.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`${this.node.topics} 主题`)
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
      if (this.openAction) {
        this.openAction()
      }
    })
  }
}

@Component
export struct DiscoverNodeChip {
  @Prop node: SavedNode = { name: '', title: '', topics: 0, savedAt: 0 }
  openAction?: () => void

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.node.title || this.node.name)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.node.topics > 0) {
        Text(`${this.node.topics}`)
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
      if (this.openAction) {
        this.openAction()
      }
    })
  }
}

@Component
export struct DiscoverEmptyState {
  @Prop message: ResourceStr = $r('app.string.search_no_nodes')

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
  }
}

@Component
export struct DiscoverErrorState {
  @Prop message: string = ''
  @Prop topPadding: number = 0
  @Prop bottomPadding: number = 0
  retryAction?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          if (this.retryAction) {
            this.retryAction()
          }
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: this.topPadding, bottom: this.bottomPadding })
  }
}
