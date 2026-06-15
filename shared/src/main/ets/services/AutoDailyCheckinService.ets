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

export interface AutoDailyCheckinResult {
  attempted: boolean
  redeemed: boolean
  reason: string
  message: string
  rewardCoins: number
}

/**
 * Auto daily check-in. There is NO local "signed today" state — V2EX's /mission/daily is the only source of
 * truth. Each run just asks it: if it shows a 领取 button (canRedeem) → redeem; otherwise (already signed /
 * unavailable) → do nothing. A failed / anti-bot-walled redeem records nothing, so the next app open simply
 * tries again (the wall is intermittent). Persisting a local "signed today" flag was the source of a whole
 * class of bugs — a stale/false record would block the entire day even while V2EX still said the check-in
 * was available — and it never belonged here: the server already knows.
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

    AutoDailyCheckinService.inFlight = true
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_attempt_start', {
      source: source,
      identityFingerprint: AutoDailyCheckinService.cookieAttemptIdentity(cleanCookie),
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
        // V2EX shows a claimable 领取 button → redeem. Hand off to the hidden ArkWeb runner (the anti-bot
        // rejects a headless HTTP redeem). The runner reports back through handleWebResult.
        DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_redeem_request', {
          source: source,
        })
        AutoDailyCheckinService.requestWebRedeem()
        return AutoDailyCheckinService.result(true, false, 'redeem-requested', mission.message)
      }

      // Not claimable — already signed today (done) or a degraded/unavailable read. Either way there is
      // nothing to do and nothing to persist; the next open re-checks against the server.
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_not_redeemable', {
        source: source,
        alreadyDone: AutoDailyCheckinService.isAlreadyDoneMessage(mission.message),
        messageCode: AutoDailyCheckinService.messageCode(mission.message),
      })
      return AutoDailyCheckinService.result(true, false, 'not-redeemable', mission.message)
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
  //   success → show the reward toast.   failed → tell the user (so they can step in; next open retries).
  //   already → nothing (no toast). Nothing is persisted in any case — the server stays the source of truth.
  static async handleWebResult(
    context: common.UIAbilityContext,
    status: string,
    rewardCoins: number,
  ): Promise<void> {
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_web_result', {
      status: status,
      rewardCoins: rewardCoins,
    })
    if (status === 'success') {
      AutoDailyCheckinService.surfaceSuccess(context, rewardCoins)
    } else if (status === 'failed') {
      AutoDailyCheckinService.surfaceFailure(context)
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

  // A length+hash fingerprint of the cookie — for the diagnostic log only (never persisted as state).
  private static cookieAttemptIdentity(cookie: string): string {
    const clean = (cookie || '').trim()
    let hash = 2166136261
    for (let i = 0; i < clean.length; i += 1) {
      hash ^= clean.charCodeAt(i)
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return `${clean.length}:${hash.toString(16)}`
  }
}
