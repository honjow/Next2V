import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { connectCloudSync, CloudSyncState } from '../state/CloudSyncState'
import {
  CloudSyncFeature,
  CloudSyncFeatureDef,
  CLOUD_SYNC_FEATURES,
  cloudSyncTablesForFeatures,
} from '../storage/CloudSyncFeatures'

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
    CloudSyncSettings.loadFeaturesFromStore(store)
    const state: CloudSyncState = connectCloudSync()
    state.lastSyncAt = store.getSync(StorageKeys.CLOUD_SYNC_LAST_AT, 0) as number
    state.lastSyncOk = store.getSync(StorageKeys.CLOUD_SYNC_LAST_OK, false) as boolean
    return enabled
  }

  // Record the outcome of a sync attempt: update the in-memory holder AND persist it, so Settings can show
  // the "上次同步:…" line immediately on next open (and after a restart). Best-effort persistence — the
  // holder is updated first so the live UI reacts even if the write fails.
  static async recordLastSync(context: common.UIAbilityContext, ok: boolean): Promise<void> {
    const at: number = Date.now()
    const state: CloudSyncState = connectCloudSync()
    state.lastSyncAt = at
    state.lastSyncOk = ok
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(StorageKeys.CLOUD_SYNC_LAST_AT, at)
      store.putSync(StorageKeys.CLOUD_SYNC_LAST_OK, ok)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn('cloud_sync', 'cloud_sync_setting_error', { operation: 'recordLastSync' }, e)
    }
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

  // ----- Per-feature toggles -----

  static isFeatureEnabled(key: string): boolean {
    const state: CloudSyncState = connectCloudSync()
    if (key === CloudSyncFeature.SEARCH_HISTORY) {
      return state.featSearchHistory
    }
    if (key === CloudSyncFeature.COLLECTIONS) {
      return state.featCollections
    }
    if (key === CloudSyncFeature.RECENT_VIEWS) {
      return state.featRecentViews
    }
    if (key === CloudSyncFeature.READ_PROGRESS) {
      return state.featReadProgress
    }
    if (key === CloudSyncFeature.MARKS) {
      return state.featMarks
    }
    return false
  }

  // The CloudSyncFeature keys that are currently on, in display order.
  static enabledFeatureKeys(): string[] {
    const keys: string[] = []
    CLOUD_SYNC_FEATURES.forEach((def: CloudSyncFeatureDef) => {
      if (CloudSyncSettings.isFeatureEnabled(def.key)) {
        keys.push(def.key)
      }
    })
    return keys
  }

  // The local tables to mark/sync given the current feature selection (plus the always-on catch-all).
  static enabledTables(): string[] {
    return cloudSyncTablesForFeatures(CloudSyncSettings.enabledFeatureKeys())
  }

  static async saveFeature(
    context: common.UIAbilityContext,
    key: string,
    enabled: boolean,
  ): Promise<void> {
    CloudSyncSettings.applyFeature(key, enabled)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(StorageKeys.CLOUD_SYNC_FEATURE_PREFIX + key, enabled)
      store.flushSync()
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_feature_saved', { feature: key, enabled: enabled })
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn('cloud_sync', 'cloud_sync_setting_error', { operation: 'saveFeature' }, e)
      throw new Error(e.message || 'Failed to save cloud sync feature setting')
    }
  }

  // Single writer: maps a CloudSyncFeature key to its @Trace field on the holder. Unknown keys are ignored.
  private static applyFeature(key: string, enabled: boolean): void {
    const state: CloudSyncState = connectCloudSync()
    if (key === CloudSyncFeature.SEARCH_HISTORY) {
      state.featSearchHistory = enabled
    } else if (key === CloudSyncFeature.COLLECTIONS) {
      state.featCollections = enabled
    } else if (key === CloudSyncFeature.RECENT_VIEWS) {
      state.featRecentViews = enabled
    } else if (key === CloudSyncFeature.READ_PROGRESS) {
      state.featReadProgress = enabled
    } else if (key === CloudSyncFeature.MARKS) {
      state.featMarks = enabled
    }
  }

  private static loadFeaturesFromStore(store: SettingsPreferencesStore): void {
    CLOUD_SYNC_FEATURES.forEach((def: CloudSyncFeatureDef) => {
      const value = store.getSync(StorageKeys.CLOUD_SYNC_FEATURE_PREFIX + def.key, true) as boolean
      CloudSyncSettings.applyFeature(def.key, value)
    })
  }
}
