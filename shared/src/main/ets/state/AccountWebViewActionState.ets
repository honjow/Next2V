import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 command bus for the account web-view appbar (`'v2:accountWebViewAction'`).
 *
 * `command`: the `@ComponentV2` `Index.ets` title bar writes a `<token>:<action>` string
 * (`Index.sendAccountWebViewAction`, the single writer) when the web-view appbar reload
 * affordance is tapped; the `@ComponentV2` `AccountWebViewPage` reacts via
 * `@Monitor('<member>.command')` to refresh the page.
 *
 * The leading `<token>` (a timestamp) only guarantees the string changes so the bus
 * refires for a repeated action — it is Index's pre-existing command-bus encoding, NOT a
 * key-churn UI workaround. There is no writeback on this command.
 *
 * The legacy V1 `AppStorage` (`accountWebViewAction`) key + its dual-write were retired
 * once no reader read the V1 half. (The separate `ACCOUNT_WEB_VIEW_URL` key is unrelated
 * and still an imperative AppStorage read in `AccountWebViewPage`.)
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
