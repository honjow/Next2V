import { AppStorageV2 } from '@kit.ArkUI'

// Values mirror the `alternateIcons[].name` entries in AppScope/app.json5, plus the default
// launcher icon (which is represented by cancelling the alternate icon).
export const APP_ICON_DEFAULT: string = 'default'
export const APP_ICON_BLACK: string = 'black_solid'

/**
 * V2 mirror of the launcher app icon selection.
 *
 * The persisted source of truth is the system alternate-icon state (bundleManager.getAlternateIcons),
 * not a preferences key: the launcher keeps the selected icon across launches. AppIconSettings is the
 * single writer of this mirror; the @ComponentV2 SettingsPage connects it so the row label updates
 * as soon as a switch succeeds.
 */
@ObservedV2
export class AppIconState {
  @Trace name: string = APP_ICON_DEFAULT
}

const APP_ICON_V2_KEY: string = 'v2:appIcon'

/** Returns the app-wide AppIconState singleton from AppStorageV2. */
export function connectAppIcon(): AppIconState {
  return AppStorageV2.connect(
    AppIconState,
    APP_ICON_V2_KEY,
    () => new AppIconState(),
  )!
}
