import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_settings'
const KEY_ENABLED: string = 'autoDailyCheckinEnabled'
const KEY_LAST_ATTEMPT_DATE: string = 'autoDailyCheckinLastAttemptDate'
const KEY_LAST_ATTEMPT_IDENTITY: string = 'autoDailyCheckinLastAttemptIdentity'
const KEY_LAST_SUCCESS_DATE: string = 'autoDailyCheckinLastSuccessDate'

export interface AutoDailyCheckinSettingsSnapshot {
  enabled: boolean
  lastAttemptDate: string
  lastAttemptIdentity: string
  lastSuccessDate: string
}

export class AutoDailyCheckinSettings {
  static apply(
    enabled: boolean,
    lastAttemptDate: string = '',
    lastAttemptIdentity: string = '',
    lastSuccessDate: string = '',
  ): void {
    AppStorage.setOrCreate<boolean>(StorageKeys.AUTO_DAILY_CHECKIN_ENABLED, enabled)
    AppStorage.setOrCreate<string>(StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE, lastAttemptDate || '')
    AppStorage.setOrCreate<string>(StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY, lastAttemptIdentity || '')
    AppStorage.setOrCreate<string>(StorageKeys.AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE, lastSuccessDate || '')
  }

  static isEnabled(): boolean {
    return AppStorage.get<boolean>(StorageKeys.AUTO_DAILY_CHECKIN_ENABLED) ?? true
  }

  static getLastAttemptDate(): string {
    return AppStorage.get<string>(StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE) ?? ''
  }

  static getLastAttemptIdentity(): string {
    return AppStorage.get<string>(StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY) ?? ''
  }

  static getLastSuccessDate(): string {
    return AppStorage.get<string>(StorageKeys.AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE) ?? ''
  }

  static async load(context: common.UIAbilityContext): Promise<AutoDailyCheckinSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const enabled = store.getSync(KEY_ENABLED, true) as boolean
      const lastAttemptDate = store.getSync(KEY_LAST_ATTEMPT_DATE, '') as string
      const lastAttemptIdentity = store.getSync(KEY_LAST_ATTEMPT_IDENTITY, '') as string
      const lastSuccessDate = store.getSync(KEY_LAST_SUCCESS_DATE, '') as string
      AutoDailyCheckinSettings.apply(enabled, lastAttemptDate, lastAttemptIdentity, lastSuccessDate)
      return {
        enabled: enabled,
        lastAttemptDate: lastAttemptDate,
        lastAttemptIdentity: lastAttemptIdentity,
        lastSuccessDate: lastSuccessDate,
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取自动签到设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    const lastAttemptDate = AutoDailyCheckinSettings.getLastAttemptDate()
    const lastAttemptIdentity = AutoDailyCheckinSettings.getLastAttemptIdentity()
    const lastSuccessDate = AutoDailyCheckinSettings.getLastSuccessDate()
    AutoDailyCheckinSettings.apply(enabled, lastAttemptDate, lastAttemptIdentity, lastSuccessDate)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ENABLED, enabled)
      store.putSync(KEY_LAST_ATTEMPT_DATE, lastAttemptDate)
      store.putSync(KEY_LAST_ATTEMPT_IDENTITY, lastAttemptIdentity)
      store.putSync(KEY_LAST_SUCCESS_DATE, lastSuccessDate)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存自动签到设置失败')
    }
  }

  static async saveLastAttemptDate(
    context: common.UIAbilityContext,
    localDate: string,
    lastAttemptIdentity: string,
  ): Promise<void> {
    const enabled = AutoDailyCheckinSettings.isEnabled()
    const lastSuccessDate = AutoDailyCheckinSettings.getLastSuccessDate()
    AutoDailyCheckinSettings.apply(enabled, localDate, lastAttemptIdentity, lastSuccessDate)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ENABLED, enabled)
      store.putSync(KEY_LAST_ATTEMPT_DATE, localDate)
      store.putSync(KEY_LAST_ATTEMPT_IDENTITY, lastAttemptIdentity)
      store.putSync(KEY_LAST_SUCCESS_DATE, lastSuccessDate)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存自动签到状态失败')
    }
  }

  static async saveLastSuccessDate(context: common.UIAbilityContext, localDate: string): Promise<void> {
    const enabled = AutoDailyCheckinSettings.isEnabled()
    const lastAttemptIdentity = AutoDailyCheckinSettings.getLastAttemptIdentity()
    AutoDailyCheckinSettings.apply(enabled, localDate, lastAttemptIdentity, localDate)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ENABLED, enabled)
      store.putSync(KEY_LAST_ATTEMPT_DATE, localDate)
      store.putSync(KEY_LAST_ATTEMPT_IDENTITY, lastAttemptIdentity)
      store.putSync(KEY_LAST_SUCCESS_DATE, localDate)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存自动签到状态失败')
    }
  }
}
