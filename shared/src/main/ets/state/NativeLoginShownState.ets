import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 bus for the native-login resume signal (`'v2:nativeLoginShown'`).
 *
 * One-directional bus: the `@ComponentV2` `Index.ets` writes a `<token>:resume` string
 * (`Index.notifyNativeLoginShown`, the single writer) each time the native-login NavDestination is
 * re-shown, and the `@ComponentV2` `V2exNativeLoginPage` reacts via `@Monitor('<member>.command')`
 * to re-prepare the login challenge if it had been paused. There is no writeback on this signal.
 *
 * The legacy V1 `AppStorage` (`nativeLoginShown`) key + its dual-write were retired once no reader
 * read the V1 half.
 */
@ObservedV2
export class NativeLoginShownState {
  @Trace command: string = ''
}

const NATIVE_LOGIN_SHOWN_V2_KEY: string = 'v2:nativeLoginShown'

/** Returns the app-wide NativeLoginShownState singleton from AppStorageV2. */
export function connectNativeLoginShown(): NativeLoginShownState {
  return AppStorageV2.connect(NativeLoginShownState, NATIVE_LOGIN_SHOWN_V2_KEY, () => new NativeLoginShownState())!
}
