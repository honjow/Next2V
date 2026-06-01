import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the reply-display mode (`StorageKeys.REPLY_DISPLAY_MODE`).
 *
 * `ReplyDisplaySettings.apply()` is the single settings chokepoint (load/save route through it, and
 * SettingsBootstrap.restoreReplyDisplay seeds it at startup); it still writes the legacy `AppStorage`
 * key through the shared descriptor (`applyDescriptorValue` -> `setAppStorageValue`) AND seeds this
 * `@Trace` field. The migrated readers — SettingsPage hydration, DetailViewModel, and TopicDetailPage —
 * read this mirror instead of `AppStorage.get`. Default mirrors `ReplyDisplaySettings.MODE_THREAD`.
 */
@ObservedV2
export class ReplyDisplayState {
  @Trace mode: string = 'thread'
}

const REPLY_DISPLAY_V2_KEY: string = 'v2:replyDisplay'

/** Returns the app-wide ReplyDisplayState singleton from AppStorageV2. */
export function connectReplyDisplay(): ReplyDisplayState {
  return AppStorageV2.connect(ReplyDisplayState, REPLY_DISPLAY_V2_KEY, () => new ReplyDisplayState())!
}
