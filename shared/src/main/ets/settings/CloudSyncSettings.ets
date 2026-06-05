import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { connectCloudSync } from '../state/CloudSyncState'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_ENABLED: string = StorageKeys.CLOUD_SYNC_ENABLED

// Persistence + V2-state bridge for the "端云同步" toggle. Default OFF: device-cloud sync is opt-in, so a
// fresh install never marks distributed tables or requests the DISTRIBUTED_DATASYNC permission until the
// user turns it on. apply() is the single chokepoint that publishes `enabled` to the V2 holder.
export class CloudSyncSettings {
  static apply(enabled: boolean): void {
    connectCloudSync().enabled = enabled
  }

  static isEnabled(): boolean {
    return connectCloudSync().enabled
  }

  static async load(context: common.UIAbilityContext): Promise<boolean> {
    const store = await preferences.getPreferences(context, STORE_NAME)
    return CloudSyncSettings.loadFromStore(store)
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<boolean> {
    const enabled = store.getSync(KEY_ENABLED, false) as boolean
    CloudSyncSettings.apply(enabled)
    return enabled
  }

  static async save(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    CloudSyncSettings.apply(enabled)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ENABLED, enabled)
      store.flushSync()
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_setting_saved', { enabled: enabled })
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn('cloud_sync', 'cloud_sync_setting_error', { operation: 'save' }, e)
      throw new Error(e.message || 'Failed to save cloud sync setting')
    }
  }
}
