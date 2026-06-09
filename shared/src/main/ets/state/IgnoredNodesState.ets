import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the locally-ignored node slugs (lowercase node `name`s, e.g. `['apple', 'gossip']`).
 *
 * This is a DEVICE-GLOBAL, login-independent client-side filter — it is the app's own "hide this node's
 * topics from the aggregate feeds" preference, deliberately NOT the V2EX account-scoped server ignore
 * (unlike the blocked list, which is owner-keyed and synced from V2EX HTML). Keeping it global means it
 * works while logged out and does not reshuffle when switching accounts. `IgnoredNodesSettings` is the
 * single imperative writer (it reassigns `names` and persists to the unified `next2v_settings` store).
 *
 * Readers: `ApiService.applyActiveBlockedTopicFilter` reads `names` imperatively to drop topics whose
 * node is ignored from the home / recent / hot / tab feeds (never from a node's OWN page — an ignored
 * node stays readable, mirroring V2EX). `NodeTopicPage` reports the per-node ignored flag UP to the
 * title bar via `NodeTopicAppbarState`, so the menu does not subscribe to this list directly.
 *
 * No V1 `AppStorage` half: this is a new setting with no `@StorageLink` readers; the mirror is the only
 * live channel.
 */
@ObservedV2
export class IgnoredNodesState {
  @Trace names: string[] = []
}

const IGNORED_NODES_V2_KEY: string = 'v2:ignoredNodes'

/** Returns the app-wide IgnoredNodesState singleton from AppStorageV2. */
export function connectIgnoredNodes(): IgnoredNodesState {
  return AppStorageV2.connect(
    IgnoredNodesState,
    IGNORED_NODES_V2_KEY,
    () => new IgnoredNodesState(),
  )!
}
