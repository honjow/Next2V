import {
  ApiConstants,
  AppStrings,
  AppSearchField,
  Avatar,
  BlockedListSelectedTabState,
  connectBlockedListSelectedTab,
  connectDiscoverKeyword,
  DiscoverKeywordState,
  FeedTabBridge,
  FeedTabSettings,
  StorageKeys,
  TabItem,
  ThemeConstants,
} from 'shared'
import { BlockedListsTabsSegment } from './BlockedListsTabsSegment'

@ComponentV2
struct BlockedListsTabs {
  // V2 mirror of BLOCKED_LIST_SELECTED_TAB; this title-bar control is the sole writer, BlockedListsPage
  // the sole reader (see BlockedListSelectedTabState). The SegmentButton itself lives in the V1
  // BlockedListsTabsSegment adapter (a @ComponentV2 cannot bind SegmentButton's @Link selectedIndexes).
  @Local private tabState: BlockedListSelectedTabState = connectBlockedListSelectedTab()
  // One-way labels rebuilt into the adapter's SegmentButton options; @Local so a locale refresh re-renders.
  @Local private blockedUsersLabel: string = AppStrings.text(AppStrings.R_BLOCKED_USERS, 'Blocked users')
  @Local private blockedTopicsLabel: string = AppStrings.text(AppStrings.R_IGNORED_TOPICS, 'Blocked topics')

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

// FeedPills stays an intentional V1 @Component: its tab-bar layout machinery
// (centerTab -> scrollToIndex -> onAreaChange -> updateTabLayout -> re-render) re-fires a V2 @Monitor on
// every settle frame (device-verified ~37x for a single feedTab change vs ~1x for HomePage's @Monitor), so
// hosting the recenter handler under V2 over-fires. V1 @StorageLink + @Watch is well-behaved here. It still
// participates in the V2 feed-tab migration: its tab-tap write routes through FeedTabBridge.publishSelectedKey
// (AppStorage + the V2 FeedTabState mirror the @ComponentV2 HomePage reads), and it reads the
// bridge-dual-written AppStorage keys via @StorageLink. Migrating FeedPills itself to V2 is a deferred,
// separately-scoped follow-up (needs a non-@Monitor recenter trigger).
@Component
struct FeedPills {
  @StorageLink(StorageKeys.FEED_TAB) @Watch('onFeedTabChanged') feedTab: string = 'tech';
  @StorageLink(StorageKeys.FEED_TAB_KEYS) @Watch('onFeedTabKeysChanged') feedTabKeys: string =
    FeedTabSettings.defaultKeysJson();
  @StorageLink(StorageKeys.FEED_TAB_VISUAL_INDEX) feedTabVisualIndex: number = 0;
  @State private tabLefts: number[] = [];
  @State private tabWidths: number[] = [];
  @State private containerGlobalLeft: number = 0;
  private pendingCenterIndex: number = -1;
  private pendingCenterSmooth: boolean = true;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const index = this.selectedTabIndex()
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
                .fontColor(
                  this.visualSelectedIndex() === index
                    ? ThemeConstants.BRAND_PRIMARY
                    : ThemeConstants.TEXT_SECONDARY,
                )
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
              // local @StorageLink feedTab updates from the AppStorage half and fires @Watch for centering.
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

  private onFeedTabChanged(_propName: string): void {
    const index = this.selectedTabIndex()
    if (index < 0) {
      return
    }
    this.centerTab(index, true)
  }

  private onFeedTabKeysChanged(_propName: string): void {
    this.tabLefts = []
    this.tabWidths = []
    this.pendingCenterIndex = -1
  }

  private visibleTabs(): TabItem[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedTabKeys)
  }

  private selectedTabIndex(): number {
    const index = this.visibleTabs().findIndex((tab: TabItem) => tab.key === this.feedTab)
    return index
  }

  private visualSelectedIndex(): number {
    const count = this.visibleTabs().length
    if (count <= 0) {
      return 0
    }
    return Math.max(0, Math.min(count - 1, Math.round(this.feedTabVisualIndex)))
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
    const visualIndex = Math.max(0, Math.min(count - 1, this.feedTabVisualIndex))
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
export function PillCCBuilder() {
  FeedPills()
}

@ComponentV2
struct DiscoverSearchComponent {
  // Shared with DiscoverPage via AppStorageV2 (replaces the V1 DISCOVER_NODE_KEYWORD bus).
  @Local kwState: DiscoverKeywordState = connectDiscoverKeyword()

  build() {
    Row() {
      AppSearchField({
        text: this.kwState.keyword,
        placeholder: $r('app.string.search_discover_nodes_placeholder'),
        onTextChange: (value: string) => {
          this.kwState.keyword = value
        },
      })
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: 4,
      bottom: 4,
    })
  }
}

@Builder
export function DiscoverSearchCCBuilder() {
  DiscoverSearchComponent()
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
