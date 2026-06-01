import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 store of the global two-factor challenge sheet state (visible / cookie / source).
 *
 * Written only by `TwoFactorChallengeService` (request/cancel/complete); the migrated `@ComponentV2`
 * `Index` `@Monitor`s `visible` to drive its `bindSheet`, and reads `cookie` / `source` for the prompt.
 * Writers route through the `publish*` helpers so this single `@Trace` mirror stays authoritative.
 * V2-only: the legacy `AppStorage` half was retired once every reader moved here (`Index` is the sole
 * reader and reads this mirror via `connectTwoFactor()`).
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
  connectTwoFactor().visible = value
}
export function publishTwoFactorCookie(value: string): void {
  connectTwoFactor().cookie = value
}
export function publishTwoFactorSource(value: string): void {
  connectTwoFactor().source = value
}
