import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 buses for the two one-directional Search inputs (`'v2:searchAction'`: the `command` +
 * `pendingQuery` fields).
 *
 * Both are one-directional command buses with a single reactive consumer, the
 * `@ComponentV2` `SearchPage`:
 * - `command`: the appbar search affordance writes a `<token>:<action>` string
 *   (`Index.sendSearchAction`, the single writer); the page reacts to run the matching
 *   filter / refresh. V2-only — the legacy `AppStorage` (`searchAction`) key + its
 *   dual-write were retired once no reader read the V1 half.
 * - `pendingQuery`: a cross-page "search for X" request written as `<token>:<query>` by
 *   `SearchQueryBus.publishPending` (the single writer — Index's URL-route handler and
 *   TopicDetailPage's link handler both route through it); the page reacts to seed and run that
 *   query, then clears the bus via `SearchQueryBus.clearPending`. V2-only — the legacy `AppStorage`
 *   (`pendingSearchQuery`) key + its dual-write were retired once no reader read the V1 half.
 *
 * The leading `<token>` (a timestamp) only guarantees the string changes so the bus
 * refires for a repeated action / query — it is the pre-existing command-bus encoding,
 * NOT a key-churn UI workaround. There is no writeback on either field.
 *
 * A `@ComponentV2` consumer holds the singleton and runs each reaction via
 * `@Monitor('<member>.command')` / `@Monitor('<member>.pendingQuery')` when the field
 * changes.
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
