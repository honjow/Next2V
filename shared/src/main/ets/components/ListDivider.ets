import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct ListDivider {
  @Param inset: number = ThemeConstants.SPACE_LG

  build() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.ohos_id_color_list_separator'))
      .margin({ left: this.inset, right: this.inset/2 })
  }
}
