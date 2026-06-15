import { AppPrompt } from '../utils/AppPrompt'
import { common } from '@kit.AbilityKit'
import { AutoDailyCheckinSettings } from '../settings/AutoDailyCheckinSettings'
import { CookieJarSettings } from '../settings/CookieJarSettings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ApiService } from '../network/ApiService'
import { HttpClient } from '../network/HttpClient'
import { connectWebCheckinRunner } from '../state/WebCheckinRunnerState'
import { connectAppForeground } from '../state/AppForegroundState'
import { CheckinNotifier } from './CheckinNotifier'
import { AppStrings } from '../i18n/AppStrings'

export interface AutoDailyCheckinResult {
  attempted: boolean
  redeemed: boolean
  reason: string
  message: string
  rewardCoins: number
}

/**
 * Auto daily check-in, built around ONE piece of state: "has THIS account already succeeded today?"
 * (lastSuccessDate + identity). The rules:
 *   - Skip only when today is already signed for this account.
 *   - Otherwise actually try: load /mission/daily; if redeemable, hand the redeem to the hidden ArkWeb
 *     runner (V2EX's anti-bot rejects a headless HTTP redeem); record success only when the runner confirms
 *     a real claim (handleWebResult).
 *   - A failed / anti-bot-walled attempt records NOTHING — so the next app open simply tries again (the
 *     wall is intermittent). No "attempted" breadcrumb that could burn the day on a transient failure.
 */
export class AutoDailyCheckinService {
  private static inFlight: boolean = false
  private static api: ApiService = new ApiService()

