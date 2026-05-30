import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct NodeTag {
  @Param nodeName: string = ''
  @Param nodeTitle: string = ''

  build() {
    Text(this.nodeTitle || this.nodeName)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor($r('sys.color.font_secondary'))
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS / 2,
        bottom: ThemeConstants.SPACE_XS / 2
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
