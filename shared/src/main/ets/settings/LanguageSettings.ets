import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import i18n from '@ohos.i18n'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

export type AppLanguageMode = 'default' | 'zh-Hans' | 'zh-Hant-HK' | 'zh-Hant-TW' | 'en-US'

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

  static apply(areaID: string): LanguageSettingsSnapshot {
    const normalized = LanguageSettings.normalizeMode(areaID)
    if (normalized === LanguageSettings.MODE_SYSTEM) {
      LanguageSettings.applyPreferredLanguage(normalized)
    } else {
      i18n.System.setAppPreferredLanguage(normalized)
    }
    setAppStorageValue<AppLanguageMode>(StorageKeys.LANGUAGE_MODE, normalized)
    return { mode: normalized }
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
      mode === LanguageSettings.MODE_EN) {
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
    return AppStrings.R_LANGUAGE_FOLLOW_SYSTEM
  }

  private static applyFromStore(store: SettingsPreferencesStore): LanguageSettingsSnapshot {
    const stored = store.getSync(KEY_LANGUAGE_MODE, LanguageSettings.MODE_SYSTEM) as string
    return LanguageSettings.apply(stored)
  }

  private static applyPreferredLanguage(mode: AppLanguageMode): void {
    if (mode !== LanguageSettings.MODE_SYSTEM) {
      i18n.System.setAppPreferredLanguage(mode)
      return
    }

    let systemLanguage = ''
    try {
      systemLanguage = i18n.System.getSystemLanguage()
    } catch (_error) {
    }

    if (systemLanguage) {
      i18n.System.setAppPreferredLanguage(systemLanguage)
    }
    i18n.System.setAppPreferredLanguage(LanguageSettings.MODE_SYSTEM)
  }
}
