import { ThemeConstants } from 'shared'

@Component
export struct MainTabIcon {
  @Prop title: string = '';
  @Prop idx: number = 0;
  @Prop currentIndex: number = 0;

  build() {
    Column() {
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
}
