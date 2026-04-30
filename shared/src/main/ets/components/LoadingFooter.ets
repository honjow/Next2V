import { ThemeConstants } from '../theme/ThemeConstants'

/**
 * 列表底部加载状态指示器
 */
@Component
export struct LoadingFooter {
  @Prop isLoading: boolean = false
  @Prop hasMore: boolean = true

  build() {
    Row() {
      if (this.isLoading) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE_SMALL)
          .height(ThemeConstants.LOADING_SIZE_SMALL)
          .color($r('sys.color.font_secondary'))
        Text('加载中...')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ left: ThemeConstants.SPACE_SM })
      } else if (!this.hasMore) {
        Text('— 没有更多了 —')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(ThemeConstants.FOOTER_HEIGHT)
  }
}
