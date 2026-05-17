import { AppModalScaffold, ThemeConstants, TimeAgo, V2exReply } from 'shared'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@Component
export struct TopicDetailReplyDivider {
  @Link replyDisplayMenuShown: boolean
  @Prop replyCountText: string = ''
  @Prop replyDisplayMode: string = 'origin'
  @Prop replyDisplayModeText: string = '原版'
  onJumpToFloor?: () => void
  onLatest?: () => void
  onShowDisplayMenu?: () => void
  onDisplayModeChange?: (mode: string) => void

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(this.replyCountText)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ToolButton('楼层', false, () => {
          if (this.onJumpToFloor) {
            this.onJumpToFloor()
          }
        })
        this.DisplayModeButton()
        this.ToolButton('最新', false, () => {
          if (this.onLatest) {
            this.onLatest()
          }
        })
      }.alignItems(VerticalAlign.Center)
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_SM,
      right: ThemeConstants.SPACE_SM,
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_XS,
    })
  }

  @Builder ToolButton(label: string, active: boolean, action: () => void) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TINY)
      .fontColor(active ? Color.White : $r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(
        active ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'),
      )
      .onClick(action)
  }

  @Builder DisplayModeButton() {
    Text(this.replyDisplayModeText)
      .fontSize(ThemeConstants.FONT_SIZE_TINY)
      .fontColor(
        this.replyDisplayMode === 'origin' ? $r('sys.color.font_secondary') : Color.White,
      )
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(
        this.replyDisplayMode === 'origin'
          ? $r('sys.color.ohos_id_color_button_normal')
          : ThemeConstants.BRAND_PRIMARY,
      )
      .onClick(() => {
        if (this.onShowDisplayMenu) {
          this.onShowDisplayMenu()
        }
      })
      .bindMenu(this.replyDisplayMenuShown, this.DisplayModeMenu, {
        placement: Placement.BottomRight,
        aboutToDisappear: () => {
          this.replyDisplayMenuShown = false
        },
      })
  }

  @Builder DisplayModeMenu() {
    Menu() {
      this.DisplayModeMenuItem('楼中楼', 'thread')
      this.DisplayModeMenuItem('楼中楼(@)', 'threadWithMention')
      this.DisplayModeMenuItem('冗余楼中楼', 'threadRedundant')
      this.DisplayModeMenuItem('只看楼主', 'op')
      this.DisplayModeMenuItem('原版', 'origin')
    }
  }

  @Builder DisplayModeMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        this.replyDisplayMode === mode
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      if (this.onDisplayModeChange) {
        this.onDisplayModeChange(mode)
      }
    })
  }
}

@Component
export struct ReplyContextSheetContent {
  @BuilderParam content: () => void
  @Prop title: string = '回复上下文'
  closeAction?: () => void

  build() {
    AppModalScaffold({
      title: this.title,
      closeAction: () => {
        if (this.closeAction) {
          this.closeAction()
        }
      },
    }) {
      this.content()
    }
  }
}

@Component
export struct ReplyContextListItem {
  @Prop reply: V2exReply
  @Prop floor: number = 0
  @Prop label: string = ''
  @Prop selected: boolean = false
  @Prop snippet: string = ''
  @Prop bodyFontSize: number = ThemeConstants.FONT_SIZE_BODY
  @Prop bodyLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  onSelect?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.label)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(
            this.selected
              ? $r('sys.color.ohos_id_color_activated')
              : $r('sys.color.font_secondary'),
          )
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2,
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        Text(`#${this.floor}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.reply.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        TimeAgo({ timestamp: this.reply.created })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.snippet)
        .fontSize(this.bodyFontSize)
        .lineHeight(this.bodyLineHeight)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor(
      this.selected
        ? $r('sys.color.ohos_id_color_button_normal')
        : $r('sys.color.ohos_id_color_sub_background'),
    )
    .onClick(() => {
      if (this.onSelect) {
        this.onSelect()
      }
    })
  }
}
