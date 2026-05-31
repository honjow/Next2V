import { StorageKeys } from '../constants/StorageKeys'
import { publishTwoFactorVisible, publishTwoFactorCookie, publishTwoFactorSource } from '../state/TwoFactorState'

export class TwoFactorChallengeService {
  // Write-through helpers keep the V1 TWO_FACTOR_* AppStorage keys and the V2 TwoFactorState mirror
  // (read/@Monitor by the @ComponentV2 Index bindSheet) in lockstep from this single service.
  static request(cookie: string, source: string = ''): number {
    const requestedAt = Date.now()
    publishTwoFactorCookie(cookie)
    publishTwoFactorSource(source)
    AppStorage.setOrCreate<number>(StorageKeys.TWO_FACTOR_REQUESTED_AT, requestedAt)
    publishTwoFactorVisible(true)
    return requestedAt
  }

  static complete(): void {
    AppStorage.setOrCreate<number>(StorageKeys.TWO_FACTOR_COMPLETED_AT, Date.now())
    TwoFactorChallengeService.clear()
  }

  static cancel(): void {
    TwoFactorChallengeService.clear()
  }

  private static clear(): void {
    publishTwoFactorVisible(false)
    publishTwoFactorCookie('')
    publishTwoFactorSource('')
  }
}
