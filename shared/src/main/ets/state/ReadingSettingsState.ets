import { AppStorageV2 } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'

/**
 * V2 mirror of the reading settings (`StorageKeys.READING_TEXT_SCALE` / `READING_LINE_HEIGHT`
 * / `READING_DENSITY` / `READING_BASE64_DECODE_MODE`).
 *
 * `ReadingSettings.apply()` is the single AppStorage writer for text-scale / line-height /
 * density (every save path — `save`/`saveTypography`/`loadFromStore` — routes through it);
 * base64-decode-mode additionally has `loadFromStore`/`saveBase64DecodeMode` writers that
 * also mirror here. During the State Management V1->V2 backbone migration these dual-write:
 * the legacy `AppStorage` keys (read by any remaining V1 `@StorageLink`/`@StorageProp`) AND
 * these `@Trace` fields (read by `@ComponentV2`, e.g. `MarkdownCodeBlock` / `MarkdownContent`).
 * Transitional — drop the `AppStorage` half once every reading-settings reader is V2.
 *
 * Restore-position is not mirrored here; it gains a field when its V2 reader is migrated.
 */
@ObservedV2
export class ReadingSettingsState {
  // Defaults mirror ReadingSettings.TEXT_SCALE_DEFAULT (1.0) / DENSITY_STANDARD ('standard') /
  // BASE64_MODE_BADGE ('badge'); real values published by ReadingSettings on load/save.
  @Trace textScale: number = 1.0
  @Trace lineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  @Trace density: string = 'standard'
  @Trace base64DecodeMode: string = 'badge'
}

const READING_SETTINGS_V2_KEY: string = 'v2:readingSettings'

/** Returns the app-wide ReadingSettingsState singleton from AppStorageV2. */
export function connectReadingSettings(): ReadingSettingsState {
  return AppStorageV2.connect(
    ReadingSettingsState,
    READING_SETTINGS_V2_KEY,
    () => new ReadingSettingsState(),
  )!
}
