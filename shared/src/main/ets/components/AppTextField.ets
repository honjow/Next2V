import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct AppTextField {
  // V2 two-way replacement for the former @Link text: the parent owns the value
  // (passes it as @Param and updates it from @Event onTextChange). A @Local working
  // copy drives the TextInput so per-keystroke edits stay child-local (no parent
  // round-trip cursor jump); @Monitor propagates external resets (e.g. clear-after-submit).
  @Param text: string = ''
  @Local fieldText: string = ''
  @Param placeholder: ResourceStr = ''
  @Param inputType: InputType = InputType.Normal
  @Event onTextChange?: (value: string) => void

  aboutToAppear(): void {
    this.fieldText = this.text
  }

  @Monitor('text')
  onExternalTextChange(): void {
    // Only react to genuine external resets (parent set text to something the field
    // is not already showing), not to the echo of the user's own keystroke.
    if (this.text !== this.fieldText) {
      this.fieldText = this.text
    }
  }

  build() {
    TextInput({ placeholder: this.placeholder, text: this.fieldText })
      .type(this.inputType)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_primary'))
      .placeholderColor($r('sys.color.font_secondary'))
      .height(44)
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onChange((value: string) => {
        this.fieldText = value
        if (this.onTextChange) {
          this.onTextChange(value)
        }
      })
  }
}
