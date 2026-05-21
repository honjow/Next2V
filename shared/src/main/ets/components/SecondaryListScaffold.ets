import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct SecondaryListScaffold {
  @BuilderParam content: () => void
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0
  scroller: Scroller = new Scroller()
  @Prop listSpace: number = ThemeConstants.SPACE_SM - 2
  @Prop horizontalPadding: number = ThemeConstants.SPACE_MD
  @Prop bottomPadding: number = ThemeConstants.SPACE_XL
  @Prop includeKeyboardPadding: boolean = false
  onReachEnd?: () => void
  onDidScroll?: (offset: number, state: ScrollState) => void

  build() {
    List({ space: this.listSpace, scroller: this.scroller }) {
      ListItem() {
        Column() {
          Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT)
        }
        .width('100%')
      }
      .clip(false)

      this.content()

      ListItem() {
        Column() {
          Blank().height(this.bottomH + this.bottomPadding + this.keyboardPadding())
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
    return Math.max(0, this.keyboardH)
  }
}