  static async tryCheckin(
    context: common.UIAbilityContext,
    cookie: string,
    source: string = 'unknown',
  ): Promise<AutoDailyCheckinResult> {
    const cleanCookie = (cookie || '').trim()
    const today = AutoDailyCheckinService.localDateString()
    const identity = AutoDailyCheckinService.cookieAttemptIdentity(cleanCookie)

    if (!AutoDailyCheckinSettings.isEnabled()) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_disabled', {
        source: source,
      })
      return AutoDailyCheckinService.result(false, false, 'disabled', '')
    }
    if (!cleanCookie) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_no_cookie', {
        source: source,
      })
      return AutoDailyCheckinService.result(false, false, 'no-cookie', '')
    }
    if (AutoDailyCheckinService.inFlight) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_in_flight', {
        source: source,
      })
      return AutoDailyCheckinService.result(false, false, 'in-flight', '')
    }
    // The ONE gate: already signed today for this account → nothing to do. (A failed attempt recorded
    // nothing, so it is NOT skipped — it retries.)
    if (AutoDailyCheckinService.isSignedToday(today, identity)) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_signed', {
        source: source,
        date: today,
        identityFingerprint: identity,
      })
      return AutoDailyCheckinService.result(false, false, 'already-signed', '')
    }

    AutoDailyCheckinService.inFlight = true
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_attempt_start', {
      source: source,
      date: today,
      identityFingerprint: identity,
    })
    try {
      const mission = await AutoDailyCheckinService.api.getDailyMissionWithCookie(cleanCookie)
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_mission_loaded', {
        source: source,
        canRedeem: mission.canRedeem === true,
        canAttemptRedeem: !!mission.redeemPath,
        messageCode: AutoDailyCheckinService.messageCode(mission.message),
      })

      if (mission.canRedeem && mission.redeemPath) {
        // Hand off to the hidden ArkWeb runner. Persist NOTHING here — success is recorded only when
        // handleWebResult confirms a real claim, so a walled redeem leaves today open for a retry.
        DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_redeem_request', {
          source: source,
        })
        AutoDailyCheckinService.requestWebRedeem()
        return AutoDailyCheckinService.result(true, false, 'redeem-requested', mission.message)
      }

      // Not redeemable. Only a DEFINITIVE already-done counts as signed; a degraded / 'unavailable' read
      // records nothing and retries on the next open.
      if (AutoDailyCheckinService.isAlreadyDoneMessage(mission.message)) {
        await AutoDailyCheckinService.markSignedToday(context, today, identity)
        DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_not_redeemable', {
          source: source,
          alreadyDone: true,
          messageCode: AutoDailyCheckinService.messageCode(mission.message),
        })
        return AutoDailyCheckinService.result(true, false, 'already-signed', mission.message)
      }
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_not_redeemable', {
        source: source,
        alreadyDone: false,
        messageCode: AutoDailyCheckinService.messageCode(mission.message),
      })
      return AutoDailyCheckinService.result(true, false, 'unavailable', mission.message)
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'auto_daily_checkin_error',
        { source: source, errorKind: e.name || 'Error' },
        e,
      )
      return AutoDailyCheckinService.result(true, false, 'error', e.message || '')
    } finally {
      AutoDailyCheckinService.inFlight = false
    }
  }

  // Ask the nav-shell hidden Web runner to perform the redeem for the current account (whose cookie the
  // runner restores into the Web cookie jar). Fire-and-forget — the result returns via handleWebResult().
  private static requestWebRedeem(): void {
    const runner = connectWebCheckinRunner()
    runner.baseUrl = HttpClient.getInstance().getBaseUrl()
    runner.requestId = runner.requestId + 1
  }

  // Called by the nav-shell runner when the hidden Web check-in finishes.
  //   success / already → record "signed today" (success also shows the reward toast).
  //   failed            → record NOTHING (so the next open retries the intermittent wall) + tell the user.
  static async handleWebResult(
    context: common.UIAbilityContext,
    status: string,
    rewardCoins: number,
  ): Promise<void> {
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_web_result', {
      status: status,
      rewardCoins: rewardCoins,
    })
    if (status === 'success' || status === 'already') {
      const today = AutoDailyCheckinService.localDateString()
      const identity = AutoDailyCheckinService.cookieAttemptIdentity(
        CookieJarSettings.getCurrentCookie(),
      )
      try {
        await AutoDailyCheckinService.markSignedToday(context, today, identity)
      } catch (error) {
        const e = error as Error
        DiagnosticLogger.warn(
          'auto_daily_checkin',
          'auto_daily_checkin_web_persist_error',
          { errorKind: e.name || 'Error' },
          e,
        )
      }
      // Only a real claim ('success') is worth announcing; 'already' fires on every reopen and would be noise.
      if (status === 'success') {
        AutoDailyCheckinService.surfaceSuccess(context, rewardCoins)
      }
      return
    }
    // 'failed' = the Web runner hit V2EX's anti-bot wall / found nothing to claim. Persist nothing; surface
    // it so the user can step in.
    AutoDailyCheckinService.surfaceFailure(context)
  }

  // The single source of truth for "this account is done for today".
  private static isSignedToday(today: string, identity: string): boolean {
    return (
      AutoDailyCheckinSettings.getLastSuccessDate() === today &&
      AutoDailyCheckinSettings.getLastAttemptIdentity() === identity
    )
  }

  // Record a confirmed sign-in for this account today — the ONLY state this service persists.
  private static async markSignedToday(
    context: common.UIAbilityContext,
    today: string,
    identity: string,
  ): Promise<void> {
    await AutoDailyCheckinSettings.saveLastSuccessDate(context, today, identity)
  }

  private static isAlreadyDoneMessage(message: string): boolean {
    return (
      (message || '') === 'already_checked_in_today' ||
      (message || '').indexOf('已签到') >= 0 ||
      (message || '').indexOf('已领取') >= 0 ||
      (message || '').indexOf('已完成') >= 0
    )
  }

  private static messageCode(message: string): string {
    const clean = (message || '').trim()
    if (!clean) {
      return ''
    }
    if (AutoDailyCheckinService.isAlreadyDoneMessage(clean)) {
      return 'already_done'
    }
    if (clean.indexOf('成功') >= 0 || clean.indexOf('领取') >= 0) {
      return 'success'
    }
    return 'message_present'
  }

  private static result(
    attempted: boolean,
    redeemed: boolean,
    reason: string,
    message: string,
    rewardCoins: number = 0,
  ): AutoDailyCheckinResult {
    return {
      attempted: attempted,
      redeemed: redeemed,
      reason: reason,
      message: message,
      rewardCoins: rewardCoins,
    }
  }

  // SUCCESS is the non-actionable case: the day is signed and the account page shows 已签到. Just a light
  // foreground toast when the user is looking; no nagging notification. (We bootstrap notification consent
  // here, while foreground, so a later FAILURE can reach them.)
  private static surfaceSuccess(context: common.UIAbilityContext, rewardCoins: number): void {
    CheckinNotifier.ensureEnabled(context)
    if (!connectAppForeground().foreground) {
      return
    }
    const text =
      rewardCoins > 0
        ? AppStrings.format(
            AppStrings.text($r('app.string.daily_checkin_reward_toast'), 'Checked in: +{0} bronze'),
            [`${rewardCoins}`],
          )
        : AppStrings.text($r('app.string.checkin_completed'), 'Check-in completed')
    AppPrompt.openToast({ message: text }).catch((_error: Error) => {})
  }

  // FAILURE is the actionable case: the redeem was attempted but did NOT claim (anti-bot wall / nothing
  // claimable), so today is still unsigned. Reach the user even if the app is already backgrounded — ALWAYS
  // post a persistent, tap-to-open notification; a foreground toast is added on top for immediacy.
  private static surfaceFailure(context: common.UIAbilityContext): void {
    const title = AppStrings.text($r('app.string.daily_checkin_notify_title'), 'Daily check-in')
    const text = AppStrings.text(
      $r('app.string.daily_checkin_failed_toast'),
      "Today's auto check-in didn't go through — open the app to check in manually",
    )
    CheckinNotifier.ensureEnabled(context)
    CheckinNotifier.publish(title, text)
    if (connectAppForeground().foreground) {
      AppPrompt.openToast({ message: text }).catch((_error: Error) => {})
    }
  }

  private static cookieAttemptIdentity(cookie: string): string {
    const clean = (cookie || '').trim()
    let hash = 2166136261
    for (let i = 0; i < clean.length; i += 1) {
      hash ^= clean.charCodeAt(i)
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return `${clean.length}:${hash.toString(16)}`
  }

  private static localDateString(): string {
    const d = new Date()
    const month = `${d.getMonth() + 1}`.padStart(2, '0')
    const day = `${d.getDate()}`.padStart(2, '0')
    return `${d.getFullYear()}-${month}-${day}`
  }
}
