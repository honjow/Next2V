import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the media image-loading policy (`StorageKeys.MEDIA_AUTO_LOAD_IMAGES` /
 * `MEDIA_ONLY_LOAD_IMAGES_ON_WIFI`).
 *
 * `MediaSettings.apply()` is the single AppStorage writer for these (load/save route through
 * it). During the State Management V1->V2 backbone migration it dual-writes: the legacy
 * `AppStorage` keys (read by any remaining V1 `@StorageLink`) AND these `@Trace` fields (read
 * by `@ComponentV2`, e.g. `MarkdownContent`'s `MarkdownAutoImage`, which `@Monitor`s them to
 * re-evaluate the load policy). Transitional — drop the `AppStorage` half once every
 * media-policy reader is V2.
 */
@ObservedV2
export class MediaSettingsState {
  // Defaults mirror the AppStorage defaults (auto-load on, wifi-only off); real values
  // published by MediaSettings on load/save.
  @Trace autoLoadImages: boolean = true
  @Trace onlyLoadImagesOnWifi: boolean = false
}

const MEDIA_SETTINGS_V2_KEY: string = 'v2:mediaSettings'

/** Returns the app-wide MediaSettingsState singleton from AppStorageV2. */
export function connectMediaSettings(): MediaSettingsState {
  return AppStorageV2.connect(
    MediaSettingsState,
    MEDIA_SETTINGS_V2_KEY,
    () => new MediaSettingsState(),
  )!
}
