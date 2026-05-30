import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

/**
 * List footer loading state indicator.
 */
@ComponentV2
export struct LoadingFooter {
  @Param isLoading: boolean = false
  @Param hasMore: boolean = true
  @Param isError: boolean = false
  @Param errorMessage: string = AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed, tap to retry')
  @Param retryLabel: string = ''
  @Event onRetry?: () => void

  build() {
    Row() {
      if (this.isLoading) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE_SMALL)
          .height(ThemeConstants.LOADING_SIZE_SMALL)
          .color($r('sys.color.font_secondary'))
        Text(AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading\u2026'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ left: ThemeConstants.SPACE_SM })
      } else if (this.isError) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        if (this.retryLabel) {
          Button(this.retryLabel)
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
}
