import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

/**
 * List footer loading state indicator.
 */
@ComponentV2
export struct LoadingFooter {
  @Param isLoading: boolean = false
  @Param hasMore: boolean = true
  @Param isError: boolean = false
  @Param errorMessage: ResourceStr = $r('app.string.common_load_failed_tap_retry')
  @Param retryLabel: ResourceStr = ''
  @Event onRetry?: () => void
  private language: LanguageState = connectLanguageState()

  build() {
    Row() {
      if (this.isLoading) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE_SMALL)
          .height(ThemeConstants.LOADING_SIZE_SMALL)
          .color($r('sys.color.font_secondary'))
        Text(this.localeAwareText($r('app.string.common_loading'), 'Loading\u2026'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ left: ThemeConstants.SPACE_SM })
      } else if (this.isError) {
        Text(this.localeAwareResource(this.errorMessage))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        if (this.retryLabel) {
          Button(this.localeAwareResource(this.retryLabel))
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .height(30)
            .margin({ left: ThemeConstants.SPACE_MD })
            .onClick(() => {
              if (this.onRetry) {
                this.onRetry()
              }
            })
        }
      } else if (!this.hasMore) {
        Text($r('app.string.common_no_more'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(ThemeConstants.FOOTER_HEIGHT)
    .onClick(() => {
      if (this.isError && this.onRetry) {
        this.onRetry()
      }
    })
  }

  private localeAwareResource(resource: ResourceStr): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return resource
    }
    return resource
  }

  private localeAwareText(resource: Resource, fallback: string): string {
    if (this.language.effectiveLocale.length >= 0) {
      return AppStrings.text(resource, fallback)
    }
    return AppStrings.text(resource, fallback)
  }
}
