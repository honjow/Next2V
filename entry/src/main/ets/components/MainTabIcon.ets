import { ThemeConstants } from 'shared'

@Component
export struct MainTabIcon {
  @Prop title: string = '';
  @Prop idx: number = 0;
  @Prop currentIndex: number = 0;
  @Prop badgeCount: number = 0;

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        SymbolGlyph(
          this.idx === 0
            ? $r('sys.symbol.house_fill')
            : this.idx === 1
              ? $r('sys.symbol.square_fill_grid_2x2')
              : this.idx === 2
                ? $r('sys.symbol.bell_fill')
                : $r('sys.symbol.person_fill'),
        )
          .fontSize(ThemeConstants.INDICATOR_SIZE - 6)
          .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
          .fontColor([
            this.currentIndex === this.idx
              ? $r('sys.color.ohos_id_color_activated')
              : $r('sys.color.font_secondary'),
          ])
        if (this.badgeCount > 0) {
          Text(this.badgeText())
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .height(16)
            .constraintSize({ minWidth: 16 })
            .padding({ left: 4, right: 4 })
            .textAlign(TextAlign.Center)
            .borderRadius(8)
            .backgroundColor(Color.Red)
            .translate({ x: 8, y: -5 })
        }
      }
      .width(ThemeConstants.INDICATOR_SIZE)
      .height(ThemeConstants.INDICATOR_SIZE - 2)
      Text(this.title)
        .fontSize(ThemeConstants.FONT_SIZE_TINY)
        .fontColor(
          this.currentIndex === this.idx
            ? $r('sys.color.ohos_id_color_activated')
            : $r('sys.color.font_secondary'),
        )
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: ThemeConstants.SPACE_SM - 2, bottom: ThemeConstants.SPACE_XS })
  }

  private badgeText(): string {
    return this.badgeCount > 99 ? '99+' : `${this.badgeCount}`
  }
}
