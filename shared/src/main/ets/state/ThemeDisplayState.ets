import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the effective dark-mode signal (`StorageKeys.THEME_EFFECTIVE_DARK`).
 *
 * `ThemeSettings` is the single AppStorage writer for this key (apply / refreshEffectiveDark /
 * reapplyForFollowSystem). During the State Management V1->V2 backbone migration those paths
 * dual-write: the legacy `AppStorage` key (read by any remaining V1 `@StorageLink`) AND this
 * `@Trace` field (read by `@ComponentV2`, e.g. `MarkdownContent`). Transitional — drop the
 * `AppStorage` half once every effective-dark reader is V2.
 *
 * `mode` mirrors `StorageKeys.THEME_MODE` ('auto' | 'light' | 'dark'): `ThemeSettings.apply()` (the
 * single chokepoint, hit by load/save and SettingsBootstrap.restoreTheme) seeds it, and the migrated
 * readers (SettingsPage hydration, ThemeSettings.refreshEffectiveDark / reapplyForFollowSystem) read it
 * instead of `AppStorage.get`.
 *
 * `systemColorMode` mirrors `StorageKeys.SYSTEM_COLOR_MODE`: the cached REAL system color mode (not the
 * app override after setColorMode), seeded by `ThemeSettings.seedSystemColorMode` (early in onCreate)
 * and updated by `reapplyForFollowSystem(newColorMode)`. The sentinel default marks "not yet seeded" so
 * `getSystemColorMode` falls back to the live `context.config.colorMode`, preserving the prior
 * `AppStorage.get(...) === undefined` behavior. The `setAppStorageValue` projections are kept.
 */
@ObservedV2
export class ThemeDisplayState {
  // Default mirrors the AppStorage default (light); real value published by ThemeSettings.
  @Trace effectiveDark: boolean = false
  // Default mirrors the THEME_MODE default ('auto'); real value published by ThemeSettings.apply().
  @Trace mode: string = 'auto'
  // Sentinel (-100) distinct from ColorMode NOT_SET(-1)/DARK/LIGHT marks "system color mode not yet
  // seeded"; ThemeSettings.getSystemColorMode then falls back to the live context.config.colorMode.
  @Trace systemColorMode: number = -100
}

const THEME_DISPLAY_V2_KEY: string = 'v2:themeDisplay'

/** Returns the app-wide ThemeDisplayState singleton from AppStorageV2. */
export function connectThemeDisplay(): ThemeDisplayState {
  return AppStorageV2.connect(
    ThemeDisplayState,
    THEME_DISPLAY_V2_KEY,
    () => new ThemeDisplayState(),
  )!
}
