import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the blocked-lists selected appbar tab (`StorageKeys.BLOCKED_LIST_SELECTED_TAB`).
 *
 * The selected tab is a one-directional bus between the appbar tab control and the page body: the
 * `BlockedListsTabs` title-bar component is the SOLE writer (the user taps a SegmentButton segment) and
 * `BlockedListsPage` is the SOLE reader (it switches between the blocked-members / ignored-topics list).
 * V1 stored it in `AppStorage`; with both ends migrated to `@ComponentV2` in the blocked-lists-v2 slice
 * there is no remaining V1 `@StorageLink` reader, so this mirror is the single source of truth (no
 * `AppStorage` dual-write needed — it is a fully-migrated key, not a transitional bridge). The shared
 * singleton persists the within-session tab choice across navigation exactly as the old `AppStorage` key
 * did, so returning to the destination restores the last-selected tab.
 *
 * Reading `selectedTab` inside a `@ComponentV2` `build()` subscribes that component to tab changes.
 */
@ObservedV2
export class BlockedListSelectedTabState {
  @Trace selectedTab: number = 0
}

const BLOCKED_LIST_SELECTED_TAB_V2_KEY: string = 'v2:blockedListSelectedTab'

/** Returns the app-wide BlockedListSelectedTabState singleton from AppStorageV2. */
export function connectBlockedListSelectedTab(): BlockedListSelectedTabState {
  return AppStorageV2.connect(
    BlockedListSelectedTabState,
    BLOCKED_LIST_SELECTED_TAB_V2_KEY,
    () => new BlockedListSelectedTabState(),
  )!
}

/**
 * V2 mirror of the blocked-lists id/updatedAt ledger that `BlockedListsPage` observes to refresh when
 * the blocked set changes while the page is open
 * (`StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS` / `BLOCKED_LIST_BLOCKED_MEMBER_IDS` /
 * `BLOCKED_LIST_UPDATED_AT`).
 *
 * These keys are written ONLY by `BlockedListSettings.apply()` (the single persist point) and were
 * observed by exactly one reactive consumer — `BlockedListsPage`'s `@StorageLink ... @Watch`. Other
 * readers (`ApiService`, `BlockedListSettings.runtimeSnapshot`) read the same `AppStorage` keys
 * imperatively, so during the State Management V1->V2 migration the ledger must live in BOTH stores at
 * once: `BlockedListSettings.apply()` dual-writes the V1 `AppStorage` keys AND these `@Trace` fields, so
 * the two stores never diverge — mirroring the `LocalDataPublisher` -> `TopicReadStatesState` precedent.
 *
 * A `@ComponentV2` consumer holds the singleton as `@Local` and reacts via
 * `@Monitor('<member>.ignoredTopicIdsJson', '<member>.blockedMemberIdsJson', '<member>.updatedAt')`.
 * The member metas keys are NOT mirrored here — they are read imperatively via
 * `BlockedListSettings.runtimeSnapshot()`, never via a reactive decorator.
 *
 * Transitional: drop the `AppStorage` half once every imperative reader has moved to V2.
 */
@ObservedV2
export class BlockedListStorageState {
  @Trace ignoredTopicIdsJson: string = '[]'
  @Trace blockedMemberIdsJson: string = '[]'
  @Trace updatedAt: number = 0
}

const BLOCKED_LIST_STORAGE_V2_KEY: string = 'v2:blockedListStorage'

/** Returns the app-wide BlockedListStorageState singleton from AppStorageV2. */
export function connectBlockedListStorage(): BlockedListStorageState {
  return AppStorageV2.connect(
    BlockedListStorageState,
    BLOCKED_LIST_STORAGE_V2_KEY,
    () => new BlockedListStorageState(),
  )!
}
