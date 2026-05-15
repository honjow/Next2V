import { common } from '@kit.AbilityKit'
import { AutoDailyCheckinSettings } from '../settings/AutoDailyCheckinSettings'
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
      return AutoDailyCheckinService.result(false, false, 'disabled', '')
    }
    if (!cleanCookie) {
      return AutoDailyCheckinService.result(false, false, 'no-cookie', '')
    }
    if (AutoDailyCheckinService.inFlight) {
      return AutoDailyCheckinService.result(false, false, 'in-flight', '')
    }
    if (AutoDailyCheckinSettings.getLastAttemptDate() === today &&
      AutoDailyCheckinSettings.getLastAttemptIdentity() === attemptIdentity) {
      return AutoDailyCheckinService.result(false, false, 'already-attempted', '')
    }

    AutoDailyCheckinService.inFlight = true
    try {
      await AutoDailyCheckinSettings.saveLastAttemptDate(context, today, attemptIdentity)
      const mission = await AutoDailyCheckinService.api.getDailyMissionWithCookie(cleanCookie)
      if (!mission.canRedeem || !mission.redeemPath) {
        await AutoDailyCheckinService.saveSuccessIfAlreadyDone(context, today, mission)
        return AutoDailyCheckinService.result(true, false, 'not-redeemable', mission.message)
      }
      const redeemedMission = await AutoDailyCheckinService.api.redeemDailyMissionWithCookie(
        cleanCookie,
        mission.redeemPath,
      )
      await AutoDailyCheckinSettings.saveLastSuccessDate(context, today)
      console.info(`auto daily check-in redeemed from ${source}: ${redeemedMission.message || ''}`)
      return AutoDailyCheckinService.result(true, true, 'redeemed', redeemedMission.message)
    } catch (error) {
      const e = error as Error
      console.info(`auto daily check-in skipped from ${source}: ${e.message || 'unknown error'}`)
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
    if (message.indexOf('已签到') >= 0 || message.indexOf('已领取') >= 0 || message.indexOf('已完成') >= 0) {
      await AutoDailyCheckinSettings.saveLastSuccessDate(context, today)
    }
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
