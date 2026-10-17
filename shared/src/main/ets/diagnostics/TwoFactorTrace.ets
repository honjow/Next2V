import { DiagnosticLogger } from './DiagnosticLogger'
import { DiagnosticContextObject } from './DiagnosticsRedactor'

// Correlation IDs are independent of credentials. Never hash or serialize a code,
// nonce, Cookie value, response body, or untrusted exception into this journal.
export class TwoFactorTrace {
  private static sequence: number = 0
  readonly flowId: string
  attempt: number = 0
  stage: string = 'challenge'

  constructor() {
    TwoFactorTrace.sequence += 1
    this.flowId = `2fa-${Date.now()}-${TwoFactorTrace.sequence}`
  }

  record(event: string, facts: DiagnosticContextObject = {}, failed: boolean = false): void {
    facts.schemaVersion = 1
    facts.flowId = this.flowId
    facts.attempt = this.attempt
    facts.stage = this.stage
    if (failed) {
      DiagnosticLogger.warn('two_factor', event, facts)
    } else {
      DiagnosticLogger.info('two_factor', event, facts)
    }
  }

  static route(value: string): string {
    const path = value.replace(/^https?:\/\/[^/]+/i, '').split(/[?#]/)[0]
    if (path === '/2fa') { return '2fa' }
    if (path === '/signin' || path.startsWith('/signin/')) { return 'signin' }
    if (path === '/balance') { return 'balance' }
    if (path === '/settings') { return 'settings' }
    if (path === '/notifications') { return 'notifications' }
    if (path.startsWith('/t/')) { return 'topic' }
    if (path.startsWith('/go/')) { return 'node' }
    if (value === 'nativeLogin') { return 'native_login' }
    return path ? 'other' : 'none'
  }

  static problemKind(message: string): string {
    if (!message) { return 'none' }
    if (/频繁|稍后|too many|rate.limit/i.test(message)) { return 'rate_limited' }
    if (/过期|expired/i.test(message)) { return 'expired' }
    if (/验证码|verification|code|otp/i.test(message)) { return 'verification_rejected' }
    return 'other_server_problem'
  }
}
