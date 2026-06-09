import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

@ComponentV2
export struct SectionHeader {
  @Param title: ResourceStr = ''
  private language: LanguageState = connectLanguageState()

  build() {
    Text(this.localeAwareTitle())
      .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS,
      })
      .width('100%')
  }

  private localeAwareTitle(): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return this.title
    }
    return this.title
  }
}
