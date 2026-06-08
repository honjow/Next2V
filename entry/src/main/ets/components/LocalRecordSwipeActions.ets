import { ThemeConstants } from 'shared'

/**
 * Generic swipe-to-end delete button for the local-record list pages (read-later, followed nodes,
 * recently viewed). Mirrors NotificationDeleteSwipeAction's red trash button; it carries no row
 * identity — the host page wires onDelete to its own per-row remove handler, so this stays a dumb
 * trigger and works for both topic-id and node-name keyed lists.
 */
@ComponentV2
export struct LocalRecordDeleteSwipeAction {
  @Event onDelete?: () => void

  build() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(ThemeConstants.ICON_SIZE_SM)
          .fontColor([Color.White])
      }
      .width(48)
      .height(40)
      .backgroundColor(Color.Red)
      .onClick(() => {
        if (this.onDelete) {
          this.onDelete()
        }
      })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }
}
