import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the global two-factor challenge sheet state (`TWO_FACTOR_VISIBLE` / `_COOKIE` / `_SOURCE`).
 *
 * Written only by `TwoFactorChallengeService` (request/cancel/complete); the migrated `@ComponentV2`
 * `Index` `@Monitor`s `visible` to drive its `bindSheet`, and reads `cookie` / `source` for the prompt.
 * Writers route through the `publish*` helpers (write-through: AppStorage + mirror) so the V1 keys
 * (still read by anything V1) and the mirror never drift. Transitional: drop the AppStorage half once no
 * V1 reader remains.
 */
@ObservedV2
export class TwoFactorState {
  @Trace visible: boolean = false
  @Trace cookie: string = ''
  @Trace source: string = ''
}

const TWO_FACTOR_V2_KEY: string = 'v2:twoFactor'

/** Returns the app-wide TwoFactorState singleton from AppStorageV2. */
export function connectTwoFactor(): TwoFactorState {
  return AppStorageV2.connect(TwoFactorState, TWO_FACTOR_V2_KEY, () => new TwoFactorState())!
}

export function publishTwoFactorVisible(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.TWO_FACTOR_VISIBLE, value)
  connectTwoFactor().visible = value
}
export function publishTwoFactorCookie(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TWO_FACTOR_COOKIE, value)
  connectTwoFactor().cookie = value
}
export function publishTwoFactorSource(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TWO_FACTOR_SOURCE, value)
  connectTwoFactor().source = value
}
