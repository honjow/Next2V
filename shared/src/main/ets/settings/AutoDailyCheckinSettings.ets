import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  STORE_NAME_SETTINGS,
  SettingsPreferencesStore,
  setAppStorageValue,
} from './SettingsStorage'
import { connectAutoDailyCheckin } from '../state/AutoDailyCheckinState'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_ENABLED: string = StorageKeys.AUTO_DAILY_CHECKIN_ENABLED
const KEY_LAST_ATTEMPT_DATE: string = StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE
const KEY_LAST_ATTEMPT_IDENTITY: string = StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY
const KEY_LAST_SUCCESS_DATE: string = StorageKeys.AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE

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
    setAppStorageValue<boolean>(StorageKeys.AUTO_DAILY_CHECKIN_ENABLED, enabled)
    setAppStorageValue<string>(
      StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE,
      lastAttemptDate || '',
    )
    setAppStorageValue<string>(
      StorageKeys.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY,
      lastAttemptIdentity || '',
    )
    setAppStorageValue<string>(
      StorageKeys.AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE,
      lastSuccessDate || '',
    )
    // V2 mirror dual-write from this single chokepoint; the getters below read the mirror.
    const state = connectAutoDailyCheckin()
    state.enabled = enabled
    state.lastAttemptDate = lastAttemptDate || ''
    state.lastAttemptIdentity = lastAttemptIdentity || ''
    state.lastSuccessDate = lastSuccessDate || ''
  }

  static isEnabled(): boolean {
    // Read the V2 mirror kept in lockstep by apply() (the single chokepoint). Default true.
    return connectAutoDailyCheckin().enabled
  }

  static getLastAttemptDate(): string {
    return connectAutoDailyCheckin().lastAttemptDate
  }

  static getLastAttemptIdentity(): string {
    return connectAutoDailyCheckin().lastAttemptIdentity
  }

  static getLastSuccessDate(): string {
    return connectAutoDailyCheckin().lastSuccessDate
  }

  static async load(context: common.UIAbilityContext): Promise<AutoDailyCheckinSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return AutoDailyCheckinSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read auto check-in settings')
    }
  }

  static async loadFromStore(
    store: SettingsPreferencesStore,
  ): Promise<AutoDailyCheckinSettingsSnapshot> {
    const enabled = store.getSync(KEY_ENABLED, true) as boolean
    const lastAttemptDate = store.getSync(KEY_LAST_ATTEMPT_DATE, '') as string
    const lastAttemptIdentity = store.getSync(KEY_LAST_ATTEMPT_IDENTITY, '') as string
    const lastSuccessDate = store.getSync(KEY_LAST_SUCCESS_DATE, '') as string
    AutoDailyCheckinSettings.apply(enabled, lastAttemptDate, lastAttemptIdentity, lastSuccessDate)
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_setting_loaded', {
      enabled: enabled,
      hasLastAttempt: !!lastAttemptDate,
      hasLastSuccess: !!lastSuccessDate,
    })
    return {
      enabled: enabled,
      lastAttemptDate: lastAttemptDate,
      lastAttemptIdentity: lastAttemptIdentity,
      lastSuccessDate: lastSuccessDate,
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
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_setting_saved', { enabled: enabled })
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'auto_daily_setting_error',
        { operation: 'save' },
        e,
      )
      throw new Error(e.message || 'Failed to save auto check-in settings')
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
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_attempt_state_saved', {
        date: localDate,
        hasIdentityFingerprint: !!lastAttemptIdentity,
      })
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'auto_daily_setting_error',
        { operation: 'saveLastAttemptDate' },
        e,
      )
      throw new Error(e.message || 'Failed to save auto check-in state')
    }
  }

  // Records a confirmed sign-in: the success date AND the account identity that signed (the gate reads both,
  // so a different account's success on the same day does not suppress this one). lastAttemptDate mirrors
  // the date for back-compat; the gate no longer reads it.
  static async saveLastSuccessDate(
    context: common.UIAbilityContext,
    localDate: string,
    identity: string,
  ): Promise<void> {
    const enabled = AutoDailyCheckinSettings.isEnabled()
    AutoDailyCheckinSettings.apply(enabled, localDate, identity, localDate)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ENABLED, enabled)
      store.putSync(KEY_LAST_ATTEMPT_DATE, localDate)
      store.putSync(KEY_LAST_ATTEMPT_IDENTITY, identity)
      store.putSync(KEY_LAST_SUCCESS_DATE, localDate)
      store.flushSync()
      DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_success_state_saved', {
        date: localDate,
      })
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'auto_daily_setting_error',
        { operation: 'saveLastSuccessDate' },
        e,
      )
      throw new Error(e.message || 'Failed to save auto check-in state')
    }
  }
}
