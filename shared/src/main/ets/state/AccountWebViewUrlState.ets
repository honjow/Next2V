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
  // The live document <title> of the loaded page, published by AccountWebViewPage's onTitleReceive and
  // read by Index to title the NavDestination. Reset to '' on every new target so a previous page's title
  // never lingers; the title bar falls back to a neutral label until a real <title> arrives.
  @Trace title: string = ''
}

const ACCOUNT_WEB_VIEW_URL_V2_KEY: string = 'v2:accountWebViewUrl'

/** Returns the app-wide AccountWebViewUrlState singleton from AppStorageV2. */
export function connectAccountWebViewUrl(): AccountWebViewUrlState {
  return AppStorageV2.connect(
    AccountWebViewUrlState,
    ACCOUNT_WEB_VIEW_URL_V2_KEY,
    () => new AccountWebViewUrlState(),
  )!
}

export function publishAccountWebViewUrl(value: string): void {
  const holder = connectAccountWebViewUrl()
  holder.url = value
  // New target → clear the previous page's title so the bar shows the neutral fallback until this page's
  // real <title> arrives via onTitleReceive.
  holder.title = ''
}

export function publishAccountWebViewTitle(value: string): void {
  connectAccountWebViewUrl().title = value
}
