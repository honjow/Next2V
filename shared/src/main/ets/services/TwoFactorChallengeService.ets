import { publishTwoFactorVisible, publishTwoFactorCookie, publishTwoFactorSource } from '../state/TwoFactorState'
import { TwoFactorTrace } from '../diagnostics/TwoFactorTrace'
import { CookieJarSettings } from '../settings/CookieJarSettings'
import { HttpClient } from '../network/HttpClient'

export class TwoFactorChallengeService {
  private static trace: TwoFactorTrace | undefined = undefined
  private static requestedAt: number = 0
  private static pendingCookie: string = ''
  private static activeCookieAtRequest: string = ''
  private static baseUrlAtRequest: string = ''

  static currentTrace(): TwoFactorTrace | undefined { return TwoFactorChallengeService.trace }

  static isCurrent(trace: TwoFactorTrace): boolean { return TwoFactorChallengeService.trace === trace }

  static matchesContext(trace: TwoFactorTrace): boolean {
    return TwoFactorChallengeService.isCurrent(trace) &&
      TwoFactorChallengeService.activeCookieAtRequest === CookieJarSettings.getCurrentCookie() &&
      TwoFactorChallengeService.baseUrlAtRequest === HttpClient.getInstance().getBaseUrl()
  }

  static retryCookie(fallback: string): string { return TwoFactorChallengeService.trace ? TwoFactorChallengeService.pendingCookie : fallback }

  static acceptPersistedSession(trace: TwoFactorTrace, cookie: string): void {
    // Cookie storage can update before a later WebCookie/session/account write fails.
    // Allow that same flow to retry completion without treating its own write as an account switch.
    if (TwoFactorChallengeService.isCurrent(trace) && cookie === CookieJarSettings.getCurrentCookie()) {
      TwoFactorChallengeService.activeCookieAtRequest = cookie
      trace.record('runtime_session_adopted')
    }
  }

  static updateRetry(trace: TwoFactorTrace, cookie: string): void {
    if (!TwoFactorChallengeService.isCurrent(trace)) { return }
    trace.record('retry_state_updated', {
      sessionChanged: cookie !== TwoFactorChallengeService.pendingCookie, sessionPresent: !!cookie,
    })
    TwoFactorChallengeService.pendingCookie = cookie
    publishTwoFactorCookie(cookie)
  }
  // V2-only: the global 2FA challenge sheet state lives solely in the AppStorageV2 'v2:twoFactor' holder
  // (TwoFactorState). This service is its single writer (via the publish* helpers); the @ComponentV2 Index
  // @Monitors visible and reads cookie/source. No legacy V1 AppStorage timestamp breadcrumbs remain — the
  // former write-only TWO_FACTOR_REQUESTED_AT/COMPLETED_AT keys had zero runtime readers and were retired.
  static request(cookie: string, source: string = ''): number {
    if (TwoFactorChallengeService.trace && !TwoFactorChallengeService.matchesContext(TwoFactorChallengeService.trace)) {
      TwoFactorChallengeService.cancel()
    }
    // Concurrent business requests must not overwrite a challenge already being answered.
    if (TwoFactorChallengeService.trace && source !== 'nativeLogin') {
      TwoFactorChallengeService.trace.record('challenge_coalesced', { sourceRoute: TwoFactorTrace.route(source) })
      return TwoFactorChallengeService.requestedAt
    }
    const requestedAt = Date.now()
    TwoFactorChallengeService.requestedAt = requestedAt
    TwoFactorChallengeService.trace = new TwoFactorTrace()
    TwoFactorChallengeService.pendingCookie = cookie
    TwoFactorChallengeService.activeCookieAtRequest = CookieJarSettings.getCurrentCookie()
    TwoFactorChallengeService.baseUrlAtRequest = HttpClient.getInstance().getBaseUrl()
    TwoFactorChallengeService.trace.record('challenge_opened', {
      sourceRoute: TwoFactorTrace.route(source), sessionPresent: !!cookie,
    })
    publishTwoFactorCookie(cookie)
    publishTwoFactorSource(source)
    publishTwoFactorVisible(true)
    return requestedAt
  }

  static complete(): void {
    TwoFactorChallengeService.trace?.record('flow_completed')
    TwoFactorChallengeService.clear()
  }

  static cancel(): void {
    TwoFactorChallengeService.trace?.record('flow_cancelled')
    TwoFactorChallengeService.clear()
  }

  private static clear(): void {
    TwoFactorChallengeService.trace = undefined
    TwoFactorChallengeService.pendingCookie = ''
    TwoFactorChallengeService.activeCookieAtRequest = ''
    TwoFactorChallengeService.baseUrlAtRequest = ''
    publishTwoFactorVisible(false)
    publishTwoFactorCookie('')
    publishTwoFactorSource('')
  }
}
