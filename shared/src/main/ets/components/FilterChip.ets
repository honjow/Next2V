import { Chip, ChipSize } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

@ComponentV2
export struct FilterChip {
  @Param label: string = ''
  @Param labelResource: Resource = $r('app.string.app_name')
  @Param hasLabelResource: boolean = false
  @Param selected: boolean = false
  @Param fill: boolean = false
  private language: LanguageState = connectLanguageState()
  @Event action?: () => void

  build() {
    Row() {
      Chip({
        label: {
          text: this.displayLabel(),
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

  private displayLabel(): string {
    if (this.hasLabelResource && this.language.effectiveLocale.length >= 0) {
      return AppStrings.text(this.labelResource, this.label)
    }
    return this.label
  }
}
