import { TabSegmentButtonV2, SegmentButtonV2Items, LengthMetrics } from '@kit.ArkUI'
import { ThemeConstants } from 'shared'

/**
 * `@ComponentV2` segmented control for the BlockedLists appbar tabs, hosting the V2-native
 * `TabSegmentButtonV2` (the tab-style successor of the V1 `SegmentButton`). It exposes only one-way
 * `@Param` inputs (the two tab labels + the externally-selected index) plus an `@Event` click callback.
 *
 * Why V2-native and not the old V1 `SegmentButton` adapter: V1 `SegmentButton` declares
 * `@Link selectedIndexes`, which a `@ComponentV2` parent cannot bind. `TabSegmentButtonV2` instead takes
 * a one-way `@Param selectedIndex` and emits `onItemClicked`, so it is a controlled component that needs
 * no V1 decorators anywhere on the boundary. Same pattern as `UserProfileActivityTabs`.
 *
 * Controlled-selection contract: the highlight is driven entirely by the incoming `selectedIndex`; a tap
 * routes out through `onTabClicked`, the parent updates its persisted selected tab, and the new value
 * flows back in as `selectedIndex`. This also restores the highlight from parent state when the
 * BlockedLists tab is recreated (its navigation destination re-appears while the persisted tab is 1) —
 * the old adapter needed an explicit `syncSelectedIndexes()` for this; here it falls out of the one-way
 * binding for free.
 */
@ComponentV2
export struct BlockedListsTabsSegment {
  @Param firstLabel: string = '';
  @Param secondLabel: string = '';
  @Param selectedIndex: number = 0;
  @Event onTabClicked?: (index: number) => void;
  // @ObservedV2 items whose @Trace text is updated in place on a label/locale change (replaces the old
  // @Watch('onLabelsChanged') rebuild). Held @Local so the SegmentButtonV2Items identity stays stable.
  @Local private tabItems: SegmentButtonV2Items = new SegmentButtonV2Items([{ text: '' }, { text: '' }]);

  aboutToAppear(): void {
    this.syncLabels()
  }

  @Monitor('firstLabel', 'secondLabel')
  onLabelsChanged(): void {
    this.syncLabels()
  }

  build() {
    Row() {
      TabSegmentButtonV2({
        items: this.tabItems,
        selectedIndex: this.clampIndex(this.selectedIndex),
        onItemClicked: (index: number) => {
          if (this.onTabClicked) {
            this.onTabClicked(index)
          }
        },
        // Preserve the V1 adapter's per-button padding {top:10,bottom:10,left:8,right:8}.
        itemPadding: {
          top: LengthMetrics.vp(10),
          bottom: LengthMetrics.vp(10),
          start: LengthMetrics.vp(8),
          end: LengthMetrics.vp(8),
        },
      })
        .width(ThemeConstants.COMPACT_SEGMENT_BUTTON_WIDTH)
        .constraintSize({
          minWidth: ThemeConstants.COMPACT_SEGMENT_BUTTON_WIDTH,
          maxWidth: ThemeConstants.COMPACT_SEGMENT_BUTTON_WIDTH,
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_SM)
  }

  private clampIndex(index: number): number {
    return index === 1 ? 1 : 0
  }

  private syncLabels(): void {
    this.tabItems[0].text = this.firstLabel
    this.tabItems[1].text = this.secondLabel
  }
}
