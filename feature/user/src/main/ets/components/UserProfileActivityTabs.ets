import { TabSegmentButtonV2, SegmentButtonV2Items, LengthMetrics } from '@kit.ArkUI'
import { ThemeConstants } from 'shared'

/**
 * `@ComponentV2` segmented control for UserProfilePage's topic / reply activity tabs, hosting the
 * V2-native `TabSegmentButtonV2` (the tab-style successor of the V1 `SegmentButton`). It exposes a
 * one-way `@Param` label pair + the externally-selected index, plus an `@Event` click callback.
 *
 * Why V2-native and not the old V1 `SegmentButton` adapter: V1 `SegmentButton` declares
 * `@Link selectedIndexes`, which a `@ComponentV2` parent cannot bind. `TabSegmentButtonV2` takes a
 * one-way `@Param selectedIndex` and emits `onItemClicked`, so it is a controlled component needing no
 * V1 decorators on the boundary. The selected tab is page-state in `UserProfilePage` (driven off
 * `onTabClicked`) and flows back in here as `selectedIndex` to drive the highlight — preserving the
 * exact look and behaviour without swapping the visual to a different component.
 */
@ComponentV2
export struct UserProfileActivityTabs {
  @Param topicLabel: string = '';
  @Param replyLabel: string = '';
  @Param selectedIndex: number = 0;
  @Event onTabClicked?: (index: number) => void;
  // @ObservedV2 items whose @Trace text is updated in place on a label/count change (replaces the old
  // @Watch('onLabelsChanged') rebuild). Held @Local so the SegmentButtonV2Items identity stays stable.
  @Local private tabItems: SegmentButtonV2Items = new SegmentButtonV2Items([{ text: '' }, { text: '' }]);

  aboutToAppear(): void {
    this.syncLabels()
  }

  @Monitor('topicLabel', 'replyLabel')
  onLabelsChanged(): void {
    this.syncLabels()
  }

  build() {
    Row() {
      TabSegmentButtonV2({
        items: this.tabItems,
        selectedIndex: this.selectedIndex,
        // Re-enable the sliding selection-highlight animation. `enableStateAnimation` is a
        // TabSegmentButtonV2 @Param @since 24; the SDK/API 24 upgrade exposes it (API 23 rejected
        // it at compile time), restoring the animated tab switch the old V1 SegmentButton had.
        enableStateAnimation: true,
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
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_SM)
  }

  private syncLabels(): void {
    this.tabItems[0].text = this.topicLabel
    this.tabItems[1].text = this.replyLabel
  }
}
