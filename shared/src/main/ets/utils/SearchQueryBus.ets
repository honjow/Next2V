import { StorageKeys } from '../constants/StorageKeys'
import { connectSearchAction } from '../state/SearchActionState'

/**
 * Action-bus publisher for the global pending-search-query command consumed by
 * SearchPage via `StorageKeys.PENDING_SEARCH_QUERY` (parsed as `<timestamp>:<query>`
 * by `SearchPageStateCoordinator.parsePendingQuery`, regex `^\d+:(.+)$`).
 *
 * The timestamp prefix makes each command unique so the consumer's @Monitor re-fires
 * even for a repeated query — it is an action-bus stamp, not a render-key churn.
 * Centralised here so `@ComponentV2` callers stay free of the `Date.now()` token that
 * the V2 leaf-migration contract forbids inside migrated files. This is the single
 * dual-write point for the pending-query bus: Index's URL-route handler and
 * TopicDetailPage's in-content search link both route through `publishPending`.
 *
 * During the State Management V1->V2 migration the command lives in BOTH stores at once:
 * the V1 `AppStorage` key (kept for reversibility) AND the `@Trace pendingQuery` field of
 * the `SearchActionState` mirror (read by the `@ComponentV2` SearchPage). The mirror is
 * updated here so the single writer keeps the two stores in lockstep.
 */
export class SearchQueryBus {
  static publishPending(query: string): void {
    const clean = (query || '').trim()
    if (!clean) {
      return
    }
    const command = `${Date.now()}:${clean}`
    AppStorage.setOrCreate<string>(StorageKeys.PENDING_SEARCH_QUERY, command)
    connectSearchAction().pendingQuery = command
  }

  /** Clears the pending-query bus in both stores once SearchPage has consumed it. */
  static clearPending(): void {
    AppStorage.setOrCreate<string>(StorageKeys.PENDING_SEARCH_QUERY, '')
    connectSearchAction().pendingQuery = ''
  }
}
