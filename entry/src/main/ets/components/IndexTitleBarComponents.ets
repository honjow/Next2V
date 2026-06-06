import {
  ApiConstants,
  AppSearchField,
  AppStrings,
  Avatar,
  BlockedListSelectedTabState,
  connectBlockedListSelectedTab,
  connectFeedTab,
  connectSearchAction,
  connectThemeDisplay,
  FeedTabBridge,
  FeedTabSettings,
  FeedTabState,
  connectFeedVisualIndex,
  FeedVisualIndexState,
  SearchActionState,
  TabItem,
  ThemeConstants,
  ThemeDisplayState,
} from 'shared'
import { BlockedListsTabsSegment } from './BlockedListsTabsSegment'

@ComponentV2
struct BlockedListsTabs {
  // V2 mirror of BLOCKED_LIST_SELECTED_TAB; this title-bar control is the sole writer, BlockedListsPage
  // the sole reader (see BlockedListSelectedTabState). The segmented control lives in the @ComponentV2
  // BlockedListsTabsSegment, which hosts the V2-native TabSegmentButtonV2 (controlled selectedIndex).
  @Local private tabState: BlockedListSelectedTabState = connectBlockedListSelectedTab();
  // One-way labels pushed into the segmented control's @Trace items; @Local so a locale refresh re-renders.
  @Local private blockedUsersLabel: string = AppStrings.text(
    AppStrings.R_BLOCKED_USERS,
    'Blocked users',
  );
  @Local private blockedTopicsLabel: string = AppStrings.text(
    AppStrings.R_IGNORED_TOPICS,
    'Blocked topics',
  );

  build() {
    BlockedListsTabsSegment({
      firstLabel: this.blockedUsersLabel,
      secondLabel: this.blockedTopicsLabel,
      selectedIndex: this.clampTab(this.tabState.selectedTab),
      onTabClicked: (index: number) => {
        this.tabState.selectedTab = this.clampTab(index)
      },
    })
  }

  private clampTab(index: number): number {
    return index === 1 ? 1 : 0
  }
}
@Builder
export function BlockedListsTabsCCBuilder() {
  BlockedListsTabs()
}

