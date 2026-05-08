import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct AppSearchField {
  @Link text: string
  @Prop placeholder: string = ''
  onTextChange?: (value: string) => void
  onSubmit?: (value: string) => void

  build() {
    Search({ value: this.text, placeholder: this.placeholder })
      .height(40)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .onChange((value: string) => {
        this.text = value
        if (this.onTextChange) {
          this.onTextChange(value)
        }
      })
      .onSubmit((value: string) => {
        if (this.onSubmit) {
          this.onSubmit(value)
        }
      })
  }
}
