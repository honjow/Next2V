import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'

@ComponentV2
export struct SecondaryFormScaffold {
  @BuilderParam content: () => void
  // Safe-area / keyboard metrics are published into AppStorageV2 by EntryAbility.
  // Reading these @Trace fields keeps padding reactive exactly like the former
  // @StorageProp(StorageKeys.*) reads did.
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param horizontalPadding: number = ThemeConstants.SPACE_MD
  @Param bottomPadding: number = ThemeConstants.SPACE_XL
  @Param includeKeyboardPadding: boolean = false

  build() {
    Scroll() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Blank().height(this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT)
        this.content()
        Blank().height(this.layout.bottomAvoidHeight + this.bottomPadding + this.keyboardPadding())
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
    return Math.max(0, this.layout.keyboardHeight)
  }
}
