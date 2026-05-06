import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct AppModalScaffold {
  @BuilderParam content: () => void
  @Prop title: string = ''
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  closeAction?: () => void

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(ThemeConstants.ICON_SIZE_SM)
            .fontColor([$r('sys.color.font_primary')])
        }
        .width(40)
        .height(40)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(() => {
          if (this.closeAction) {
            this.closeAction()
          }
        })
      }
      .height(56)
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })

      List({ space: ThemeConstants.SPACE_SM }) {
        this.content()

        ListItem() {
          Column() {
            Blank().height(this.bottomH + ThemeConstants.SPACE_MD)
          }
          .width('100%')
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
