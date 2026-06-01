import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 store of the pending account-webview target URL.
 *
 * Written by `AccountDetailPage` / `AccountWebViewPage` before pushing the web view (and read back by
 * `AccountWebViewPage` on appear); the `@ComponentV2` `Index` reads this `@Trace` field to title the
 * account-webview NavDestination. Writers route through `publishAccountWebViewUrl`. V2-only: the legacy
 * `AppStorage` half was retired once every reader moved to this mirror.
 */
@ObservedV2
export class AccountWebViewUrlState {
  @Trace url: string = ''
}

const ACCOUNT_WEB_VIEW_URL_V2_KEY: string = 'v2:accountWebViewUrl'

/** Returns the app-wide AccountWebViewUrlState singleton from AppStorageV2. */
export function connectAccountWebViewUrl(): AccountWebViewUrlState {
  return AppStorageV2.connect(AccountWebViewUrlState, ACCOUNT_WEB_VIEW_URL_V2_KEY, () => new AccountWebViewUrlState())!
}

export function publishAccountWebViewUrl(value: string): void {
  connectAccountWebViewUrl().url = value
}
