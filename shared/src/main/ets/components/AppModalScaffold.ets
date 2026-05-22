import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit'

@Component
export struct AppModalScaffold {
  @BuilderParam content: () => void
  @Prop title: string = ''
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0
  @Prop compact: boolean = false
  @Prop includeKeyboardPadding: boolean = false
  @Prop enableComponentSafeArea: boolean = true
  @Prop contentBackgroundColor: ResourceColor = $r('sys.color.ohos_id_color_card_bg')
  closeAction?: () => void
  scroller: Scroller = new Scroller();

  build() {
    HdsNavigation() {
      List({ space: ThemeConstants.SPACE_SM, scroller: this.scroller }) {
        this.content()

        ListItem() {
          Column() {
            Blank().height(this.bottomH + ThemeConstants.SPACE_MD + this.keyboardPadding())
          }
          .width('100%')
        }
      }
      .height('100%')
      .layoutWeight(1)
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .titleBar({
      enableComponentSafeArea: this.enableComponentSafeArea,
      content: {
        title: {
          mainTitle: this.title
        },
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.xmark'),
              type: IconStyleMode.SMALL,
              action: () => {
                if (this.closeAction) {
                  this.closeAction()
                }
              },
            }
          }]
        },
      },
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .bindToScrollable([this.scroller])
    .width('100%')
    .height('100%')
    .backgroundColor(this.contentBackgroundColor)
  }

  private keyboardPadding(): number {
    if (!this.includeKeyboardPadding) {
      return 0
    }
    return Math.max(0, this.keyboardH)
  }
}
