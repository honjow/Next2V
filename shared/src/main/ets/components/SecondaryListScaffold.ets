import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'

@ComponentV2
export struct SecondaryListScaffold {
  @BuilderParam content: () => void
  // Safe-area / keyboard metrics are published into AppStorageV2 by EntryAbility.
  // Reading these @Trace fields keeps padding reactive exactly like the former
  // @StorageProp(StorageKeys.*) reads did.
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  // @Param (not a plain member) because parents pass their own Scroller in by reference.
  @Param scroller: Scroller = new Scroller()
  @Param listSpace: number = ThemeConstants.SPACE_SM - 2
  @Param horizontalPadding: number = ThemeConstants.SPACE_MD
  @Param bottomPadding: number = ThemeConstants.SPACE_XL
  @Param includeKeyboardPadding: boolean = false
  @Event onReachEnd?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

  build() {
    List({ space: this.listSpace, scroller: this.scroller }) {
      ListItem() {
        Column() {
          Blank().height(this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT)
        }
        .width('100%')
      }
      .clip(false)

      this.content()

      ListItem() {
        Column() {
          Blank().height(this.layout.bottomAvoidHeight + this.bottomPadding + this.keyboardPadding())
        }
        .width('100%')
      }
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    .clip(false)
    .edgeEffect(EdgeEffect.None)
    .onDidScroll((_scrollOffset: number, scrollState: ScrollState) => {
      if (this.onDidScroll) {
        this.onDidScroll(this.scroller.currentOffset().yOffset, scrollState)
      }
    })
    .onScrollIndex((_start: number, _end: number, _center: number) => {
      if (this.onDidScroll) {
        this.onDidScroll(this.scroller.currentOffset().yOffset, ScrollState.Scroll)
      }
    })
    .onReachEnd(() => {
      if (this.onReachEnd) {
        this.onReachEnd()
      }
    })
  }

  private keyboardPadding(): number {
    if (!this.includeKeyboardPadding) {
      return 0
    }
    return Math.max(0, this.layout.keyboardHeight)
  }
}
