import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct EmptyState {
  @Param message: string = ''
  @Param stateHeight: number = 240

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(this.stateHeight)
  }
}
