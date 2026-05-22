import { ThemeConstants } from '../theme/ThemeConstants'

/**
 * 列表底部加载状态指示器
 */
@Component
export struct LoadingFooter {
  @Prop isLoading: boolean = false
  @Prop hasMore: boolean = true
  @Prop isError: boolean = false
  @Prop errorMessage: string = '加载失败，点击重试'
  @Prop retryLabel: string = ''
  onRetry?: () => void

  build() {
    Row() {
      if (this.isLoading) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE_SMALL)
          .height(ThemeConstants.LOADING_SIZE_SMALL)
          .color($r('sys.color.font_secondary'))
        Text('加载中…')
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
