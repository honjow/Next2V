import { Chip, ChipSize } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct FilterChip {
  @Param label: string = ''
  @Param selected: boolean = false
  @Param fill: boolean = false
  @Event action?: () => void

  build() {
    Row() {
      Chip({
        label: {
          text: this.label,
          fontSize: ThemeConstants.FONT_SIZE_TAG,
          fontColor: $r('sys.color.font_primary'),
          activatedFontColor: Color.White
        },
        activated: this.selected,
        size: ChipSize.SMALL,
        backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
        activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
        borderRadius: ThemeConstants.RADIUS_ROUND,
        allowClose: false
      })
    }
    .height(ThemeConstants.TOUCH_TARGET_SM)
    .layoutWeight(this.fill ? 1 : 0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.action) {
        this.action()
      }
    })
  }
}
