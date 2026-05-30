import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the one-directional account web-view command bus
 * (`StorageKeys.ACCOUNT_WEB_VIEW_ACTION`).
 *
 * `command` mirrors `ACCOUNT_WEB_VIEW_ACTION`: the V1 `Index.ets` title bar writes a
 * `<token>:<action>` string (`Index.sendAccountWebViewAction`, the single writer) when
 * the web-view appbar reload affordance is tapped; the `@ComponentV2`
 * `AccountWebViewPage` reacts via `@Monitor('<member>.command')` to refresh the page.
 *
 * The leading `<token>` (a timestamp) only guarantees the string changes so the bus
 * refires for a repeated action — it is Index's pre-existing command-bus encoding, NOT a
 * key-churn UI workaround. There is no writeback on this key.
 *
 * During the State Management V1->V2 migration the command lives in BOTH stores at once:
 * the writer dual-writes the V1 `AppStorage` key AND the matching `@Trace` field so the
 * bridge stays uniform and reversible, mirroring the `SearchActionState` /
 * `UserProfileActionState` / `NodeTopicActionState` precedents.
 *
 * Transitional: drop the `AppStorage` half once the writer no longer needs it.
 */
@ObservedV2
export class AccountWebViewActionState {
  @Trace command: string = ''
}

const ACCOUNT_WEB_VIEW_ACTION_V2_KEY: string = 'v2:accountWebViewAction'

/** Returns the app-wide AccountWebViewActionState singleton from AppStorageV2. */
export function connectAccountWebViewAction(): AccountWebViewActionState {
  return AppStorageV2.connect(
    AccountWebViewActionState,
    ACCOUNT_WEB_VIEW_ACTION_V2_KEY,
    () => new AccountWebViewActionState(),
  )!
}
