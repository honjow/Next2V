import { StorageKeys } from '../constants/StorageKeys'

export class TwoFactorChallengeService {
  static request(cookie: string, source: string = ''): number {
    const requestedAt = Date.now()
    AppStorage.setOrCreate<string>(StorageKeys.TWO_FACTOR_COOKIE, cookie)
    AppStorage.setOrCreate<string>(StorageKeys.TWO_FACTOR_SOURCE, source)
    AppStorage.setOrCreate<number>(StorageKeys.TWO_FACTOR_REQUESTED_AT, requestedAt)
    AppStorage.setOrCreate<boolean>(StorageKeys.TWO_FACTOR_VISIBLE, true)
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
    AppStorage.setOrCreate<boolean>(StorageKeys.TWO_FACTOR_VISIBLE, false)
    AppStorage.setOrCreate<string>(StorageKeys.TWO_FACTOR_COOKIE, '')
    AppStorage.setOrCreate<string>(StorageKeys.TWO_FACTOR_SOURCE, '')
  }
}
