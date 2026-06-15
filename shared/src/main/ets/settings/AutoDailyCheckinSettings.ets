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

export interface AutoDailyCheckinSettingsSnapshot {
  enabled: boolean
}

/**
 * Persists ONLY the auto check-in on/off toggle. There is no local "signed today" / "last attempt" state —
 * V2EX's /mission/daily is the source of truth for whether the check-in is still available, so the service
 * asks it live each run instead of trusting a local breadcrumb (which used to go stale and block the day).
 */
export class AutoDailyCheckinSettings {
  static apply(enabled: boolean): void {
    setAppStorageValue<boolean>(StorageKeys.AUTO_DAILY_CHECKIN_ENABLED, enabled)
    connectAutoDailyCheckin().enabled = enabled
  }

  static isEnabled(): boolean {
    // Read the V2 mirror kept in lockstep by apply() (the single chokepoint). Default true.
    return connectAutoDailyCheckin().enabled
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
    AutoDailyCheckinSettings.apply(enabled)
    DiagnosticLogger.info('auto_daily_checkin', 'auto_daily_setting_loaded', { enabled: enabled })
    return { enabled: enabled }
  }

  static async save(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    AutoDailyCheckinSettings.apply(enabled)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ENABLED, enabled)
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
}
