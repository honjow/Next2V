import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'

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
  @Event onClear?: () => void

  build() {
    // Two visually distinct groups so the mode switch is never confused with a format action:
    // the left is the scrollable set of formatting buttons; the right is a segmented edit/preview
    // toggle (a single grouped control with a highlighted active segment).
    Row({ space: ThemeConstants.SPACE_SM }) {
      Scroll() {
        Row({ space: ThemeConstants.SPACE_XS }) {
          this.ToolButton('B', false, () => { this.fire(this.onBold) }, FontWeight.Bold)
          this.ToolButton('I', false, () => { this.fire(this.onItalic) }, FontWeight.Medium, FontStyle.Italic)
          this.ToolButton('`', false, () => { this.fire(this.onCode) })
          this.ToolButton('>', false, () => { this.fire(this.onQuote) })
          this.ToolButton('-', false, () => { this.fire(this.onList) })
          this.ToolButton('[]', false, () => { this.fire(this.onLink) })
          this.ToolButton(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_IMAGE, 'Image'), false, () => { this.fire(this.onImage) })
          this.ToolButton(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_CLEAR, 'Clear'), false, () => { this.fire(this.onClear) })
        }
        .height(32)
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      // Edit/preview segmented toggle. Gate the pair on `if (this.previewActive)` so the WHOLE pair
      // rebuilds when the mode flips: with two inline siblings each binding `.backgroundColor` to
      // this.previewActive, only the first re-evaluated reliably, so the active highlight could stick
      // (looked static). The if/else tears down and recreates both segments on every change.
      Row() {
        if (this.previewActive) {
          this.SegToggle(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_EDIT, 'Edit'), false, () => { this.fire(this.onEdit) })
          this.SegToggle(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_PREVIEW, 'Preview'), true, () => { this.fire(this.onPreview) })
        } else {
          this.SegToggle(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_EDIT, 'Edit'), true, () => { this.fire(this.onEdit) })
          this.SegToggle(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_PREVIEW, 'Preview'), false, () => { this.fire(this.onPreview) })
        }
      }
      .padding(2)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    }
    .width('100%')
    .height(32)
    .alignItems(VerticalAlign.Center)
  }

  // One segment of the edit/preview toggle. `active` is static within each if/else branch above, so
  // by-value passing is fine here — the branch swap (keyed on previewActive) recreates the segments.
  @Builder
  private SegToggle(label: string, active: boolean, action: () => void) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .textAlign(TextAlign.Center)
      .height(28)
      .constraintSize({ minWidth: 40 })
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .fontColor(active ? Color.White : $r('sys.color.font_secondary'))
      .backgroundColor(active ? ThemeConstants.BRAND_PRIMARY : Color.Transparent)
      .onClick(action)
  }

  @Builder
  private ToolButton(
    label: string,
    active: boolean,
    action: () => void,
    weight: FontWeight = FontWeight.Normal,
    style: FontStyle = FontStyle.Normal
  ) {
    Button(label)
      .type(ButtonType.Normal)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontWeight(weight)
      .fontStyle(style)
      .fontColor(active ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
      .height(30)
      .constraintSize({ minWidth: 30 })
      .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onClick(action)
  }

  private fire(action?: () => void): void {
    if (action) {
      action()
    }
  }
}
