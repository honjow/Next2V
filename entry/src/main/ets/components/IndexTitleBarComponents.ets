import {
  ApiConstants,
  AppSearchField,
  AppStrings,
  Avatar,
  BlockedListSelectedTabState,
  connectBlockedListSelectedTab,
  connectFeedTab,
  connectSearchAction,
  connectLanguageState,
  FeedTabBridge,
  FeedTabSettings,
  FeedTabState,
  connectFeedVisualIndex,
  FeedVisualIndexState,
  LanguageState,
  SearchActionState,
  SubTabBar,
  TabItem,
  ThemeConstants,
} from 'shared'
import { BlockedListsTabsSegment } from './BlockedListsTabsSegment'

@ComponentV2
struct BlockedListsTabs {
  // V2 mirror of BLOCKED_LIST_SELECTED_TAB; this title-bar control is the sole writer, BlockedListsPage
  // the sole reader (see BlockedListSelectedTabState). The segmented control lives in the @ComponentV2
  // BlockedListsTabsSegment, which hosts the V2-native TabSegmentButtonV2 (controlled selectedIndex).
  @Local private tabState: BlockedListSelectedTabState = connectBlockedListSelectedTab();
  @Local private language: LanguageState = connectLanguageState();
  // One-way labels pushed into the segmented control's @Trace items; @Local so a locale refresh re-renders.
  @Local private blockedUsersLabel: string = '';
  @Local private blockedTopicsLabel: string = '';

  aboutToAppear(): void {
    this.refreshLabels()
  }

  @Monitor('language.effectiveLocale')
  onLocaleChanged(): void {
    this.refreshLabels()
  }

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

  private refreshLabels(): void {
    this.blockedUsersLabel = AppStrings.text($r('app.string.blocked_users'), 'Blocked users')
    this.blockedTopicsLabel = AppStrings.text($r('app.string.ignored_topics'), 'Blocked topics')
  }
}
@Builder
export function BlockedListsTabsCCBuilder() {
  BlockedListsTabs()
}

// FeedPills is @ComponentV2: the pinned home feed-tab bar hosted in the HDS title-bar bottomBuilder.
// It hosts the shared SubTabBar, which owns the horizontal List, the sliding underline / capsule
// styling, per-tab layout measurement, and the centeredTarget REQUEST-TIME recenter coalescing guard
// (device-verified ~1 scrollToIndex per discrete tab change, vs the ~244x storm a naive V2 port made).
// The structural guards that keep the recenter bounded are preserved through the shared component:
//   1. Its host ComponentContent is created ONCE and cached in Index (Index.pillBarContent), never
//      re-created in build(). Re-creating it every Index.build() re-mounts this @ComponentV2 and,
//      because it reads the per-frame visual index, ties Index.build to that signal -> ~400
//      re-mounts/s during a swipe. Caching keeps the per-frame re-render inside the SubTabBar subtree.
//   2. The per-frame visual index lives in its OWN @ObservedV2 holder (FeedVisualIndexState), isolated
//      from the @Monitor-ed FeedTabState so its high-frequency churn cannot perturb feedTab observers.
//   3. SubTabBar's centeredTarget guard arms at request time, drives one centerTab per NEW target and
//      short-circuits repeat fires, so a deferred off-screen center can never storm.
// Tab taps route through FeedTabBridge.requestTransition (the NextE SubtabTransitionBridge pattern):
// the tap asks the HomePage swiper for a NATIVE page animation WITHOUT writing feedTab first. Writing
// feedTab before the animation is the pre-fix click-jump root cause (the controlled Swiper .index()
// binding settled the page + indicator instantly). The settled key flows back via the swiper onChange
// -> publishSelectedKey path, which also persists the selection.
@ComponentV2
struct FeedPills {
  @Local private feedState: FeedTabState = connectFeedTab();
  @Local private visualIndexState: FeedVisualIndexState = connectFeedVisualIndex();
  @Local private language: LanguageState = connectLanguageState();

  build() {
    SubTabBar({
      tabs: this.tabKeys(),
      labels: this.tabLabels(),
      barHeight: ApiConstants.TAB_BAR_HEIGHT,
      visualIndex: this.visualIndexState.value,
      selectedIndex: this.selectedTabIndex(),
      onSelect: (index: number) => {
        const keys: string[] = this.tabKeys()
        if (index >= 0 && index < keys.length && keys[index] !== this.feedState.feedTab) {
          FeedTabBridge.requestTransition(keys[index])
        }
      },
    })
  }

  private tabKeys(): string[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedState.feedTabKeys).map((tab: TabItem) => tab.key)
  }

  // AppStrings-resolved plain labels for the shared SubTabBar (a HAR cannot reference the app's $r
  // keys). AppStrings.text() reads the V2 locale signal; the explicit locale read below makes this
  // build re-run on a language switch so the cached bar re-keys with freshly resolved labels.
  private tabLabels(): string[] {
    const locale = this.language.effectiveLocale
    return FeedTabSettings.tabsFromKeysJson(this.feedState.feedTabKeys).map((tab: TabItem) => {
      if (typeof tab.label === 'string') {
        return tab.label
      }
      if (locale.length >= 0) {
        return AppStrings.text(tab.label, '')
      }
      return AppStrings.text(tab.label, '')
    })
  }

  private selectedTabIndex(): number {
    return this.tabKeys().findIndex((key: string) => key === this.feedState.feedTab)
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
  private language: LanguageState = connectLanguageState();
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
        // System-style trailing "搜索" button (Search's own searchButton property) so SOV2EX can be run
        // without the IME enter key. Tapping it fires onSubmit, same as pressing enter.
        searchButtonText: this.localeAwareText($r('app.string.nav_search'), 'Search'),
        useSystemMaterial: true,
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

  private localeAwareText(resource: Resource, fallback: string): string {
    if (this.language.effectiveLocale.length >= 0) {
      return AppStrings.text(resource, fallback)
    }
    return AppStrings.text(resource, fallback)
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
