import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import i18n from '@ohos.i18n'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
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
      return AppStrings.t(AppStrings.R_COMMON_LIGHT, 'Light')
    }
    if (normalizedMode === THEME_MODE_DARK) {
      return AppStrings.t(AppStrings.R_COMMON_DARK, 'Dark')
    }
    return AppStrings.t(AppStrings.R_COMMON_AUTO, 'Automatic')
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
    // 根因记录（2026-05-24 由 bisect 锁定）：
    // context.setColorMode 触发 Configuration 全量重建，OS 用 system language
    // (zh-Hans) 回填 Configuration.language，ArkUI engine 同步 render locale = zh，
    // 覆盖 setAppPreferredLanguage 设的 app preferred。表现：cold-start tab/Text
    // 显示中文，但 rm.cfg.locale 仍是 en、byName 仍返回 Home（probe 全平）。
    //
    // 防御策略：
    //   A) auto 模式 = COLOR_MODE_NOT_SET，已是系统默认值，不主动调用以避免触发
    //      Configuration 重建（绝大多数用户走此路径，根除冷启动副作用）。
    //   B) Dark/Light 模式仍需调，调完同步 re-pin app preferred language。
    //   C) onConfigurationUpdate 兜底：任何 Configuration 重建都 re-pin（见 EntryAbility）。
    if (mode !== THEME_MODE_DARK && mode !== THEME_MODE_LIGHT) {
      // auto / 未知值：保持系统默认 ColorMode，不调 setColorMode。
      return
    }
    let preferredBefore: string = ''
    try {
      preferredBefore = i18n.System.getAppPreferredLanguage()
    } catch (_e) {
    }
    try {
      if (mode === THEME_MODE_DARK) {
        context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      } else {
        context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
      }
    } catch (error) {
      const e = error as Error
      console.error('apply color mode failed: ' + e.message)
    }
    // Re-pin: setColorMode 已触发 Configuration 重建，立刻把 app preferred 写回。
    try {
      if (preferredBefore && preferredBefore !== 'default') {
        i18n.System.setAppPreferredLanguage(preferredBefore)
        console.info('[i18n][theme-repin] setAppPreferredLanguage(' + preferredBefore + ') after setColorMode(' + mode + ')')
      }
    } catch (_e) {
    }
  }
}
