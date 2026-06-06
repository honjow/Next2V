import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 buses for the standalone Search page, stored under `'v2:searchAction'`. Both the title-bar search
 * field (hosted in the `HdsNavDestination` title bar, a separate component tree) and the `@ComponentV2`
 * `SearchPage` connect to this single singleton, which is how they stay in sync across the two trees.
 *
 * - `keyword`: the live query text. The title-bar field is the primary writer (one write per keystroke);
 *   `SearchPage` mirrors it into its own working keyword via `@Monitor('actionState.keyword')`, and also
 *   writes it back (suppressing its own monitor) when it seeds a query from a history chip / pending
 *   request, so the field reflects the chosen text. `@Trace` so both trees react.
 * - `submitSeq`: a monotonically increasing submit signal. The title-bar field bumps it on Enter;
 *   `SearchPage` reacts via `@Monitor('actionState.submitSeq')` to run the SOV2EX remote search. The value
 *   is meaningless — it only guarantees the field changes so the bus refires for a repeated submit.
 * - `pendingQuery`: a cross-page "search for X" request written as `<token>:<query>` by
 *   `SearchQueryBus.publishPending` (the single writer — Index's URL-route handler and TopicDetailPage's
 *   link handler both route through it); the page reacts to seed and run that query, then clears the bus
 *   via `SearchQueryBus.clearPending`. V2-only — the legacy `AppStorage` (`pendingSearchQuery`) key + its
 *   dual-write were retired once no reader read the V1 half.
 *
 * A `@ComponentV2` consumer holds the singleton and runs each reaction via `@Monitor('<member>.<field>')`.
 */
@ObservedV2
export class SearchActionState {
  @Trace keyword: string = ''
  @Trace submitSeq: number = 0
  @Trace pendingQuery: string = ''
}

const SEARCH_ACTION_V2_KEY: string = 'v2:searchAction'

/** Returns the app-wide SearchActionState singleton from AppStorageV2. */
export function connectSearchAction(): SearchActionState {
  return AppStorageV2.connect(
    SearchActionState,
    SEARCH_ACTION_V2_KEY,
    () => new SearchActionState(),
  )!
}
