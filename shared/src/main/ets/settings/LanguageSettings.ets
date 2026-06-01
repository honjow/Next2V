import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import i18n from '@ohos.i18n'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'
import { connectLanguageState } from '../state/LanguageState'

export type AppLanguageMode = 'default' | 'zh-Hans' | 'zh-Hant-HK' | 'zh-Hant-TW' | 'en-US' | 'ja-JP' | 'ko-KR'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_LANGUAGE_MODE: string = StorageKeys.LANGUAGE_MODE

export interface LanguageSettingsSnapshot {
  mode: AppLanguageMode
}

export class LanguageSettings {
  static readonly MODE_SYSTEM: AppLanguageMode = 'default'
  static readonly MODE_ZH_CN: AppLanguageMode = 'zh-Hans'
  static readonly MODE_ZH_HK: AppLanguageMode = 'zh-Hant-HK'
  static readonly MODE_ZH_TW: AppLanguageMode = 'zh-Hant-TW'
  static readonly MODE_EN: AppLanguageMode = 'en-US'
  static readonly MODE_JA: AppLanguageMode = 'ja-JP'
  static readonly MODE_KO: AppLanguageMode = 'ko-KR'

  // Cache the last system language applied in follow-system mode.
  // When reapplyForFollowSystem sees the same value, it short-circuits
  // to avoid setAppPreferredLanguage churn that triggers recursive
  // onConfigurationUpdated → reapplyForFollowSystem loops.
  private static lastAppliedFollowSystemLanguage: string = ''

  static apply(areaID: string): LanguageSettingsSnapshot {
    const mode = LanguageSettings.normalizeMode(areaID)
    const normalized = LanguageSettings.resolveTargetLanguage(mode)
    if (normalized) {
      try {
        i18n.System.setAppPreferredLanguage(normalized)
      } catch (error) {
        const e = error as Error
        console.error('setAppPreferredLanguage failed: ' + e.message)
      }
    }
    // Seed the follow-system guard cache so reapplyForFollowSystem
    // does not re-apply the same language on the first Environment callback.
    if (mode === LanguageSettings.MODE_SYSTEM && normalized) {
      LanguageSettings.lastAppliedFollowSystemLanguage = normalized
    }
    setAppStorageValue<AppLanguageMode>(StorageKeys.LANGUAGE_MODE, mode)
    // V2 mirror dual-write: SettingsPage hydration, reapplyForFollowSystem, and
    // AppStrings.currentLanguageMode read this instead of AppStorage.get(LANGUAGE_MODE).
    connectLanguageState().mode = mode
    return { mode }
  }

  // Follow-system mode: resolve the current system language as the concrete
  // value to set. setAppPreferredLanguage('default') cannot clear a previous
  // pin at the OS level, so we must pass the resolved locale explicitly.
  private static resolveTargetLanguage(mode: AppLanguageMode): string {
    if (mode !== LanguageSettings.MODE_SYSTEM) {
      return mode
    }
    try {
      const sys = i18n.System.getSystemLanguage()
      if (sys) {
        return sys
      }
    } catch (_e) {}
    return ''
  }

  // Called by ApplicationContext EnvironmentCallback (application-level async event,
  // outside the Configuration rebuild call chain, so setAppPreferredLanguage is safe).
  static reapplyForFollowSystem(): void {
    const mode = (connectLanguageState().mode || LanguageSettings.MODE_SYSTEM) as string
    if (LanguageSettings.normalizeMode(mode) !== LanguageSettings.MODE_SYSTEM) {
      return
    }
    let sys = ''
    try { sys = i18n.System.getSystemLanguage() } catch (_e) {}
    if (!sys) {
      return
    }
    // Short-circuit: skip if this is the same system language we already applied.
    // Without this guard, every setAppPreferredLanguage(sys) triggers another
    // onConfigurationUpdated callback, which calls reapplyForFollowSystem again,
    // creating an infinite config-change loop that freezes the app.
    if (sys === LanguageSettings.lastAppliedFollowSystemLanguage) {
      return
    }
    try {
      i18n.System.setAppPreferredLanguage(sys)
      LanguageSettings.lastAppliedFollowSystemLanguage = sys
    } catch (error) {
      const e = error as Error
      console.error('reapplyForFollowSystem failed: ' + e.message)
    }
  }

