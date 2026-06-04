import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { LengthMetrics, SegmentButtonV2Items, SymbolGlyphModifier, TabSegmentButtonV2 } from '@kit.ArkUI'

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
  // The image button opens a menu (anchored on the button itself) instead of one flat action: upload a
  // new image to the configured image host, or insert a bare image-link skeleton.
  @Event onImageUpload?: () => void
  @Event onInsertImageLink?: () => void

  // Edit (pencil) / Preview (eye) icons for the system segmented toggle.
  private segItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { symbol: $r('sys.symbol.square_and_pencil') },
    { symbol: $r('sys.symbol.eye') },
  ])
  // Two-way binding to TabSegmentButtonV2 so the component owns (and animates) the switch; kept in
  // sync with the parent's previewActive both ways.
  @Local private segIndex: number = 0

  // Image-source menu (anchored on the picture button). Controlled visibility + reusable glyph
  // modifiers mirror the project's bindMenu convention (see ReplyCardActions / SettingsPage dropdowns).
  @Local private imageMenuShown: boolean = false
  @Local private uploadImageIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.cloud_and_arrow_up'))
  @Local private insertLinkIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.link'))

  // Mirror the parent's previewActive back into segIndex ONLY when they actually differ. On a tap the
  // component already moves segIndex via the two-way binding (and starts the slide animation); the
  // subsequent previewActive change would otherwise re-assign the same value here and reset the running
  // animation to its end state. The guard keeps this purely for external resets (e.g. aboutToAppear
  // forcing edit mode), where segIndex still needs to follow.
  @Monitor('previewActive')
  onPreviewActiveChange(): void {
    const target: number = this.previewActive ? 1 : 0
    if (this.segIndex !== target) {
      this.segIndex = target
    }
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
          this.ImageButton()
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
          // The sliding selection animation is opt-in via enableStateAnimation (API 24+); without it the
          // pill jumps. Two-way selectedIndex alone only keeps the selection in sync, it doesn't animate.
          enableStateAnimation: true,
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

  // Same chrome as IconButton, but the tap opens a menu hung directly on the button (so it pops from the
  // image icon) rather than firing a single action.
  @Builder
  private ImageButton() {
    Button() {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_secondary')])
    }
    .type(ButtonType.Normal)
    .height(30)
    .constraintSize({ minWidth: 36 })
    .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    .focusOnTouch(false)
    .onClick(() => { this.showImageMenu() })
    .bindMenu(this.imageMenuShown, this.ImageMenu, {
      placement: Placement.BottomLeft,
      aboutToDisappear: () => { this.imageMenuShown = false },
    })
  }

  @Builder
  ImageMenu() {
    Menu() {
      MenuItem({ content: AppStrings.R_IMAGE_UPLOAD_ACTION_NEW, symbolStartIcon: this.uploadImageIcon })
        .onClick(() => { this.runImageAction(this.onImageUpload) })
      MenuItem({ content: AppStrings.R_IMAGE_UPLOAD_ACTION_LINK, symbolStartIcon: this.insertLinkIcon })
        .onClick(() => { this.runImageAction(this.onInsertImageLink) })
    }
  }

  // Reset-then-open so the controlled menu re-opens reliably on every tap (matches the project's
  // show*Menu() convention); run the chosen action after the menu has dismissed.
  private showImageMenu(): void {
    this.imageMenuShown = false
    setTimeout(() => { this.imageMenuShown = true }, 20)
  }

  private runImageAction(action?: () => void): void {
    this.imageMenuShown = false
    if (action) {
      setTimeout(() => { action() }, 80)
    }
  }

  private fire(action?: () => void): void {
    if (action) {
      action()
    }
  }
}
