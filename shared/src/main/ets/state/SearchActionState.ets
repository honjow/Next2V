import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the two one-directional Search input buses
 * (`StorageKeys.SEARCH_ACTION` + `StorageKeys.PENDING_SEARCH_QUERY`).
 *
 * Both are one-directional command buses with a single reactive consumer, the
 * `@ComponentV2` `SearchPage`:
 * - `command` mirrors `SEARCH_ACTION`: the appbar search affordance writes a
 *   `<token>:<action>` string (`Index.sendSearchAction`, the single writer); the page
 *   reacts to run the matching filter / refresh.
 * - `pendingQuery` mirrors `PENDING_SEARCH_QUERY`: a cross-page "search for X" request
 *   written as `<token>:<query>` by `SearchQueryBus.publishPending` (the single
 *   dual-write point — Index's URL-route handler and TopicDetailPage's link handler
 *   both route through it); the page reacts to seed and run that query, then clears the
 *   bus via `SearchQueryBus.clearPending`.
 *
 * The leading `<token>` (a timestamp) only guarantees the string changes so the bus
 * refires for a repeated action / query — it is the pre-existing command-bus encoding,
 * NOT a key-churn UI workaround. There is no writeback on either key.
 *
 * During the State Management V1->V2 migration each command lives in BOTH stores at
 * once: the writer dual-writes the V1 `AppStorage` key AND the matching `@Trace` field
 * so the bridge stays uniform and reversible, mirroring the `UserProfileActionState` /
 * `NodeTopicActionState` / `ImagePreviewActionState` precedents.
 *
 * A `@ComponentV2` consumer holds the singleton and runs each reaction via
 * `@Monitor('<member>.command')` / `@Monitor('<member>.pendingQuery')` when the field
 * changes.
 *
 * Transitional: drop the `AppStorage` half once the writers no longer need it.
 */
@ObservedV2
export class SearchActionState {
  @Trace command: string = ''
  @Trace pendingQuery: string = ''
}

const SEARCH_ACTION_V2_KEY: string = 'v2:searchAction'

/** Returns the app-wide SearchActionState singleton from AppStorageV2. */
export function connectSearchAction(): SearchActionState {
  return AppStorageV2.connect(SearchActionState, SEARCH_ACTION_V2_KEY, () => new SearchActionState())!
}
