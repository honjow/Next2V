import { Chip, ChipSize } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct FilterChip {
  @Prop label: string = ''
  @Prop selected: boolean = false
  @Prop fill: boolean = false
  action?: () => void

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
