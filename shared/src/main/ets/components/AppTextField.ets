import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct AppTextField {
  @Link text: string
  @Prop placeholder: string = ''
  @Prop inputType: InputType = InputType.Normal
  onTextChange?: (value: string) => void

  build() {
    TextInput({ placeholder: this.placeholder, text: this.text })
      .type(this.inputType)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_primary'))
      .placeholderColor($r('sys.color.font_secondary'))
      .height(44)
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
      .layoutWeight(1)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onChange((value: string) => {
        this.text = value
        if (this.onTextChange) {
          this.onTextChange(value)
        }
      })
  }
}
