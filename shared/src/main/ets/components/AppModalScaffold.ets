import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct AppModalScaffold {
  @BuilderParam content: () => void
  @Prop title: string = ''
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0
  @Prop compact: boolean = false
  @Prop includeKeyboardPadding: boolean = false
  closeAction?: () => void

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(this.compact ? ThemeConstants.FONT_SIZE_TITLE : ThemeConstants.FONT_SIZE_H3)
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
            Blank().height(this.bottomH + ThemeConstants.SPACE_MD + this.keyboardPadding())
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

  private keyboardPadding(): number {
    if (!this.includeKeyboardPadding) {
      return 0
    }
    return Math.max(0, this.keyboardH)
  }
}
