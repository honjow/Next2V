import { hdsMaterial, HdsTabs, HdsTabsController, HdsTabsFloatingStyle } from '@kit.UIDesignKit'

/**
 * Project-owned HDS Tabs mini button wrapper.
 *
 * Do not tune this from call sites to hide clipping. The wrapper owns the
 * non-clipping HdsTabs activity box because the upstream hds_button package
 * constrains the material surface inside its Row.size/padding composition.
 */
@ComponentV2
export struct HdsMiniBarButton {
  @Param barWidth: number = 50
  @Param barHeight: number = 50
  @Param activityPadding: number = 16
  @Param controller: HdsTabsController = new HdsTabsController()
  @Param maskColor: ResourceColor = Color.Transparent
  @Param materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.IMMERSIVE
  @Param materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE
  @Param barPosition: BarPosition = BarPosition.End
  @Param barOverlap: boolean = true
  @Event onButtonClick?: () => void

  @BuilderParam buttonContent: () => void = this.defaultButtonBuilder

  @Builder defaultButtonBuilder() {
    SymbolGlyph($r('sys.symbol.plus'))
      .fontSize(27)
      .fontColor([$r('sys.color.ohos_id_color_text_primary')])
  }

  private activityWidth(): number {
    return this.barWidth + this.activityPadding * 2
  }

  private activityHeight(): number {
    return this.barHeight + this.activityPadding * 2
  }

  build() {
    Stack() {
      HdsTabs({ controller: this.controller }) {
        TabContent()
          .tabBar(this.buttonContent())
      }
      .barWidth(this.barWidth)
      .barHeight(this.barHeight)
      .barOverlap(this.barOverlap)
      .barPosition(this.barPosition)
      .barFloatingStyle({
        gradientMask: {
          maskColor: this.maskColor,
        },
        // Center the material button vertically inside the non-clipping activity box.
        // The box is barHeight + activityPadding*2 tall, so equal top/bottom margins
        // (== activityPadding) center it. Callers only size the button; centering is the default.
        barBottomMargin: this.activityPadding,
        systemMaterialEffect: {
          materialType: this.materialType,
          materialLevel: this.materialLevel,
        },
      } as HdsTabsFloatingStyle)
      .onTabBarClick(() => {
        if (this.onButtonClick) {
          this.onButtonClick()
        }
      })
      .width(this.activityWidth())
      .height(this.activityHeight())
      .clip(false)
    }
    .width(this.activityWidth())
    .height(this.activityHeight())
    .clip(false)
  }
}
