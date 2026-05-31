import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the pending account-webview target URL (`StorageKeys.ACCOUNT_WEB_VIEW_URL`).
 *
 * Written by `AccountDetailPage` / `AccountWebViewPage` before pushing the web view; the migrated
 * `@ComponentV2` `Index` reads this `@Trace` field to title the account-webview NavDestination. Writers
 * route through `publishAccountWebViewUrl` (write-through: AppStorage + mirror). Transitional: drop the
 * AppStorage half once no V1 `@StorageLink` reads the key.
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
  AppStorage.setOrCreate<string>(StorageKeys.ACCOUNT_WEB_VIEW_URL, value)
  connectAccountWebViewUrl().url = value
}
