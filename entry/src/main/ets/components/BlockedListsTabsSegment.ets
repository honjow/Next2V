import { SegmentButton, SegmentButtonOptions } from '@kit.ArkUI'
import { ThemeConstants } from 'shared'

/**
 * V1 @Component adapter that hosts the framework `SegmentButton` for the BlockedLists appbar tabs.
 *
 * Why this stays V1 while its parent (`BlockedListsTabs`) is `@ComponentV2`: `SegmentButton` declares
 * `@Link selectedIndexes: number[]`, and ArkUI forbids a `@ComponentV2` parent from binding any V1
 * `@Link` member ("A V2 component cannot be used with any member property decorated by '@Link' in a V1
 * component"). So the mandatory two-way `selectedIndexes` binding must live entirely inside a V1
 * component. This adapter owns that binding internally and exposes only one-way `@Prop` inputs (the two
 * tab labels + the externally-selected index) plus a plain click callback — all legal across the
 * V2-parent -> V1-child boundary — preserving the exact SegmentButton look/behaviour without swapping to
 * a different component. Same boundary pattern as `UserProfileActivityTabs`.
 *
 * Unlike that sibling, this adapter also syncs its highlight from `selectedIndex`: the BlockedLists tab
 * is recreated when its navigation destination re-appears while the persisted tab is 1, so the highlight
 * must be restored from the parent state rather than always starting at 0.
 */
@Component
export struct BlockedListsTabsSegment {
  @Prop @Watch('onLabelsChanged') firstLabel: string = '';
  @Prop @Watch('onLabelsChanged') secondLabel: string = '';
  @Prop @Watch('onSelectedIndexChanged') selectedIndex: number = 0;
  onTabClicked?: (index: number) => void;
  @State private selectedIndexes: number[] = [0];
  @State private tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '' }, { text: '' }],
    buttonPadding: { top: 10, bottom: 10, left: 8, right: 8 },
  });

  aboutToAppear(): void {
    this.rebuildOptions()
    this.syncSelectedIndexes()
  }

  build() {
    Row() {
      SegmentButton({
        options: this.tabOptions,
        selectedIndexes: $selectedIndexes,
        onItemClicked: (index: number) => {
          if (this.onTabClicked) {
            this.onTabClicked(index)
          }
        },
      })
        .constraintSize({ maxWidth: 448 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_SM)
  }

  private onLabelsChanged(_propName: string): void {
    this.rebuildOptions()
  }

  private onSelectedIndexChanged(_propName: string): void {
    this.syncSelectedIndexes()
  }

  private rebuildOptions(): void {
    this.tabOptions = SegmentButtonOptions.tab({
      buttons: [
        { text: this.firstLabel },
        { text: this.secondLabel },
      ],
      buttonPadding: { top: 10, bottom: 10, left: 8, right: 8 },
    })
  }

  private syncSelectedIndexes(): void {
    this.selectedIndexes = [this.selectedIndex === 1 ? 1 : 0]
  }
}
