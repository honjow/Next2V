import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct SecondaryFormScaffold {
  @BuilderParam content: () => void
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0
  @Prop horizontalPadding: number = ThemeConstants.SPACE_MD
  @Prop bottomPadding: number = ThemeConstants.SPACE_XL
  @Prop includeKeyboardPadding: boolean = false

  build() {
    Scroll() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT)
        this.content()
        Blank().height(this.bottomH + this.bottomPadding + this.keyboardPadding())
      }
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
  }

  private keyboardPadding(): number {
    if (!this.includeKeyboardPadding) {
      return 0
    }
    return Math.max(0, this.keyboardH)
  }
}
