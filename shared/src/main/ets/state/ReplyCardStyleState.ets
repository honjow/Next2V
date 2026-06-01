import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the reply-card density setting (`StorageKeys.REPLY_CARD_STYLE`:
 * 'standard' | 'compact').
 *
 * `ReplyCardStyleSettings.apply()` is the single writer for this mirror — both the startup
 * `loadFromStore`/`load` path and the settings `save` path route through it (it also keeps the
 * preferences-backed AppStorage key in sync via the descriptor helper). Read by the migrated
 * `@ComponentV2` ReplyCard and SettingsPage. Pure-V2: every reader of this density value reads the
 * `@Trace` field, so the factory defaults to STYLE_STANDARD rather than seeding from AppStorage.
 */
@ObservedV2
export class ReplyCardStyleState {
  // Default mirrors ReplyCardStyleSettings.STYLE_STANDARD; the real value is published by
  // ReplyCardStyleSettings.apply() (startup restore + settings save).
  @Trace replyCardStyle: string = 'standard'
}

const REPLY_CARD_STYLE_V2_KEY: string = 'v2:replyCardStyle'

/**
 * Returns the app-wide ReplyCardStyleState singleton from AppStorageV2, defaulted to STYLE_STANDARD.
 * A `@ComponentV2` connecting before `SettingsBootstrap`'s `apply()` write sees the default and then
 * updates reactively when apply publishes the persisted value (matching the prior seed semantics,
 * since the volatile AppStorage key was likewise unset before apply on a cold start).
 */
export function connectReplyCardStyle(): ReplyCardStyleState {
  return AppStorageV2.connect(ReplyCardStyleState, REPLY_CARD_STYLE_V2_KEY, () => new ReplyCardStyleState())!
}
