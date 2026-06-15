import { AppPrompt } from '../utils/AppPrompt'
import { common } from '@kit.AbilityKit'
import { AutoDailyCheckinSettings } from '../settings/AutoDailyCheckinSettings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ApiService } from '../network/ApiService'
import { HttpClient } from '../network/HttpClient'
import { connectWebCheckinRunner } from '../state/WebCheckinRunnerState'
import { connectAppForeground } from '../state/AppForegroundState'
import { CheckinNotifier } from './CheckinNotifier'
import { AppStrings } from '../i18n/AppStrings'
import type { V2exDailyMission } from '../network/NetworkTypes'

export interface AutoDailyCheckinResult {
  attempted: boolean
  redeemed: boolean
  reason: string
  message: string
  rewardCoins: number
}

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
    const attemptIdentity = AutoDailyCheckinService.cookieAttemptIdentity(cleanCookie)
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
    if (
      AutoDailyCheckinSettings.getLastAttemptDate() === today &&
      AutoDailyCheckinSettings.getLastAttemptIdentity() === attemptIdentity
    ) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_already_attempted', {
        source: source,
        date: today,
        identityFingerprint: attemptIdentity,
      })
      return AutoDailyCheckinService.result(false, false, 'already-attempted', '')
    }

    AutoDailyCheckinService.inFlight = true
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_attempt_start', {
      source: source,
      date: today,
      identityFingerprint: attemptIdentity,
    })
    try {
      // Do NOT write the day breadcrumb up front: a transient mission failure must not burn the whole day.
      // It is persisted below only on a definitive outcome (already-done, or a redeem we actually
      // requested), so a degraded 'daily_checkin_unavailable' / error self-heals on the next app open.
      const mission = await AutoDailyCheckinService.api.getDailyMissionWithCookie(cleanCookie)
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_mission_loaded', {
        source: source,
        canRedeem: mission.canRedeem === true,
        canAttemptRedeem: !!mission.redeemPath,
        messageCode: AutoDailyCheckinService.messageCode(mission.message),
      })
      if (!mission.canRedeem || !mission.redeemPath) {
        const alreadyDone = AutoDailyCheckinService.isAlreadyDoneMessage(mission.message)
        // Only a definitive already-done persists the breadcrumb (saveSuccessIfAlreadyDone). A transient
        // 'daily_checkin_unavailable' persists nothing → the next app open retries.
        await AutoDailyCheckinService.saveSuccessIfAlreadyDone(context, today, mission)
        DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_not_redeemable', {
          source: source,
          alreadyDone: alreadyDone,
          messageCode: AutoDailyCheckinService.messageCode(mission.message),
        })
        return AutoDailyCheckinService.result(true, false, 'not-redeemable', mission.message)
      }
      // Redeemable → mark the day attempted now (so a reopen before handleWebResult persists success does
      // not re-trigger the web redeem).
      await AutoDailyCheckinSettings.saveLastAttemptDate(context, today, attemptIdentity)
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_redeem_request', {
        source: source,
      })
      // The redeem itself can't go over HTTP (V2EX's anti-bot rejects a headless request), so hand off to
      // the globally-mounted hidden ArkWeb runner — a real browser engine that passes the check. It reports
      // back through handleWebResult(), where the last-success breadcrumb + reward toast are written once
      // the navigation has actually claimed.
      AutoDailyCheckinService.requestWebRedeem()
      return AutoDailyCheckinService.result(true, false, 'redeem-requested', mission.message)
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

  // Called by the nav-shell runner when the hidden Web check-in finishes. Persists the success breadcrumb
  // and surfaces the reward toast (auto check-in has no visible caller that would otherwise show it).
  static async handleWebResult(
    context: common.UIAbilityContext,
    status: string,
    rewardCoins: number,
  ): Promise<void> {
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_web_result', {
      status: status,
      rewardCoins: rewardCoins,
    })
    // 'failed' = the Web runner hit V2EX's anti-bot wall / found nothing to claim. It used to return
    // silently, so a blocked day looked identical to a normal one. Surface it so the user can step in.
    if (status === 'failed') {
      AutoDailyCheckinService.surfaceFailure(context)
      return
    }
    if (status !== 'success' && status !== 'already') {
      return
    }
    try {
      await AutoDailyCheckinSettings.saveLastSuccessDate(
        context,
        AutoDailyCheckinService.localDateString(),
      )
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'auto_daily_checkin_web_persist_error',
        { errorKind: e.name || 'Error' },
        e,
      )
    }
    // Only a real claim (status 'success') is worth announcing; 'already' fires on every reopen and would
    // be noise.
    if (status === 'success') {
      AutoDailyCheckinService.surfaceSuccess(context, rewardCoins)
    }
  }

  private static async saveSuccessIfAlreadyDone(
    context: common.UIAbilityContext,
    today: string,
    mission: V2exDailyMission,
  ): Promise<void> {
    const message = mission.message || ''
    if (AutoDailyCheckinService.isAlreadyDoneMessage(message)) {
      await AutoDailyCheckinSettings.saveLastSuccessDate(context, today)
    }
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

  // SUCCESS is the non-actionable case: the day is signed, the account page already shows 已签到, and the
  // user does not need to act. So we DON'T nag with a notification — just a light foreground toast when
  // they happen to be looking. (We still bootstrap notification consent here, while foreground, so a later
  // FAILURE can reach them.) Background success surfaces nothing; the settled 已签到 state is the record.
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
  // claimable), so today is still unsigned and the streak is at risk. This must reach the user even if the
  // app is already backgrounded — so ALWAYS post a persistent, tap-to-open notification (not just a
  // transient toast). A foreground toast is added on top for immediacy. The notification no-ops only if the
  // user has denied notification consent.
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
    let hash = 2166136261
    for (let i = 0; i < cookie.length; i += 1) {
      hash ^= cookie.charCodeAt(i)
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return `${cookie.length}:${hash.toString(16)}`
  }

  private static localDateString(): string {
    const d = new Date()
    const month = `${d.getMonth() + 1}`.padStart(2, '0')
    const day = `${d.getDate()}`.padStart(2, '0')
    return `${d.getFullYear()}-${month}-${day}`
  }
}
