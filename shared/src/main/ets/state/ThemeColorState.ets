import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the app theme-color setting (`StorageKeys.THEME_COLOR`).
 *
 * `ThemeColorSettings.apply()` is the single AppStorage writer for this key and dual-writes this
 * holder so @ComponentV2 readers can react without a restart.
 */
@ObservedV2
export class ThemeColorState {
  // Default mirrors ThemeColorSettings.DEFAULT_COLOR ('galaxyBlue'); restored from preferences at startup.
  @Trace color: string = 'galaxyBlue'
}

const THEME_COLOR_V2_KEY: string = 'v2:themeColor'

/** Returns the app-wide ThemeColorState singleton from AppStorageV2. */
export function connectThemeColor(): ThemeColorState {
  return AppStorageV2.connect(
    ThemeColorState,
    THEME_COLOR_V2_KEY,
    () => new ThemeColorState(),
  )!
}