// FeedPills is @ComponentV2: it reads the V2 FeedTabState mirror (feedTab / feedTabKeys) plus the dedicated
// FeedVisualIndexState holder (per-frame indicator/highlight), and recenters its horizontal pill bar from
// @Monitor('feedState.feedTab'). Three things make the recenter device-verifiably bounded to ~1 scrollToIndex
// per discrete tab change (V1-equivalent), instead of the ~244x storm a naive V2 port produced:
//   1. Its host ComponentContent is created ONCE and cached in Index (Index.pillBarContent), never re-`new`-ed
//      in build(). Re-creating it every Index.build() re-mounts this @ComponentV2 and, because it reads the
//      per-frame visual index, ties Index.build to that signal -> ~400 re-mounts/s during a swipe, each
//      re-centering. Caching keeps the per-frame re-render inside FeedPills.
//   2. The per-frame visual index lives in its OWN @ObservedV2 holder (FeedVisualIndexState), isolated from
//      the @Monitor-ed FeedTabState so its high-frequency churn cannot perturb the feedTab observers.
//   3. The `centeredTarget` REQUEST-TIME coalescing guard (below): a new target arms it and drives one
//      centerTab; repeat fires for the same target short-circuit even while an off-screen center is deferred,
//      so the over-fire/deferred-retry can never storm. centerTab/updateTabLayout stay byte-identical to V1
//      (pendingCenterIndex cleared before scrolling) so a deferred center completes exactly once.
// The per-frame visualIndex re-render (highlight + sliding indicator) is preserved unchanged. Tab taps still
// route through FeedTabBridge.publishSelectedKey (AppStorage + the V2 mirror HomePage reads).
@ComponentV2
struct FeedPills {
  @Local private feedState: FeedTabState = connectFeedTab();
  @Local private visualIndexState: FeedVisualIndexState = connectFeedVisualIndex();
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay();
  @Local private tabLefts: number[] = [];
  @Local private tabWidths: number[] = [];
  @Local private containerGlobalLeft: number = 0;
  private pendingCenterIndex: number = -1;
  private pendingCenterSmooth: boolean = true;
  // Request-time recenter coalescing: the tab index we are currently driving a recenter toward. Armed the
  // instant a NEW target is observed (before any deferral), so the ~32x monitor burst collapses to one
  // effective recenter and the off-screen deferred-retry cannot storm. Reset on a keys change (reorder).
  private centeredTarget: number = -1;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const index = this.selectedTabIndex()
    // Idempotent vs re-attach: the host ComponentContent can re-attach this same instance many times during
    // a swipe; only (re)center when the selected target actually differs from what we last centered toward,
    // so a re-attach with an unchanged selection does not re-issue scrollToIndex. Real changes are driven by
    // @Monitor('feedState.feedTab') below; this only seeds/repairs the initial + post-reorder centering.
    if (index === this.centeredTarget) {
      return
    }
    this.centeredTarget = index
    if (index > 0) {
      this.centerTab(index, false)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ space: ThemeConstants.SPACE_XS, scroller: this.scroller }) {
        ForEach(this.visibleTabs(), (tab: TabItem, index: number) => {
          ListItem() {
            Column({ space: 1 }) {
              Text(tab.label)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor(this.tabTextColor(index))
                .fontWeight(
                  this.visualSelectedIndex() === index ? FontWeight.Medium : FontWeight.Regular,
                )
                .padding({
                  left: ThemeConstants.SPACE_MD,
                  right: ThemeConstants.SPACE_MD,
                  top: ThemeConstants.SPACE_XS,
                })
              Blank()
                .height(2)
                .width(18)
            }
            .alignItems(HorizontalAlign.Center)
            .padding({ bottom: 0 })
            .onClick(() => {
              // Route through the bridge (AppStorage + V2 mirror) so the @ComponentV2 HomePage reacts; the
              // shared feedState.feedTab @Trace updates from the mirror half and fires our @Monitor for centering.
              FeedTabBridge.publishSelectedKey(tab.key)
            })
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              this.updateTabLayout(index, newValue)
            })
          }
        })
      }
      .scrollBar(BarState.Off)
      .listDirection(Axis.Horizontal)
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      .width('100%')
      .height('100%')
      Row()
        .width(this.indicatorWidth())
        .height(3)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .borderRadius(1.5)
        .position({ x: this.indicatorLeft(), y: ApiConstants.TAB_BAR_HEIGHT - 14 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.containerGlobalLeft = this.areaX(newValue?.globalPosition?.x)
    })
  }

  @Monitor('feedState.feedTab')
  onFeedTabChanged(): void {
    const index = this.selectedTabIndex()
    if (index < 0) {
      return
    }
    // Coalesce the ~32x monitor burst for ONE discrete change: only a genuinely new target drives a
    // recenter; repeated fires for the same target are no-ops. Arm at request time so an off-screen
    // (deferred) target still short-circuits the rest of the burst.
    if (index === this.centeredTarget) {
      return
    }
    this.centeredTarget = index
    this.centerTab(index, true)
  }

  @Monitor('feedState.feedTabKeys')
  onFeedTabKeysChanged(): void {
    this.tabLefts = []
    this.tabWidths = []
    this.pendingCenterIndex = -1
    // Layout/order changed: drop the recenter guard so the next feedTab change recenters against the new
    // layout (e.g. HomePage.correctFeedTabIfNeeded re-selecting tab 0 after a reorder).
    this.centeredTarget = -1
  }

  private visibleTabs(): TabItem[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedState.feedTabKeys)
  }

  private selectedTabIndex(): number {
    const index = this.visibleTabs().findIndex((tab: TabItem) => tab.key === this.feedState.feedTab)
    return index
  }

  private visualSelectedIndex(): number {
    const count = this.visibleTabs().length
    if (count <= 0) {
      return 0
    }
    return Math.max(0, Math.min(count - 1, Math.round(this.visualIndexState.value)))
  }

  private tabTextColor(index: number): ResourceColor {
    const color =
      this.visualSelectedIndex() === index
        ? ThemeConstants.BRAND_PRIMARY
        : ThemeConstants.TEXT_SECONDARY
    return this.themeTrackedColor(color)
  }

  private themeTrackedColor(color: ResourceColor): ResourceColor {
    // FeedPills is hosted in a cached ComponentContent, so it must read the V2 theme signal itself;
    // the color token stays semantic/system-owned, while this dependency triggers immediate repaint.
    if (this.themeDisplay.effectiveDark) {
      return color
    }
    return color
  }

  private updateTabLayout(index: number, area: Area): void {
    const width = (area?.width as number) || 0
    const left = this.areaX(area?.globalPosition?.x) - this.containerGlobalLeft
    if (width <= 0) {
      return
    }
    const nextLefts = this.tabLefts.slice()
    const nextWidths = this.tabWidths.slice()
    nextLefts[index] = left
    nextWidths[index] = width
    this.tabLefts = nextLefts
    this.tabWidths = nextWidths
    if (this.pendingCenterIndex === index) {
      this.centerTab(index, this.pendingCenterSmooth)
    }
  }

  private indicatorWidth(): number {
    return 18
  }

  private indicatorLeft(): number {
    const count = this.visibleTabs().length
    if (count <= 0) {
      return ThemeConstants.SPACE_SM
    }
    const visualIndex = Math.max(0, Math.min(count - 1, this.visualIndexState.value))
    const fromIndex = Math.floor(visualIndex)
    const toIndex = Math.min(count - 1, fromIndex + 1)
    const fraction = visualIndex - fromIndex
    const fromCenter = this.tabCenter(fromIndex)
    const toCenter = this.tabCenter(toIndex)
    return fromCenter + (toCenter - fromCenter) * fraction - this.indicatorWidth() / 2
  }

  private tabCenter(index: number): number {
    const left = this.tabLefts[index]
    const width = this.tabWidths[index]
    if (left !== undefined && width !== undefined && width > 0) {
      return left + width / 2
    }
    return this.estimatedTabCenter(index)
  }

  private averageMeasuredTabWidth(): number {
    let total = 0
    let count = 0
    for (let i = 0; i < this.tabWidths.length; i++) {
      const width = this.tabWidths[i]
      if (width !== undefined && width > 0) {
        total += width
        count++
      }
    }
    return count > 0 ? total / count : 48
  }

  private estimatedTabCenter(index: number): number {
    const step = this.averageMeasuredTabWidth() + ThemeConstants.SPACE_XS
    for (let prev = index - 1; prev >= 0; prev--) {
      const left = this.tabLefts[prev]
      const width = this.tabWidths[prev]
      if (left !== undefined && width !== undefined && width > 0) {
        return left + width / 2 + (index - prev) * step
      }
    }
    for (let next = index + 1; next < this.visibleTabs().length; next++) {
      const left = this.tabLefts[next]
      const width = this.tabWidths[next]
      if (left !== undefined && width !== undefined && width > 0) {
        return left + width / 2 - (next - index) * step
      }
    }
    return ThemeConstants.SPACE_SM + this.averageMeasuredTabWidth() / 2 + index * step
  }

  private areaX(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private centerTab(index: number, smooth: boolean): void {
    if (index < 0 || index >= this.visibleTabs().length) {
      return
    }
    const width = this.tabWidths[index]
    if (width === undefined || width <= 0) {
      this.pendingCenterIndex = index
      this.pendingCenterSmooth = smooth
      return
    }
    this.pendingCenterIndex = -1
    this.scroller.scrollToIndex(index, smooth, ScrollAlign.CENTER)
  }
}
@Builder
export function PillCCBuilder(_params: Object) {
  FeedPills()
}

