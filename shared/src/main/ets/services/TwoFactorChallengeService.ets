import { publishTwoFactorVisible, publishTwoFactorCookie, publishTwoFactorSource } from '../state/TwoFactorState'

export class TwoFactorChallengeService {
  // V2-only: the global 2FA challenge sheet state lives solely in the AppStorageV2 'v2:twoFactor' holder
  // (TwoFactorState). This service is its single writer (via the publish* helpers); the @ComponentV2 Index
  // @Monitors visible and reads cookie/source. No legacy V1 AppStorage timestamp breadcrumbs remain — the
  // former write-only TWO_FACTOR_REQUESTED_AT/COMPLETED_AT keys had zero runtime readers and were retired.
  static request(cookie: string, source: string = ''): number {
    const requestedAt = Date.now()
    publishTwoFactorCookie(cookie)
    publishTwoFactorSource(source)
    publishTwoFactorVisible(true)
    return requestedAt
  }

  static complete(): void {
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
