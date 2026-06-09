import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct GroupedListSection {
  @BuilderParam content: () => void
  @Param inset: number = ThemeConstants.LIST_SECTION_INSET
  @Param radius: number = ThemeConstants.RADIUS_CARD

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(this.radius)
    .clip(true)
    .padding(this.inset)
    .backgroundColor($r('app.color.card_background'))
  }
}
