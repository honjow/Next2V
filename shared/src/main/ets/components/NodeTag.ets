import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct NodeTag {
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''

  build() {
    Text(this.nodeTitle || this.nodeName)
      .fontSize(11)
      .fontColor('#A0C0D8')
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: 2,
        bottom: 2
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor('#1E3040')
  }
}
