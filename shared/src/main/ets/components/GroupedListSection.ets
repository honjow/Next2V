import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct GroupedListSection {
  @BuilderParam content: () => void
  @Prop inset: number = ThemeConstants.LIST_SECTION_INSET
  @Prop radius: number = ThemeConstants.RADIUS_CARD

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(this.radius)
    .clip(true)
    .padding(this.inset)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
