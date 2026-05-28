import { hdsMaterial, HdsTabs, HdsTabsController, HdsTabsFloatingStyle } from '@kit.UIDesignKit'

/**
 * Project-owned HDS Tabs mini button wrapper.
 *
 * Do not tune this from call sites to hide clipping. The wrapper owns the
 * non-clipping HdsTabs activity box because the upstream hds_button package
 * constrains the material surface inside its Row.size/padding composition.
 */
@Component
export struct HdsMiniBarButton {
  @Prop barWidth: number = 50
  @Prop barHeight: number = 50
  @Prop activityPadding: number = 16
  controller: HdsTabsController = new HdsTabsController()
  @Prop maskColor: ResourceColor = Color.Transparent
  @Prop barBottomMargin: number = 8
  @Prop materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.IMMERSIVE
  @Prop materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE
  @Prop barPosition: BarPosition = BarPosition.End
  @Prop barOverlap: boolean = true
  onButtonClick?: () => void

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
        barBottomMargin: this.barBottomMargin,
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
