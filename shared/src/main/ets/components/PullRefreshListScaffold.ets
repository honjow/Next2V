import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'
import { PullRefresh } from './PullRefresh'

@Component
export struct PullRefreshListScaffold {
  @BuilderParam content: () => void
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  scroller: Scroller = new Scroller()
  @Prop listSpace: number = ThemeConstants.SPACE_SM - 2
  @Prop horizontalPadding: number = ThemeConstants.SPACE_MD
  @Prop topPadding: number = 0
  @Prop bottomPadding: number = ThemeConstants.SPACE_XL
  @Prop indicatorTop: number = -1
  @Prop refreshThreshold: number = 40
  @Prop scrollEnabled: boolean = true
  onRefresh?: () => Promise<void>
  onBottomRefresh?: () => Promise<void>
  canStartBottomRefresh?: () => boolean
  onReachEnd?: () => void
  onScrollIndex?: (start: number, end: number, center: number) => void
  onDidScroll?: (offset: number, state: ScrollState) => void
  onScrollEnableChange?: (enabled: boolean) => void

  build() {
    PullRefresh({
      scroller: this.scroller,
      indicatorTop: this.resolvedIndicatorTop(),
      threshold: this.refreshThreshold,
      bottomIndicatorBottom: this.bottomH + this.bottomPadding,
      onRefresh: async () => {
        if (this.onRefresh) {
          await this.onRefresh()
        }
      },
      onBottomRefresh: async () => {
        if (this.onBottomRefresh) {
          await this.onBottomRefresh()
        }
      },
      canStartBottomRefresh: () => {
        if (this.canStartBottomRefresh) {
          return this.canStartBottomRefresh()
        }
        return false
      },
      onScrollEnableChange: (enabled: boolean) => {
        if (this.onScrollEnableChange) {
          this.onScrollEnableChange(enabled)
        }
      }
    }) {
      List({ space: this.listSpace, scroller: this.scroller }) {
        ListItem() {
          Column() {
            Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT + this.topPadding)
          }
          .width('100%')
        }
        .clip(false)

        this.content()

        ListItem() {
          Column() {
            Blank().height(this.bottomH + this.bottomPadding)
          }
          .width('100%')
        }
      }
      .enableScrollInteraction(this.scrollEnabled)
      .onScroll((_scrollOffset: number, scrollState: ScrollState) => {
        if (this.onDidScroll) {
          this.onDidScroll(this.scroller.currentOffset().yOffset, scrollState)
        }
      })
      .onScrollIndex((start: number, end: number, center: number) => {
        if (this.onScrollIndex) {
          this.onScrollIndex(start, end, center)
        }
        if (this.onDidScroll) {
          this.onDidScroll(this.scroller.currentOffset().yOffset, ScrollState.Scroll)
        }
      })
      .onReachEnd(() => {
        if (this.onReachEnd) {
          this.onReachEnd()
        }
      })
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      .clip(false)
      .edgeEffect(EdgeEffect.None)
    }
  }

  private resolvedIndicatorTop(): number {
    if (this.indicatorTop >= 0) {
      return this.indicatorTop
    }
    return this.topH + ThemeConstants.TITLE_BAR_HEIGHT / 2 + this.topPadding
  }
}
