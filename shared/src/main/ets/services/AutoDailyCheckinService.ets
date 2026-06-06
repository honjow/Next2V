import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { AutoDailyCheckinSettings } from '../settings/AutoDailyCheckinSettings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ApiService } from '../network/ApiService'
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
        await AutoDailyCheckinService.saveSuccessIfAlreadyDone(
          context,
          today,
          attemptIdentity,
          mission,
        )
        DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_not_redeemable', {
          source: source,
          alreadyDone: alreadyDone,
          messageCode: AutoDailyCheckinService.messageCode(mission.message),
        })
        return AutoDailyCheckinService.result(true, false, 'not-redeemable', mission.message)
      }
      // Redeem over plain HTTP (the same path the manual check-in uses; the hidden-WebView runner is gone).
      // V2EX intermittently serves an anti-abuse wall on the redeem endpoint ("请用一个干净安装的浏览器重试");
      // redeemDailyMissionWithCookie surfaces that as a thrown error (the page is still claimable afterwards),
      // caught below. The day breadcrumb is persisted ONLY on a confirmed claim — a walled / failed redeem
      // leaves no breadcrumb, so the next app open retries instead of burning the whole day.
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_redeem_request', {
        source: source,
      })
      const redeemed = await AutoDailyCheckinService.api.redeemDailyMissionWithCookie(cleanCookie)
      const claimed = !redeemed.mission.canRedeem
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_redeem_result', {
        source: source,
        claimed: claimed,
        reward: redeemed.rewardCoins,
      })
      if (claimed) {
        await AutoDailyCheckinSettings.saveLastSuccessDate(context, today)
        await AutoDailyCheckinSettings.saveLastAttemptDate(context, today, attemptIdentity)
        AutoDailyCheckinService.showRewardToast(redeemed.rewardCoins)
        return AutoDailyCheckinService.result(
          true,
          true,
          'redeemed',
          redeemed.mission.message,
          redeemed.rewardCoins,
        )
      }
      return AutoDailyCheckinService.result(true, false, 'redeem-failed', redeemed.mission.message)
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

  private static async saveSuccessIfAlreadyDone(
    context: common.UIAbilityContext,
    today: string,
    attemptIdentity: string,
    mission: V2exDailyMission,
  ): Promise<void> {
    const message = mission.message || ''
    if (AutoDailyCheckinService.isAlreadyDoneMessage(message)) {
      await AutoDailyCheckinSettings.saveLastSuccessDate(context, today)
      // Also stamp the gate breadcrumb so a reopen skips the redundant mission re-check for the rest of today.
      await AutoDailyCheckinSettings.saveLastAttemptDate(context, today, attemptIdentity)
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

  // User-facing feedback for a successful AUTO check-in (it runs post-login with no UI caller that would
  // otherwise surface it). Shows the 铜币 reward when known, else a plain success.
  private static showRewardToast(rewardCoins: number): void {
    const message =
      rewardCoins > 0
        ? AppStrings.format(
            AppStrings.text(AppStrings.R_DAILY_CHECKIN_REWARD_TOAST, 'Checked in: +{0} bronze'),
            [`${rewardCoins}`],
          )
        : AppStrings.text(AppStrings.R_CHECKIN_COMPLETED, 'Check-in completed')
    promptAction.openToast({ message: message }).catch((_error: Error) => {})
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
