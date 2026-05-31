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
 * Only the effective-dark signal is mirrored here; theme mode gains a field when its V2
 * reader is migrated.
 */
@ObservedV2
export class ThemeDisplayState {
  // Default mirrors the AppStorage default (light); real value published by ThemeSettings.
  @Trace effectiveDark: boolean = false
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