  static async applyLanguage(context: common.UIAbilityContext, areaID: string): Promise<LanguageSettingsSnapshot> {
    const normalized = LanguageSettings.normalizeMode(areaID)
    const snapshot = LanguageSettings.apply(normalized)
    const store = await preferences.getPreferences(context, STORE_NAME)
    store.putSync(KEY_LANGUAGE_MODE, normalized)
    store.flushSync()
    return snapshot
  }

  static async applyStoredPreferredLanguage(context: common.UIAbilityContext): Promise<LanguageSettingsSnapshot> {
    const store = await preferences.getPreferences(context, STORE_NAME)
    return LanguageSettings.applyFromStore(store)
  }

  static async load(context: common.UIAbilityContext): Promise<LanguageSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return LanguageSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read language settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<LanguageSettingsSnapshot> {
    return LanguageSettings.applyFromStore(store)
  }

  static async loadStoredMode(context: common.UIAbilityContext): Promise<AppLanguageMode> {
    const store = await preferences.getPreferences(context, STORE_NAME)
    const stored = store.getSync(KEY_LANGUAGE_MODE, LanguageSettings.MODE_SYSTEM) as string
    return LanguageSettings.normalizeMode(stored)
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    await LanguageSettings.applyLanguage(context, mode)
  }

  static normalizeMode(value: string): AppLanguageMode {
    const mode = (value || '').trim()
    if (mode === LanguageSettings.MODE_SYSTEM ||
      mode === LanguageSettings.MODE_ZH_CN ||
      mode === LanguageSettings.MODE_ZH_HK ||
      mode === LanguageSettings.MODE_ZH_TW ||
      mode === LanguageSettings.MODE_EN ||
      mode === LanguageSettings.MODE_JA ||
      mode === LanguageSettings.MODE_KO) {
      return mode as AppLanguageMode
    }
    // Backward-compatible normalization for values persisted by the discarded restart lane.
    if (mode === 'system') {
      return LanguageSettings.MODE_SYSTEM
    }
    if (mode === 'zh-CN') {
      return LanguageSettings.MODE_ZH_CN
    }
    if (mode === 'zh-HK') {
      return LanguageSettings.MODE_ZH_HK
    }
    if (mode === 'zh-TW') {
      return LanguageSettings.MODE_ZH_TW
    }
    if (mode === 'en') {
      return LanguageSettings.MODE_EN
    }
    if (mode === 'ja') {
      return LanguageSettings.MODE_JA
    }
    if (mode === 'ko') {
      return LanguageSettings.MODE_KO
    }
    return LanguageSettings.MODE_SYSTEM
  }

  static modeText(mode: string): ResourceStr {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    if (normalizedMode === LanguageSettings.MODE_ZH_CN) {
      return AppStrings.R_LANGUAGE_SIMPLIFIED_CHINESE
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_HK) {
      return AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_HK
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_TW) {
      return AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_TW
    }
    if (normalizedMode === LanguageSettings.MODE_EN) {
      return AppStrings.R_LANGUAGE_ENGLISH
    }
    if (normalizedMode === LanguageSettings.MODE_JA) {
      return AppStrings.R_LANGUAGE_JAPANESE
    }
    if (normalizedMode === LanguageSettings.MODE_KO) {
      return AppStrings.R_LANGUAGE_KOREAN
    }
    return AppStrings.R_LANGUAGE_FOLLOW_SYSTEM
  }

  private static applyFromStore(store: SettingsPreferencesStore): LanguageSettingsSnapshot {
    const stored = store.getSync(KEY_LANGUAGE_MODE, LanguageSettings.MODE_SYSTEM) as string
    return LanguageSettings.apply(stored)
  }
}
