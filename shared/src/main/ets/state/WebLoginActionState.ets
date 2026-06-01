import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 command bus for the web-login appbar (`'v2:webLoginAction'`).
 *
 * One-directional bus: the `@ComponentV2` `Index.ets` web-login title-bar menu writes a `<token>:<action>`
 * string (`Index.sendWebLoginAction`, the single writer) for the save / reload menu items, and the
 * `@ComponentV2` `V2exWebLoginPage` reacts via `@Monitor('<member>.command')` to save or reload.
 * There is no writeback on this command.
 *
 * The legacy V1 `AppStorage` (`webLoginAction`) key + its dual-write were retired once no reader
 * read the V1 half.
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
