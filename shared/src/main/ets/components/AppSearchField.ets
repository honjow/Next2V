import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct AppSearchField {
  // V2 two-way replacement for the former @Link text (see AppTextField for the pattern).
  @Param text: string = ''
  @Local fieldText: string = ''
  @Param placeholder: ResourceStr = ''
  @Event onTextChange?: (value: string) => void
  @Event onSubmit?: (value: string) => void

  aboutToAppear(): void {
    this.fieldText = this.text
  }

  @Monitor('text')
  onExternalTextChange(): void {
    if (this.text !== this.fieldText) {
      this.fieldText = this.text
    }
  }

  build() {
    Search({ value: this.fieldText, placeholder: this.placeholder })
      .height(40)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .onChange((value: string) => {
        this.fieldText = value
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
