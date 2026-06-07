import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { connectThemeColor } from '../state/ThemeColorState'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_THEME_COLOR: string = StorageKeys.THEME_COLOR
const THEME_COLOR_GALAXY_BLUE: string = 'galaxyBlue'
const THEME_COLOR_ORANGE_YELLOW: string = 'orangeYellow'
const THEME_COLOR_CAT_BLUE: string = 'catBlue'
const THEME_COLOR_HUAWEI_RED: string = 'huaweiRed'
const THEME_COLOR_ELEGANT_PURPLE: string = 'elegantPurple'
const THEME_COLOR_BILIBILI_PINK: string = 'bilibiliPink'
const THEME_COLOR_GRASS_GREEN: string = 'grassGreen'

export interface ThemeColorOption {
  label: ResourceStr
  value: string
  color: ResourceColor
}

export interface ThemeColorSettingsSnapshot {
  color: string
}

export class ThemeColorSettings {
  static readonly COLOR_GALAXY_BLUE: string = THEME_COLOR_GALAXY_BLUE
  static readonly COLOR_ORANGE_YELLOW: string = THEME_COLOR_ORANGE_YELLOW
  static readonly COLOR_CAT_BLUE: string = THEME_COLOR_CAT_BLUE
  static readonly COLOR_HUAWEI_RED: string = THEME_COLOR_HUAWEI_RED
  static readonly COLOR_ELEGANT_PURPLE: string = THEME_COLOR_ELEGANT_PURPLE
  static readonly COLOR_BILIBILI_PINK: string = THEME_COLOR_BILIBILI_PINK
  static readonly COLOR_GRASS_GREEN: string = THEME_COLOR_GRASS_GREEN
  static readonly DEFAULT_COLOR: string = THEME_COLOR_GALAXY_BLUE

  static options(): ThemeColorOption[] {
    return [
      {
        label: AppStrings.R_THEME_COLOR_GALAXY_BLUE,
        value: THEME_COLOR_GALAXY_BLUE,
        color: '#0958F7',
      },
      {
        label: AppStrings.R_THEME_COLOR_ORANGE_YELLOW,
        value: THEME_COLOR_ORANGE_YELLOW,
        color: '#FE9925',
      },
      {
        label: AppStrings.R_THEME_COLOR_CAT_BLUE,
        value: THEME_COLOR_CAT_BLUE,
        color: '#345483',
      },
      {
        label: AppStrings.R_THEME_COLOR_HUAWEI_RED,
        value: THEME_COLOR_HUAWEI_RED,
        color: '#D9323B',
      },
      {
        label: AppStrings.R_THEME_COLOR_ELEGANT_PURPLE,
        value: THEME_COLOR_ELEGANT_PURPLE,
        color: '#8143D6',
      },
      {
        label: AppStrings.R_THEME_COLOR_BILIBILI_PINK,
        value: THEME_COLOR_BILIBILI_PINK,
        color: '#FB80A5',
      },
      {
        label: AppStrings.R_THEME_COLOR_GRASS_GREEN,
        value: THEME_COLOR_GRASS_GREEN,
        color: '#8ED931',
      },
    ]
  }

  static apply(color: string): ThemeColorSettingsSnapshot {
    const normalized = ThemeColorSettings.normalizeColor(color)
    setAppStorageValue<string>(StorageKeys.THEME_COLOR, normalized)
    connectThemeColor().color = normalized
    return { color: normalized }
  }

  static async load(context: common.UIAbilityContext): Promise<ThemeColorSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ThemeColorSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read theme color settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<ThemeColorSettingsSnapshot> {
    const color = ThemeColorSettings.normalizeColor(
      store.getSync(KEY_THEME_COLOR, THEME_COLOR_GALAXY_BLUE) as string,
    )
    return ThemeColorSettings.apply(color)
  }

  static async save(context: common.UIAbilityContext, color: string): Promise<void> {
    const normalized = ThemeColorSettings.normalizeColor(color)
    ThemeColorSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_THEME_COLOR, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save theme color settings')
    }
  }

  static normalizeColor(color: string): string {
    const value = (color || '').trim()
    if (
      value === THEME_COLOR_ORANGE_YELLOW ||
      value === THEME_COLOR_CAT_BLUE ||
      value === THEME_COLOR_HUAWEI_RED ||
      value === THEME_COLOR_ELEGANT_PURPLE ||
      value === THEME_COLOR_BILIBILI_PINK ||
      value === THEME_COLOR_GRASS_GREEN
    ) {
      return value
    }
    return THEME_COLOR_GALAXY_BLUE
  }

  static label(color: string): ResourceStr {
    const normalized = ThemeColorSettings.normalizeColor(color)
    if (normalized === THEME_COLOR_ORANGE_YELLOW) {
      return AppStrings.R_THEME_COLOR_ORANGE_YELLOW
    }
    if (normalized === THEME_COLOR_CAT_BLUE) {
      return AppStrings.R_THEME_COLOR_CAT_BLUE
    }
    if (normalized === THEME_COLOR_HUAWEI_RED) {
      return AppStrings.R_THEME_COLOR_HUAWEI_RED
    }
    if (normalized === THEME_COLOR_ELEGANT_PURPLE) {
      return AppStrings.R_THEME_COLOR_ELEGANT_PURPLE
    }
    if (normalized === THEME_COLOR_BILIBILI_PINK) {
      return AppStrings.R_THEME_COLOR_BILIBILI_PINK
    }
    if (normalized === THEME_COLOR_GRASS_GREEN) {
      return AppStrings.R_THEME_COLOR_GRASS_GREEN
    }
    return AppStrings.R_THEME_COLOR_GALAXY_BLUE
  }

  static colorValue(color: string): ResourceColor {
    const normalized = ThemeColorSettings.normalizeColor(color)
    if (normalized === THEME_COLOR_ORANGE_YELLOW) {
      return '#FE9925'
    }
    if (normalized === THEME_COLOR_CAT_BLUE) {
      return '#345483'
    }
    if (normalized === THEME_COLOR_HUAWEI_RED) {
      return '#D9323B'
    }
    if (normalized === THEME_COLOR_ELEGANT_PURPLE) {
      return '#8143D6'
    }
    if (normalized === THEME_COLOR_BILIBILI_PINK) {
      return '#FB80A5'
    }
    if (normalized === THEME_COLOR_GRASS_GREEN) {
      return '#8ED931'
    }
    return '#0958F7'
  }

  static currentColor(): ResourceColor {
    return ThemeColorSettings.colorValue(connectThemeColor().color)
  }
}
