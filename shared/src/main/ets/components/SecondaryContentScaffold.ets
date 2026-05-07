import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct SecondaryContentScaffold {
  @BuilderParam content: () => void
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0
  @Prop bottomPadding: number = 0
  @Prop includeKeyboardPadding: boolean = false

  build() {
    Column() {
      Blank()
        .height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT)

      this.content()

      Blank()
        .height(this.bottomH + this.bottomPadding + this.keyboardPadding())
    }
    .width('100%')
    .height('100%')
    .clip(false)
  }

  private keyboardPadding(): number {
    if (!this.includeKeyboardPadding) {
      return 0
    }
    return Math.max(0, this.keyboardH)
  }
}