const TITLE_BAR_COMPACT_WIDTH: number = 600
const TITLE_BAR_EXPANDED_WIDTH: number = 840
const TITLE_BAR_LEADING_EDGE_RESERVE_COMPACT: number = 16
const TITLE_BAR_LEADING_EDGE_RESERVE_MEDIUM: number = 24
const TITLE_BAR_LEADING_EDGE_RESERVE_EXPANDED: number = 32
const TITLE_BAR_BACK_BUTTON_SLOT_WIDTH: number = 48
const TITLE_BAR_ACTION_VISUAL_RESERVE: number = 36
const TITLE_BAR_TRAILING_EDGE_RESERVE: number = TITLE_BAR_LEADING_EDGE_RESERVE_COMPACT

function titleBarLengthToNumber(value: Length | undefined): number {
  if (typeof value === 'number') {
    return value
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value)
    return Number.isNaN(parsed) ? 0 : parsed
  }
  return 0
}

function titleBarTrailingReserve(menuMaxCount: number, menuItemCount: number): number {
  const inlineCount = Math.max(0, Math.min(menuMaxCount, menuItemCount))
  const hasOverflowAction = menuItemCount > menuMaxCount
  const actionSlotCount = inlineCount + (hasOverflowAction ? 1 : 0)
  if (actionSlotCount <= 0) {
    return 0
  }
  return actionSlotCount * TITLE_BAR_ACTION_VISUAL_RESERVE + TITLE_BAR_TRAILING_EDGE_RESERVE
}

