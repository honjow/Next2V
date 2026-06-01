import { AppStorageV2 } from '@kit.ArkUI'
import { ApiConstants, TabItem } from '../constants/ApiConstants'

/**
 * V2 mirror of the feed-tab group: which feed tab is selected, the visible-tab key list, and the
 * indicator interpolation index.
 *
 * This is the **bidirectional, multi-writer** feed-tab bus:
 * - `feedTab` is written by HomePage (swipe -> onChange) AND FeedPills (tab tap) AND the persistence layer
 *   (`FeedTabSettings.applySelectedKey`). Read by both to drive the swiper / highlight.
 * - `feedTabKeys` is written by `FeedTabSettings.apply` (incl. bootstrap restore) AND HomeNodeSettingsPage
 *   (settings reorder, which routes through `FeedTabSettings.save` -> `apply`). Read by HomePage /
 *   FeedPills / HomeNodeSettingsPage.
 * The per-frame indicator interpolation index (`feedTabVisualIndex`) lives in a SEPARATE `@ObservedV2`
 * holder (`FeedVisualIndexState`, below), NOT on this class — see its own doc for why.
 *
 * Pure-V2: every consumer reads this mirror — including `FeedTabSettings`, which now reads `feedTab` /
 * `feedTabKeys` imperatively off the holder in save/saveSelectedKey — so `FeedTabBridge` writes only the
 * `@Trace` field; the legacy `FEED_TAB` / `FEED_TAB_KEYS` AppStorage half was retired once no reader read it.
 *
 * The factory seeds `feedTabKeys` to the default tab list (`ApiConstants.TAB_ITEMS`, identical to
 * `FeedTabSettings.defaultKeys()`) so a `@ComponentV2` connecting before the
 * `SettingsBootstrap.restoreFeedTabs()` bridge write sees the same defaults the persistence layer applies.
 */
@ObservedV2
export class FeedTabState {
  @Trace feedTab: string = 'tech'
  @Trace feedTabKeys: string = '[]'
}

const FEED_TAB_V2_KEY: string = 'v2:feedTab'

function defaultFeedTabKeysJson(): string {
  return JSON.stringify(ApiConstants.TAB_ITEMS.map((tab: TabItem) => tab.key))
}

/** Returns the app-wide FeedTabState singleton from AppStorageV2, defaulted to the built-in tab list. */
export function connectFeedTab(): FeedTabState {
  return AppStorageV2.connect(FeedTabState, FEED_TAB_V2_KEY, () => {
    const state = new FeedTabState()
    state.feedTabKeys = defaultFeedTabKeysJson()
    return state
  })!
}

/**
 * Single write point for the feed-tab group. `publishSelectedKey` / `publishKeys` write the V2 mirror that
 * every consumer (HomePage, FeedPills, HomeNodeSettingsPage, FeedTabSettings) reads. `publishVisualIndex`
 * writes the dedicated FeedVisualIndexState holder. Callers pass already-defaulted values (defaults live in
 * `FeedTabSettings`), so the bridge does no fallback logic of its own.
 */
export class FeedTabBridge {
  static publishSelectedKey(key: string): void {
    connectFeedTab().feedTab = key
  }

  static publishKeys(keysJson: string): void {
    connectFeedTab().feedTabKeys = keysJson
  }

  static publishVisualIndex(index: number): void {
    // Pure-V2: write the dedicated FeedVisualIndexState holder (separate from FeedTabState). The sole reader
    // is the @ComponentV2 FeedPills indicator. High-frequency (per-frame mid-swipe); isolated so it cannot
    // churn the feedTab/feedTabKeys observers.
    connectFeedVisualIndex().value = index
  }
}

const FEED_VISUAL_INDEX_V2_KEY: string = 'v2FeedVisualIndex'

/**
 * Per-frame feed-tab indicator interpolation index. Kept in its OWN @ObservedV2 holder (NOT on FeedTabState)
 * so its high-frequency mid-swipe writes never churn the feedTab/feedTabKeys observers, and crucially so the
 * @ComponentV2 FeedPills (hosted in a per-build ComponentContent) can read it reactively for the sliding
 * indicator without the host re-create loop a @Trace field on the @Monitor-ed FeedTabState triggered.
 */
@ObservedV2
export class FeedVisualIndexState {
  @Trace value: number = 0
}

/** Returns the app-wide FeedVisualIndexState singleton from AppStorageV2. */
export function connectFeedVisualIndex(): FeedVisualIndexState {
  return AppStorageV2.connect(FeedVisualIndexState, FEED_VISUAL_INDEX_V2_KEY, () => new FeedVisualIndexState())!
}

/**
 * V2 mirror of the feed list-scroll lock (`'listScrollEnabled'`). HomePage locks/unlocks list scrolling
 * while a horizontal tab swipe is in progress; the inner FeedListPage reads it for its scaffold's
 * `scrollEnabled`. Both ends move to V2 in this cut and no other surface reads the `'listScrollEnabled'`
 * AppStorage key (SearchPage/TopicDetailPage keep their own local `@State` of the same name), so this is a
 * pure-V2 mirror.
 */
@ObservedV2
export class ListScrollState {
  @Trace enabled: boolean = true
}

const LIST_SCROLL_V2_KEY: string = 'v2:listScrollEnabled'

/** Returns the app-wide ListScrollState singleton from AppStorageV2. */
export function connectListScroll(): ListScrollState {
  return AppStorageV2.connect(ListScrollState, LIST_SCROLL_V2_KEY, () => new ListScrollState())!
}
