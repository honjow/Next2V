import { common, Want } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import i18n from '@ohos.i18n'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings, type AppLanguageMode } from '../i18n/AppStrings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_LANGUAGE_MODE: string = StorageKeys.LANGUAGE_MODE
const DEFAULT_APP_LANGUAGE: string = 'default'

export interface LanguageSettingsSnapshot {
  mode: AppLanguageMode
}

export class LanguageSettings {
  static readonly MODE_SYSTEM: AppLanguageMode = 'system'
  static readonly MODE_ZH_CN: AppLanguageMode = 'zh-CN'
  static readonly MODE_ZH_HK: AppLanguageMode = 'zh-HK'
  static readonly MODE_ZH_TW: AppLanguageMode = 'zh-TW'
  static readonly MODE_EN: AppLanguageMode = 'en'
  private static restartInProgress: boolean = false

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
    const snapshot = LanguageSettings.apply(context, mode)
    LanguageSettings.alignSystemPreferredLanguage(context, mode)
    return snapshot
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_LANGUAGE_MODE, normalizedMode)
      store.flushSync()
      LanguageSettings.apply(context, normalizedMode)
      LanguageSettings.alignSystemPreferredLanguage(context, normalizedMode)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存语言设置失败')
    }
  }

  static async saveAndRestart(context: common.UIAbilityContext, mode: string): Promise<void> {
    if (LanguageSettings.restartInProgress) {
      return
    }
    LanguageSettings.restartInProgress = true
    try {
      await LanguageSettings.save(context, mode)
      LanguageSettings.restartEntryAbility(context)
    } catch (error) {
      LanguageSettings.restartInProgress = false
      const e = error as Error
      throw new Error(e.message || '切换语言失败')
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

  static preferredLanguageForMode(mode: string): string {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    if (normalizedMode === LanguageSettings.MODE_ZH_CN) {
      return 'zh-Hans-CN'
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_HK) {
      return 'zh-Hant-HK'
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_TW) {
      return 'zh-Hant-TW'
    }
    if (normalizedMode === LanguageSettings.MODE_EN) {
      return 'en'
    }
    return DEFAULT_APP_LANGUAGE
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

  private static alignSystemPreferredLanguage(context: common.UIAbilityContext, mode: AppLanguageMode): void {
    const language = LanguageSettings.preferredLanguageForMode(mode)
    i18n.System.setAppPreferredLanguage(language)
    try {
      context.getApplicationContext().setLanguage(language)
    } catch (error) {
      if (mode !== LanguageSettings.MODE_SYSTEM) {
        const e = error as Error
        console.info('set application language fallback failed: ' + (e.message || 'unknown'))
      }
    }
    try {
      const current = i18n.System.getAppPreferredLanguage()
      if (current !== language) {
        console.info('app preferred language pending: ' + current)
      }
    } catch (_error) {
    }
  }

  private static restartEntryAbility(context: common.UIAbilityContext): void {
    const want: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: context.abilityInfo.name,
    }
    context.getApplicationContext().restartApp(want)
  }
}
