import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct NodeTag {
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''

  build() {
    Text(this.nodeTitle || this.nodeName)
      .fontSize(11)
      .fontColor($r('sys.color.font_secondary'))
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: 2,
        bottom: 2
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
