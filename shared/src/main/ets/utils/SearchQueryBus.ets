import { connectSearchAction } from '../state/SearchActionState'

/**
 * Action-bus publisher for the global pending-search-query command consumed by SearchPage via the
 * `@Trace pendingQuery` field of the `SearchActionState` mirror (parsed as `<timestamp>:<query>` by
 * `SearchPageStateCoordinator.parsePendingQuery`, regex `^\d+:(.+)$`).
 *
 * The timestamp prefix makes each command unique so the consumer's @Monitor re-fires even for a
 * repeated query — it is an action-bus stamp, not a render-key churn. Centralised here so `@ComponentV2`
 * callers stay free of the `Date.now()` token that the V2 leaf-migration contract forbids inside
 * migrated files. This is the single writer of the pending-query bus: Index's URL-route handler and
 * TopicDetailPage's in-content search link both route through `publishPending`.
 *
 * V2-only: the command lives solely in the `SearchActionState` mirror (read by the `@ComponentV2`
 * SearchPage); the legacy `AppStorage` half was retired once no reader read the V1 key.
 */
export class SearchQueryBus {
  static publishPending(query: string): void {
    const clean = (query || '').trim()
    if (!clean) {
      return
    }
    const command = `${Date.now()}:${clean}`
    connectSearchAction().pendingQuery = command
  }

  /** Clears the pending-query bus once SearchPage has consumed it. */
  static clearPending(): void {
    connectSearchAction().pendingQuery = ''
  }
}
