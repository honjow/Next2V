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
 * `restorePosition` mirrors `StorageKeys.READING_RESTORE_POSITION`; `ReadingSettings.apply()` (which
 * takes the restore flag) and `saveRestorePosition()` seed it, and its V2 readers (SettingsPage
 * hydration, ReadingSettings.save/saveTypography current-value reads, TopicDetailPage restore) consume
 * this field instead of `AppStorage.get`. The `setAppStorageValue` projection of the key is kept.
 */
@ObservedV2
export class ReadingSettingsState {
  // Defaults mirror ReadingSettings.TEXT_SCALE_DEFAULT (1.0) / DENSITY_STANDARD ('standard') /
  // BASE64_MODE_BADGE ('badge') / restore-position off; real values published by ReadingSettings.
  @Trace textScale: number = 1.0
  @Trace lineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  @Trace density: string = 'standard'
  @Trace base64DecodeMode: string = 'badge'
  @Trace restorePosition: boolean = false
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
