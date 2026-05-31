import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'
import { ApiConstants, TabItem } from '../constants/ApiConstants'
import { setAppStorageValue } from '../settings/SettingsStorage'

/**
 * V2 mirror of the feed-tab group: which feed tab is selected (`StorageKeys.FEED_TAB`), the visible-tab
 * key list (`StorageKeys.FEED_TAB_KEYS`), and the indicator interpolation index
 * (`StorageKeys.FEED_TAB_VISUAL_INDEX`).
 *
 * This is the **bidirectional, multi-writer** feed-tab bus:
 * - `feedTab` is written by HomePage (swipe -> onChange) AND FeedPills (tab tap) AND the persistence layer
 *   (`FeedTabSettings.applySelectedKey`). Read by both to drive the swiper / highlight.
 * - `feedTabKeys` is written by `FeedTabSettings.apply` (incl. bootstrap restore) AND HomeNodeSettingsPage
 *   (settings reorder, **stays V1** and also routes through `FeedTabSettings.save` -> `apply`). Read by
 *   HomePage / FeedPills (+ HomeNodeSettingsPage's own V1 `@StorageLink`).
 * The per-frame indicator interpolation index (`feedTabVisualIndex`) lives in a SEPARATE `@ObservedV2`
 * holder (`FeedVisualIndexState`, below), NOT on this class — see its own doc for why.
 *
 * Bridge stance during the V1->V2 migration:
 * - `feedTab` / `feedTabKeys` have remaining V1 consumers — `FeedTabSettings` imperatively `AppStorage.get`s
 *   both — so `FeedTabBridge` DUAL-WRITES the V1 AppStorage key AND the `@Trace` field (à la
 *   `LayoutSafeAreaBridge`). (Both `@ComponentV2` HomePage and `@ComponentV2` HomeNodeSettingsPage read the
 *   mirror.)
 *
 * The factory seeds `feedTab`/`feedTabKeys` from AppStorage so a `@ComponentV2` connecting before the
 * `SettingsBootstrap.restoreFeedTabs()` bridge write still gets the persisted values — matching the old
 * `@StorageLink` initial-read semantics (default keys = `ApiConstants.TAB_ITEMS`, identical to
 * `FeedTabSettings.defaultKeys()`).
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

/** Returns the app-wide FeedTabState singleton from AppStorageV2, seeded from the V1 AppStorage keys. */
export function connectFeedTab(): FeedTabState {
  return AppStorageV2.connect(FeedTabState, FEED_TAB_V2_KEY, () => {
    const state = new FeedTabState()
    state.feedTab = AppStorage.get<string>(StorageKeys.FEED_TAB) ?? 'tech'
    state.feedTabKeys = AppStorage.get<string>(StorageKeys.FEED_TAB_KEYS) ?? defaultFeedTabKeysJson()
    return state
  })!
}

/**
 * Single dual-write point for the feed-tab group. `publishSelectedKey` / `publishKeys` write BOTH the V1
 * AppStorage key (still read imperatively by `FeedTabSettings` and via `@StorageLink` by
 * HomeNodeSettingsPage) AND the V2 mirror, keeping the stores in lockstep. `publishVisualIndex` writes the
 * mirror only (no remaining V1 reader). Callers pass already-defaulted values (defaults live in
 * `FeedTabSettings`), so the bridge does no fallback logic of its own.
 */
export class FeedTabBridge {
  static publishSelectedKey(key: string): void {
    setAppStorageValue<string>(StorageKeys.FEED_TAB, key)
    connectFeedTab().feedTab = key
  }

  static publishKeys(keysJson: string): void {
    setAppStorageValue<string>(StorageKeys.FEED_TAB_KEYS, keysJson)
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
