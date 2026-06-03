import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Command bus that asks the globally-mounted hidden ArkWeb runner to perform a daily check-in. V2EX's
 * /mission/daily/redeem is guarded by a TLS/JS-fingerprint anti-bot that a headless HTTP redeem cannot
 * pass, so the AUTO check-in path (which runs at login / startup with no visible UI) can only redeem
 * through a real Web engine. `AutoDailyCheckinService` bumps `requestId` after it has decided a redeem
 * is due; the runner mounted in the nav shell reacts via @Monitor and reports back through
 * `AutoDailyCheckinService.handleWebResult`. Single-writer: only the service mutates this holder.
 */
@ObservedV2
export class WebCheckinRunnerState {
  // Bump to a new positive value to request a run.
  @Trace requestId: number = 0
  @Trace baseUrl: string = 'https://www.v2ex.com'
}

const WEB_CHECKIN_RUNNER_V2_KEY: string = 'v2:webCheckinRunner'

/** Returns the app-wide WebCheckinRunnerState singleton from AppStorageV2. */
export function connectWebCheckinRunner(): WebCheckinRunnerState {
  return AppStorageV2.connect(
    WebCheckinRunnerState,
    WEB_CHECKIN_RUNNER_V2_KEY,
    () => new WebCheckinRunnerState(),
  )!
}