function titleBarWidthAwareEdgeReserve(titleBarWidth: number): number {
  if (titleBarWidth >= TITLE_BAR_EXPANDED_WIDTH) {
    return TITLE_BAR_LEADING_EDGE_RESERVE_EXPANDED
  }
  if (titleBarWidth >= TITLE_BAR_COMPACT_WIDTH) {
    return TITLE_BAR_LEADING_EDGE_RESERVE_MEDIUM
  }
  return TITLE_BAR_LEADING_EDGE_RESERVE_COMPACT
}

function titleBarLeadingReserve(titleBarWidth: number): number {
  return TITLE_BAR_BACK_BUTTON_SLOT_WIDTH + titleBarWidthAwareEdgeReserve(titleBarWidth)
}

// The standalone Search page hosts its input directly in the HdsNavDestination title bar (so there is no
// separate search row in the page body). It writes the shared SearchActionState bus that SearchPage reads:
// keyword on every keystroke, submitSeq on Enter. SearchPage seeds the field back via seedSeq (history chip /
// pending query / reset) — the field must NOT read keyword in build (see fieldText) or typing flaps the IME.
@ComponentV2
struct SearchTitleField {
  private actionState: SearchActionState = connectSearchAction();
  @Local private titleBarWidth: number = 0;
  // The text pushed INTO the field. It changes only on mount or when SearchPage seeds a query (via seedSeq),
  // NEVER per keystroke. build() must not read actionState.keyword: typing writes keyword on every character,
  // and because this component is a title-bar ComponentContent, re-running its build rebuilds the whole
  // subtree and re-mounts the Search — which closed + reopened the soft keyboard on every keystroke.
  @Local private fieldText: string = '';

  aboutToAppear(): void {
    this.fieldText = this.actionState.keyword
  }

  @Monitor('actionState.seedSeq')
  onSeed(): void {
    this.fieldText = this.actionState.keyword
  }

  build() {
    Row() {
      AppSearchField({
        text: this.fieldText,
        placeholder: $r('app.string.search_topics_nodes_users_placeholder'),
        autoFocus: true,
        onTextChange: (value: string) => {
          // Write-only — must NOT be read back in build() (see fieldText), or every keystroke re-renders here.
          this.actionState.keyword = value
        },
        onSubmit: (_value: string) => {
          this.actionState.submitSeq = this.actionState.submitSeq + 1
        },
      }).layoutWeight(1)
    }
    .width('100%')
    .height(ThemeConstants.TITLE_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    // Left padding clears the auto back-button slot; right padding keeps an edge gap (no menu on this page).
    .padding({
      left: titleBarLeadingReserve(this.titleBarWidth),
      right: TITLE_BAR_TRAILING_EDGE_RESERVE,
    })
    // None on the Row so the empty leading region (the back-button slot) stays tappable; the AppSearchField
    // child still hit-tests normally (HitTestMode.None is per-node, not subtree).
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.titleBarWidth = titleBarLengthToNumber(newValue?.width)
    })
  }
}
@Builder
export function SearchTitleFieldCCBuilder(_params: Object) {
  SearchTitleField()
}

