import { ThemeConstants } from '../theme/ThemeConstants'
import { SecondaryListScaffold } from './SecondaryListScaffold'

@ComponentV2
export struct V2exWebViewScaffold {
  @BuilderParam content: () => void
  @Param isStatusVisible: boolean = false
  @Param isStatusError: boolean = false
  @Param statusText: string = ''
  @Param statusMaxLines: number = 1

  build() {
    Column() {
      Column() {
        SecondaryListScaffold({ horizontalPadding: 0, bottomPadding: 0, listSpace: 0 }) {
          this.content()
        }
      }
      .width('100%')
      .layoutWeight(1)

      this.StatusBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  StatusBar() {
    if (this.isStatusVisible) {
      Row() {
        Text(this.statusText)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(this.isStatusError ? Color.Red : $r('sys.color.font_secondary'))
          .maxLines(this.statusMaxLines)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_MD,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS
      })
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    }
  }
}
