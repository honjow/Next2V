import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the native-login resume signal (`StorageKeys.NATIVE_LOGIN_SHOWN`).
 *
 * One-directional bus: the V1 `Index.ets` writes a `<token>:resume` string
 * (`Index.notifyNativeLoginShown`, the single writer) each time the native-login NavDestination is
 * re-shown, and the `@ComponentV2` `V2exNativeLoginPage` reacts via `@Monitor('<member>.command')`
 * to re-prepare the login challenge if it had been paused. There is no writeback on this key.
 *
 * During the State Management V1->V2 migration the signal lives in BOTH stores at once: the writer
 * dual-writes the V1 `AppStorage` key AND this `@Trace` field so the bridge stays uniform and
 * reversible, mirroring the `NodeTopicActionState` precedent.
 *
 * Transitional: drop the `AppStorage` half once the writer no longer needs it.
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
