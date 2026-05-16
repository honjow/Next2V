import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_THEME_MODE: string = StorageKeys.THEME_MODE
const THEME_MODE_AUTO: string = 'auto'
const THEME_MODE_LIGHT: string = 'light'
const THEME_MODE_DARK: string = 'dark'

export interface ThemeSettingsSnapshot {
  mode: string
  effectiveDark: boolean
}

export class ThemeSettings {
  static readonly MODE_AUTO: string = THEME_MODE_AUTO
  static readonly MODE_LIGHT: string = THEME_MODE_LIGHT
  static readonly MODE_DARK: string = THEME_MODE_DARK

  static apply(context: common.UIAbilityContext, mode: string): ThemeSettingsSnapshot {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    const effectiveDark = ThemeSettings.effectiveDarkForMode(context, normalizedMode)
    setAppStorageValue<string>(StorageKeys.THEME_MODE, normalizedMode)
    setAppStorageValue<boolean>(StorageKeys.THEME_EFFECTIVE_DARK, effectiveDark)
    ThemeSettings.applySystemColorMode(context, normalizedMode)
    return { mode: normalizedMode, effectiveDark: effectiveDark }
  }

  static async load(context: common.UIAbilityContext): Promise<ThemeSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ThemeSettings.loadFromStore(store, context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取主题设置失败')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore, context: common.UIAbilityContext): Promise<ThemeSettingsSnapshot> {
    const mode = ThemeSettings.normalizeMode(store.getSync(KEY_THEME_MODE, THEME_MODE_AUTO) as string)
    return ThemeSettings.apply(context, mode)
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    ThemeSettings.apply(context, normalizedMode)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_THEME_MODE, normalizedMode)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存主题设置失败')
    }
  }

  static refreshEffectiveDark(context: common.UIAbilityContext, colorMode?: ConfigurationConstant.ColorMode): void {
    const mode = ThemeSettings.normalizeMode(AppStorage.get<string>(StorageKeys.THEME_MODE) || THEME_MODE_AUTO)
    setAppStorageValue<boolean>(StorageKeys.THEME_EFFECTIVE_DARK, ThemeSettings.effectiveDarkForMode(context, mode, colorMode))
  }

  static normalizeMode(value: string): string {
    const mode = (value || '').trim()
    if (mode === THEME_MODE_LIGHT || mode === THEME_MODE_DARK) {
      return mode
    }
    return THEME_MODE_AUTO
  }

  static modeText(mode: string): string {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    if (normalizedMode === THEME_MODE_LIGHT) {
      return '浅色'
    }
    if (normalizedMode === THEME_MODE_DARK) {
      return '深色'
    }
    return '自动'
  }

  private static effectiveDarkForMode(
    context: common.UIAbilityContext,
    mode: string,
    colorMode?: ConfigurationConstant.ColorMode
  ): boolean {
    if (mode === THEME_MODE_DARK) {
      return true
    }
    if (mode === THEME_MODE_LIGHT) {
      return false
    }
    return (colorMode ?? context.config.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
  }

  private static applySystemColorMode(context: common.UIAbilityContext, mode: string): void {
    try {
      if (mode === THEME_MODE_DARK) {
        context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
        return
      }
      if (mode === THEME_MODE_LIGHT) {
        context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
        return
      }
      context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (error) {
      const e = error as Error
      console.error('apply color mode failed: ' + e.message)
    }
  }
}
