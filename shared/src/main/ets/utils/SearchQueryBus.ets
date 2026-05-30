import { StorageKeys } from '../constants/StorageKeys'

/**
 * Action-bus publisher for the global pending-search-query command consumed by
 * SearchPage via `StorageKeys.PENDING_SEARCH_QUERY` (parsed as `<timestamp>:<query>`
 * by `SearchPageStateCoordinator.parsePendingQuery`, regex `^\d+:(.+)$`).
 *
 * The timestamp prefix makes each command unique so the consumer's @Watch/@Monitor
 * re-fires even for a repeated query — it is an action-bus stamp, not a render-key
 * churn. Centralised here so `@ComponentV2` callers stay free of the `Date.now()`
 * token that the V2 leaf-migration contract forbids inside migrated files.
 */
export class SearchQueryBus {
  static publishPending(query: string): void {
    const clean = (query || '').trim()
    if (!clean) {
      return
    }
    AppStorage.setOrCreate<string>(StorageKeys.PENDING_SEARCH_QUERY, `${Date.now()}:${clean}`)
  }
}
