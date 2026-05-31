import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'
import { connectThemeDisplay } from '../state/ThemeDisplayState'

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
    ThemeSettings.publishEffectiveDark(effectiveDark)
    ThemeSettings.applySystemColorMode(context, normalizedMode)
    return { mode: normalizedMode, effectiveDark: effectiveDark }
  }

  static async load(context: common.UIAbilityContext): Promise<ThemeSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ThemeSettings.loadFromStore(store, context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read theme settings')
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
      throw new Error(e.message || 'Failed to save theme settings')
    }
  }

  static refreshEffectiveDark(context: common.UIAbilityContext, colorMode?: ConfigurationConstant.ColorMode): void {
    const mode = ThemeSettings.normalizeMode(AppStorage.get<string>(StorageKeys.THEME_MODE) || THEME_MODE_AUTO)
    ThemeSettings.publishEffectiveDark(ThemeSettings.effectiveDarkForMode(context, mode, colorMode))
  }

  // Single sink for THEME_EFFECTIVE_DARK: dual-writes the legacy AppStorage key (read by any
  // remaining V1 @StorageLink) and the V2 ThemeDisplayState mirror (read by @ComponentV2).
  private static publishEffectiveDark(effectiveDark: boolean): void {
    setAppStorageValue<boolean>(StorageKeys.THEME_EFFECTIVE_DARK, effectiveDark)
    connectThemeDisplay().effectiveDark = effectiveDark
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
      return AppStrings.text(AppStrings.R_COMMON_LIGHT, 'Light')
    }
    if (normalizedMode === THEME_MODE_DARK) {
      return AppStrings.text(AppStrings.R_COMMON_DARK, 'Dark')
    }
    return AppStrings.text(AppStrings.R_COMMON_AUTO, 'Automatic')
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
        ThemeSettings.setColorModeIfChanged(context, ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
        return
      }
      if (mode === THEME_MODE_LIGHT) {
        ThemeSettings.setColorModeIfChanged(context, ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
        return
      }
      // auto: read the independently tracked SYSTEM_COLOR_MODE (the real system value),
      // not context.config.colorMode — the latter reflects the app override after set,
      // which would prevent dark→auto from returning to light.
      const sysMode = ThemeSettings.getSystemColorMode(context)
      if (sysMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        ThemeSettings.setColorModeIfChanged(context, ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
        return
      }
      if (sysMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        ThemeSettings.setColorModeIfChanged(context, ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
        return
      }
      return
    } catch (error) {
      const e = error as Error
      console.error('apply color mode failed: ' + e.message)
    }
  }

  // Only call setColorMode when the target differs from context.config.colorMode,
  // to avoid triggering unnecessary rebuilds.
  private static setColorModeIfChanged(context: common.UIAbilityContext, target: ConfigurationConstant.ColorMode): void {
    if (context.config.colorMode === target) {
      return
    }
    context.setColorMode(target)
  }

  // Called once by EntryAbility early in onCreate (before any setColorMode):
  // snapshots context.config.colorMode as the real system value into AppStorage.
  // The EnvironmentCallback later updates this cache with new colorMode values.
  static seedSystemColorMode(context: common.UIAbilityContext): void {
    setAppStorageValue<number>(StorageKeys.SYSTEM_COLOR_MODE, context.config.colorMode as number)
  }

  private static getSystemColorMode(context: common.UIAbilityContext): ConfigurationConstant.ColorMode {
    const stored = AppStorage.get<number>(StorageKeys.SYSTEM_COLOR_MODE)
    if (stored === ConfigurationConstant.ColorMode.COLOR_MODE_DARK as number) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }
    if (stored === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT as number) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    }
    if (stored === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET as number) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    }
    // Fallback: when not seeded, use context.config.colorMode
    // (only possible before onCreate).
    const live = context.config.colorMode
    if (live === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }
    if (live === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  }

  // Called by ApplicationContext EnvironmentCallback (application-level async event,
  // outside the Configuration rebuild call chain, so setColorMode is safe).
  static reapplyForFollowSystem(context: common.UIAbilityContext, newColorMode?: ConfigurationConstant.ColorMode): void {
    // First, update the cached real system colorMode.
    if (newColorMode !== undefined) {
      setAppStorageValue<number>(StorageKeys.SYSTEM_COLOR_MODE, newColorMode as number)
    }
    const mode = ThemeSettings.normalizeMode(AppStorage.get<string>(StorageKeys.THEME_MODE) || THEME_MODE_AUTO)
    if (mode !== THEME_MODE_AUTO) {
      return
    }
    const sysMode = newColorMode ?? ThemeSettings.getSystemColorMode(context)
    if (sysMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      ThemeSettings.setColorModeIfChanged(context, ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      ThemeSettings.publishEffectiveDark(true)
    } else if (sysMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      ThemeSettings.setColorModeIfChanged(context, ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
      ThemeSettings.publishEffectiveDark(false)
    }
  }
}
