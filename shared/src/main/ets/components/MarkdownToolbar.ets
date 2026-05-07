import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct MarkdownToolbar {
  @Prop previewActive: boolean = false

  onEdit?: () => void
  onPreview?: () => void
  onBold?: () => void
  onItalic?: () => void
  onCode?: () => void
  onQuote?: () => void
  onList?: () => void
  onLink?: () => void
  onImage?: () => void
  onClear?: () => void

  build() {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
      this.ToolButton('编辑', !this.previewActive, () => { this.fire(this.onEdit) })
      this.ToolButton('预览', this.previewActive, () => { this.fire(this.onPreview) })
      this.ToolButton('B', false, () => { this.fire(this.onBold) }, FontWeight.Bold)
      this.ToolButton('I', false, () => { this.fire(this.onItalic) }, FontWeight.Medium, FontStyle.Italic)
      this.ToolButton('</>', false, () => { this.fire(this.onCode) })
      this.ToolButton('>', false, () => { this.fire(this.onQuote) })
      this.ToolButton('-', false, () => { this.fire(this.onList) })
      this.ToolButton('链', false, () => { this.fire(this.onLink) })
      this.ToolButton('图', false, () => { this.fire(this.onImage) })
      this.ToolButton('清', false, () => { this.fire(this.onClear) })
    }
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
      .height(ThemeConstants.TOUCH_TARGET_SM)
      .constraintSize({ minWidth: 42 })
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      .borderRadius(ThemeConstants.RADIUS_MD)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      .onClick(action)
  }

  private fire(action?: () => void): void {
    if (action) {
      action()
    }
  }
}
