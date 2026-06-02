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

      // Inlined (NOT a @Builder): a @Builder called with a primitive `active` argument is by-value
      // and does not re-render when the value changes, which froze the highlight. Reading
      // this.previewActive directly here makes both segments reactively reflect the current mode.
      Row() {
        Text(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_EDIT, 'Edit'))
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .textAlign(TextAlign.Center)
          .height(28)
          .constraintSize({ minWidth: 40 })
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .fontColor(this.previewActive ? $r('sys.color.font_secondary') : Color.White)
          .backgroundColor(this.previewActive ? Color.Transparent : ThemeConstants.BRAND_PRIMARY)
          .onClick(() => { this.fire(this.onEdit) })
        Text(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_PREVIEW, 'Preview'))
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .textAlign(TextAlign.Center)
          .height(28)
          .constraintSize({ minWidth: 40 })
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .fontColor(this.previewActive ? Color.White : $r('sys.color.font_secondary'))
          .backgroundColor(this.previewActive ? ThemeConstants.BRAND_PRIMARY : Color.Transparent)
          .onClick(() => { this.fire(this.onPreview) })
      }
      .padding(2)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    }
    .width('100%')
    .height(32)
    .alignItems(VerticalAlign.Center)
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
