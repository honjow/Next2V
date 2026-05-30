import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct AppActionButton {
  @Param label: ResourceStr = ''
  @Param primary: boolean = false
  @Param isEnabled: boolean = true
  @Event action?: () => void

  build() {
    Button(this.label, { type: ButtonType.Capsule })
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontWeight(FontWeight.Medium)
      .height(44)
      .width('100%')
      .enabled(this.isEnabled)
      .buttonStyle(this.primary ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL)
      .onClick(() => {
        if (this.isEnabled && this.action) {
          this.action()
        }
      })
  }
}
