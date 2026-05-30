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
    Scroll() {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ToolButton(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_EDIT, 'Edit'), !this.previewActive, () => { this.fire(this.onEdit) })
        this.ToolButton(AppStrings.text(AppStrings.R_MARKDOWN_TOOLBAR_PREVIEW, 'Preview'), this.previewActive, () => { this.fire(this.onPreview) })
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
    .width('100%')
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
