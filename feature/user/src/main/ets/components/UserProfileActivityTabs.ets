import { SegmentButton, SegmentButtonOptions } from '@kit.ArkUI'
import { ThemeConstants } from 'shared'

/**
 * V1 @Component adapter that hosts the framework `SegmentButton` for UserProfilePage's
 * topic / reply activity tabs.
 *
 * Why this stays V1 while its parent (`UserProfilePage`) is `@ComponentV2`: `SegmentButton` declares
 * `@Link selectedIndexes: number[]`, and ArkUI forbids a `@ComponentV2` parent from binding any V1
 * `@Link` member — the compiler rejects it with "A V2 component cannot be used with any member property
 * decorated by '@Link' in a V1 component". So the mandatory two-way `selectedIndexes` binding must live
 * entirely inside a V1 component. This adapter owns that binding internally and exposes only a one-way
 * `@Prop` label pair + a plain click callback (both legal across the V2-parent -> V1-child boundary),
 * preserving the exact SegmentButton look and behaviour without swapping to a different component.
 *
 * The selected tab is page-state in the parent (driven off `onTabClicked`); this adapter keeps its own
 * `selectedIndexes` purely for the SegmentButton highlight, exactly as the page did before migration.
 */
@Component
export struct UserProfileActivityTabs {
  @Prop @Watch('onLabelsChanged') topicLabel: string = '';
  @Prop @Watch('onLabelsChanged') replyLabel: string = '';
  onTabClicked?: (index: number) => void;
  @State private selectedIndexes: number[] = [0];
  @State private tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '' }, { text: '' }],
    buttonPadding: { top: 10, bottom: 10, left: 8, right: 8 },
  });

  aboutToAppear(): void {
    this.rebuildOptions()
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
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_SM)
  }

  private onLabelsChanged(_propName: string): void {
    this.rebuildOptions()
  }

  private rebuildOptions(): void {
    this.tabOptions = SegmentButtonOptions.tab({
      buttons: [
        { text: this.topicLabel },
        { text: this.replyLabel }
      ],
      buttonPadding: { top: 10, bottom: 10, left: 8, right: 8 },
    })
  }
}
