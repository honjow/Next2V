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
  @Prop bottomPadding: number = ThemeConstants.SPACE_XL
  @Prop refreshThreshold: number = 40
  @Prop scrollEnabled: boolean = true
  onRefresh?: () => Promise<void>
  onReachEnd?: () => void
  onScrollIndex?: (start: number, end: number, center: number) => void
  onScrollEnableChange?: (enabled: boolean) => void

  build() {
    PullRefresh({
      scroller: this.scroller,
      indicatorTop: this.topH + ThemeConstants.TITLE_BAR_HEIGHT / 2,
      threshold: this.refreshThreshold,
      onRefresh: async () => {
        if (this.onRefresh) {
          await this.onRefresh()
        }
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
            Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT)
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
      .onScrollIndex((start: number, end: number, center: number) => {
        if (this.onScrollIndex) {
          this.onScrollIndex(start, end, center)
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
}
