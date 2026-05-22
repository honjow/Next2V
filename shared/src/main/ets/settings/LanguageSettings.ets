import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings, type AppLanguageMode } from '../i18n/AppStrings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_LANGUAGE_MODE: string = StorageKeys.LANGUAGE_MODE

export interface LanguageSettingsSnapshot {
  mode: AppLanguageMode
}

export class LanguageSettings {
  static readonly MODE_SYSTEM: AppLanguageMode = 'system'
  static readonly MODE_ZH_CN: AppLanguageMode = 'zh-CN'
  static readonly MODE_ZH_HK: AppLanguageMode = 'zh-HK'
  static readonly MODE_ZH_TW: AppLanguageMode = 'zh-TW'
  static readonly MODE_EN: AppLanguageMode = 'en'

  static apply(context: common.UIAbilityContext, mode: string): LanguageSettingsSnapshot {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    AppStrings.applyLanguageMode(context, normalizedMode)
    setAppStorageValue<AppLanguageMode>(StorageKeys.LANGUAGE_MODE, normalizedMode)
    return { mode: normalizedMode }
  }

  static async load(context: common.UIAbilityContext): Promise<LanguageSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return LanguageSettings.loadFromStore(store, context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取语言设置失败')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore, context: common.UIAbilityContext): Promise<LanguageSettingsSnapshot> {
    const mode = LanguageSettings.normalizeMode(store.getSync(KEY_LANGUAGE_MODE, AppStrings.DEFAULT_LANGUAGE_MODE) as string)
    return LanguageSettings.apply(context, mode)
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    LanguageSettings.apply(context, normalizedMode)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_LANGUAGE_MODE, normalizedMode)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存语言设置失败')
    }
  }

  static normalizeMode(value: string): AppLanguageMode {
    const mode = (value || '').trim()
    if (mode === LanguageSettings.MODE_ZH_CN ||
      mode === LanguageSettings.MODE_ZH_HK ||
      mode === LanguageSettings.MODE_ZH_TW ||
      mode === LanguageSettings.MODE_EN) {
      return mode as AppLanguageMode
    }
    return LanguageSettings.MODE_SYSTEM
  }

  static modeText(mode: string): string {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    if (normalizedMode === LanguageSettings.MODE_ZH_CN) {
      return AppStrings.t(AppStrings.R_LANGUAGE_SIMPLIFIED_CHINESE, 'Simplified Chinese')
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_HK) {
      return AppStrings.t(AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_HK, 'Traditional Chinese (Hong Kong)')
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_TW) {
      return AppStrings.t(AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_TW, 'Traditional Chinese (Taiwan)')
    }
    if (normalizedMode === LanguageSettings.MODE_EN) {
      return AppStrings.t(AppStrings.R_LANGUAGE_ENGLISH, 'English')
    }
    return AppStrings.t(AppStrings.R_LANGUAGE_FOLLOW_SYSTEM, 'Follow system')
  }
}
