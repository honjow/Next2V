import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit'

@ComponentV2
export struct AppModalScaffold {
  @BuilderParam content: () => void
  @Param title: ResourceStr = ''
  // Safe-area / keyboard metrics mirrored into AppStorageV2 by EntryAbility's
  // dual-write bridge. Reading these @Trace fields keeps padding reactive exactly
  // like the former @StorageProp(StorageKeys.*) reads did.
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param compact: boolean = false
  @Param includeKeyboardPadding: boolean = false
  @Param enableComponentSafeArea: boolean = true
  @Param contentBackgroundColor: ResourceColor = $r('sys.color.ohos_id_color_card_bg')
  @Event closeAction?: () => void
  scroller: Scroller = new Scroller();

  build() {
    HdsNavigation() {
      List({ space: ThemeConstants.SPACE_SM, scroller: this.scroller }) {
        this.content()

        ListItem() {
          Column() {
            Blank().height(this.layout.bottomAvoidHeight + ThemeConstants.SPACE_MD + this.keyboardPadding())
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
    return Math.max(0, this.layout.keyboardHeight)
  }
}
