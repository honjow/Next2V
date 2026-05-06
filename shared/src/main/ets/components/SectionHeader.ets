import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct SectionHeader {
  @Prop title: string = ''

  build() {
    Text(this.title)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS
      })
      .width('100%')
  }
}