export interface UserProfileAppbarIdentityParams {
  titleUsername: string
  avatarUrl: string
  menuMaxCount: number
  menuItemCount: number
}

@ComponentV2
struct UserProfileAppbarIdentity {
  @Param titleUsername: string = '';
  @Param avatarUrl: string = '';
  @Param menuMaxCount: number = 0;
  @Param menuItemCount: number = 0;
  @Local private titleBarWidth: number = 0;

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      if ((this.titleUsername || '').trim()) {
        Avatar({
          url: this.avatarUrl,
          avatarSize: 24,
          placeholder: (this.titleUsername || '').trim(),
        })
        Text((this.titleUsername || '').trim())
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(ThemeConstants.TITLE_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: titleBarLeadingReserve(this.titleBarWidth),
      right: titleBarTrailingReserve(this.menuMaxCount, this.menuItemCount),
    })
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.titleBarWidth = titleBarLengthToNumber(newValue?.width)
    })
  }
}
@Builder
export function UserProfileIdentityCCBuilder(params: UserProfileAppbarIdentityParams) {
  UserProfileAppbarIdentity({
    titleUsername: params.titleUsername,
    avatarUrl: params.avatarUrl,
    menuMaxCount: params.menuMaxCount,
    menuItemCount: params.menuItemCount,
  })
}

export interface NodeTopicAppbarIdentityParams {
  titleNodeName: string
  avatarUrl: string
  menuMaxCount: number
  menuItemCount: number
}

@ComponentV2
struct NodeTopicAppbarIdentity {
  @Param titleNodeName: string = '';
  @Param avatarUrl: string = '';
  @Param menuMaxCount: number = 0;
  @Param menuItemCount: number = 0;
  @Local private titleBarWidth: number = 0;

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      if ((this.titleNodeName || '').trim()) {
        Avatar({
          url: this.avatarUrl,
          avatarSize: 24,
          placeholder: (this.titleNodeName || '').trim(),
        })
        Text((this.titleNodeName || '').trim())
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(ThemeConstants.TITLE_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: titleBarLeadingReserve(this.titleBarWidth),
      right: titleBarTrailingReserve(this.menuMaxCount, this.menuItemCount),
    })
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.titleBarWidth = titleBarLengthToNumber(newValue?.width)
    })
  }
}
@Builder
export function NodeTopicIdentityCCBuilder(params: NodeTopicAppbarIdentityParams) {
  NodeTopicAppbarIdentity({
    titleNodeName: params.titleNodeName,
    avatarUrl: params.avatarUrl,
    menuMaxCount: params.menuMaxCount,
    menuItemCount: params.menuItemCount,
  })
}

export interface TopicDetailAppbarIdentityParams {
  title: string
  avatarUrl: string
  username: string
  menuMaxCount: number
  menuItemCount: number
}

@ComponentV2
struct TopicDetailAppbarIdentity {
  @Param title: string = '';
  @Param avatarUrl: string = '';
  @Param username: string = '';
  @Param menuMaxCount: number = 0;
  @Param menuItemCount: number = 0;
  @Local private titleBarWidth: number = 0;

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      if ((this.title || '').trim()) {
        Avatar({
          url: this.avatarUrl,
          avatarSize: 24,
          placeholder: (this.username || this.title || '').trim(),
        })
        Text((this.title || '').trim())
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(ThemeConstants.TITLE_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: titleBarLeadingReserve(this.titleBarWidth),
      right: titleBarTrailingReserve(this.menuMaxCount, this.menuItemCount),
    })
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.titleBarWidth = titleBarLengthToNumber(newValue?.width)
    })
  }
}
@Builder
export function TopicDetailIdentityCCBuilder(params: TopicDetailAppbarIdentityParams) {
  TopicDetailAppbarIdentity({
    title: params.title,
    avatarUrl: params.avatarUrl,
    username: params.username,
    menuMaxCount: params.menuMaxCount,
    menuItemCount: params.menuItemCount,
  })
}
