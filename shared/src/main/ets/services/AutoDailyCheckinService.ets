import { common } from '@kit.AbilityKit'
import { AutoDailyCheckinSettings } from '../settings/AutoDailyCheckinSettings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ApiService } from '../network/ApiService'
import type { V2exDailyMission } from '../network/NetworkTypes'

export interface AutoDailyCheckinResult {
  attempted: boolean
  redeemed: boolean
  reason: string
  message: string
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
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_disabled', { source: source })
      return AutoDailyCheckinService.result(false, false, 'disabled', '')
    }
    if (!cleanCookie) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_no_cookie', { source: source })
      return AutoDailyCheckinService.result(false, false, 'no-cookie', '')
    }
    if (AutoDailyCheckinService.inFlight) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_in_flight', { source: source })
      return AutoDailyCheckinService.result(false, false, 'in-flight', '')
    }
    if (AutoDailyCheckinSettings.getLastAttemptDate() === today &&
      AutoDailyCheckinSettings.getLastAttemptIdentity() === attemptIdentity) {
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_skip_already_attempted', {
        source: source,
        date: today,
        identityFingerprint: attemptIdentity
      })
      return AutoDailyCheckinService.result(false, false, 'already-attempted', '')
    }

    AutoDailyCheckinService.inFlight = true
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_attempt_start', {
      source: source,
      date: today,
      identityFingerprint: attemptIdentity
    })
    try {
      await AutoDailyCheckinSettings.saveLastAttemptDate(context, today, attemptIdentity)
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_attempt_saved', { source: source, date: today })
      const mission = await AutoDailyCheckinService.api.getDailyMissionWithCookie(cleanCookie)
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_mission_loaded', {
        source: source,
        canRedeem: mission.canRedeem === true,
        canAttemptRedeem: !!mission.redeemPath,
        messageCode: AutoDailyCheckinService.messageCode(mission.message)
      })
      if (!mission.canRedeem || !mission.redeemPath) {
        const alreadyDone = AutoDailyCheckinService.isAlreadyDoneMessage(mission.message)
        await AutoDailyCheckinService.saveSuccessIfAlreadyDone(context, today, mission)
        DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_not_redeemable', {
          source: source,
          alreadyDone: alreadyDone,
          messageCode: AutoDailyCheckinService.messageCode(mission.message)
        })
        return AutoDailyCheckinService.result(true, false, 'not-redeemable', mission.message)
      }
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_redeem_start', { source: source })
      const redeemedMission = await AutoDailyCheckinService.api.redeemDailyMissionWithCookie(
        cleanCookie,
        mission.redeemPath,
      )
      await AutoDailyCheckinSettings.saveLastSuccessDate(context, today)
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_checkin_redeem_success', {
        source: source,
        messageCode: AutoDailyCheckinService.messageCode(redeemedMission.message)
      })
      return AutoDailyCheckinService.result(true, true, 'redeemed', redeemedMission.message)
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn('auto_daily_checkin', 'auto_daily_checkin_error', { source: source, errorKind: e.name || 'Error' }, e)
      return AutoDailyCheckinService.result(true, false, 'error', e.message || '')
    } finally {
      AutoDailyCheckinService.inFlight = false
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
    return (message || '') === 'already_checked_in_today' || (message || '').indexOf('已签到') >= 0 || (message || '').indexOf('已领取') >= 0 || (message || '').indexOf('已完成') >= 0
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
  ): AutoDailyCheckinResult {
    return { attempted: attempted, redeemed: redeemed, reason: reason, message: message }
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
