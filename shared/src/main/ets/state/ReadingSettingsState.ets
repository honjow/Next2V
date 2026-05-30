import { AppStorageV2 } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'

/**
 * V2 mirror of the reading typography settings (`StorageKeys.READING_TEXT_SCALE` /
 * `READING_LINE_HEIGHT`).
 *
 * `ReadingSettings.apply()` is the single AppStorage writer for these (every save path —
 * `save`/`saveTypography`/`loadFromStore` — routes through it). During the State
 * Management V1->V2 backbone migration it dual-writes: the legacy `AppStorage` keys (read
 * by remaining V1 `@StorageLink`/`@StorageProp`, e.g. `MarkdownContent`) AND these `@Trace`
 * fields (read by `@ComponentV2`, e.g. `MarkdownCodeBlock`). Transitional — drop the
 * `AppStorage` half once every reading-typography reader is V2.
 *
 * Only the markdown-relevant typography keys are mirrored here; density / base64-mode /
 * restore-position are added when their V2 readers are migrated.
 */
@ObservedV2
export class ReadingSettingsState {
  // Default mirrors ReadingSettings.TEXT_SCALE_DEFAULT (1.0); real value published by apply().
  @Trace textScale: number = 1.0
  @Trace lineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
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
