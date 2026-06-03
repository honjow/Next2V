import { ThemeConstants } from '../theme/ThemeConstants'
import { LengthMetrics, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI'

@ComponentV2
export struct MarkdownToolbar {
  @Param previewActive: boolean = false

  @Event onEdit?: () => void
  @Event onPreview?: () => void
  @Event onBold?: () => void
  @Event onItalic?: () => void
  @Event onCode?: () => void
  @Event onQuote?: () => void
  @Event onList?: () => void
  @Event onLink?: () => void
  @Event onImage?: () => void

  // Edit (pencil) / Preview (eye) icons for the system segmented toggle.
  private segItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { symbol: $r('sys.symbol.square_and_pencil') },
    { symbol: $r('sys.symbol.eye') },
  ])
  // Two-way binding to TabSegmentButtonV2 so the component owns (and animates) the switch; kept in
  // sync with the parent's previewActive both ways.
  @Local private segIndex: number = 0

  @Monitor('previewActive')
  onPreviewActiveChange(): void {
    this.segIndex = this.previewActive ? 1 : 0
  }

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Scroll() {
        Row({ space: ThemeConstants.SPACE_XS }) {
          this.IconButton($r('sys.symbol.bold'), () => { this.fire(this.onBold) })
          this.IconButton($r('sys.symbol.italic'), () => { this.fire(this.onItalic) })
          this.IconButton($r('sys.symbol.doc_plaintext'), () => { this.fire(this.onCode) })
          this.IconButton($r('sys.symbol.quote'), () => { this.fire(this.onQuote) })
          this.IconButton($r('sys.symbol.list_bullet'), () => { this.fire(this.onList) })
          this.IconButton($r('sys.symbol.link'), () => { this.fire(this.onLink) })
          this.IconButton($r('sys.symbol.picture'), () => { this.fire(this.onImage) })
        }
        .height(32)
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      // TabSegmentButtonV2 is tab-style (fills its parent) and rejects universal attributes like
      // .width(), so bound it with a fixed-width wrapper — otherwise it eats the whole row and the
      // format icons get squeezed to zero.
      Row() {
        TabSegmentButtonV2({
          items: this.segItems,
          selectedIndex: this.segIndex!!,
          onItemClicked: (index: number) => {
            if (index === 0) {
              this.fire(this.onEdit)
            } else {
              this.fire(this.onPreview)
            }
          },
          itemSymbolFontSize: LengthMetrics.fp(ThemeConstants.FONT_SIZE_TITLE),
          itemMinHeight: LengthMetrics.vp(22),
          buttonMinHeight: LengthMetrics.vp(28),
        })
      }
      .width(104)
    }
    .width('100%')
    .height(32)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private IconButton(icon: Resource, action: () => void) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_secondary')])
    }
    .type(ButtonType.Normal)
    .height(30)
    .constraintSize({ minWidth: 36 })
    .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    // Don't grab focus when tapped: the editor TextArea must keep focus (and its caret) so an insert
    // lands at the cursor and the soft keyboard stays up.
    .focusOnTouch(false)
    .onClick(action)
  }

  private fire(action?: () => void): void {
    if (action) {
      action()
    }
  }
}
