import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the web-login appbar command (`StorageKeys.WEB_LOGIN_ACTION`).
 *
 * One-directional bus: the V1 `Index.ets` web-login title-bar menu writes a `<token>:<action>`
 * string (`Index.sendWebLoginAction`, the single writer) for the save / reload menu items, and the
 * `@ComponentV2` `V2exWebLoginPage` reacts via `@Monitor('<member>.command')` to save or reload.
 * There is no writeback on this key.
 *
 * During the State Management V1->V2 migration the command lives in BOTH stores at once: the writer
 * dual-writes the V1 `AppStorage` key AND this `@Trace` field so the bridge stays uniform and
 * reversible, mirroring the `NodeTopicActionState` precedent.
 *
 * Transitional: drop the `AppStorage` half once the writer no longer needs it.
 */
@ObservedV2
export class WebLoginActionState {
  @Trace command: string = ''
}

const WEB_LOGIN_ACTION_V2_KEY: string = 'v2:webLoginAction'

/** Returns the app-wide WebLoginActionState singleton from AppStorageV2. */
export function connectWebLoginAction(): WebLoginActionState {
  return AppStorageV2.connect(WebLoginActionState, WEB_LOGIN_ACTION_V2_KEY, () => new WebLoginActionState())!
}
