import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the reply-card density setting (`StorageKeys.REPLY_CARD_STYLE`:
 * 'standard' | 'compact').
 *
 * `ReplyCardStyleSettings.apply()` is the single AppStorage writer for this key — both the
 * startup `loadFromStore`/`load` path and the settings `save` path route through it — so it
 * is the one place that dual-writes during the State Management V1->V2 backbone migration:
 * the legacy `AppStorage` key (still read by the V1 SettingsPage `@StorageLink` that drives
 * the density toggle UI) AND this `@Trace` field (read by the migrated `@ComponentV2`
 * ReplyCard). Transitional — drop the `AppStorage` half once every REPLY_CARD_STYLE reader
 * is V2.
 */
@ObservedV2
export class ReplyCardStyleState {
  // Default mirrors ReplyCardStyleSettings.STYLE_STANDARD; the real value is published by the
  // factory seed below and kept in sync by ReplyCardStyleSettings.apply().
  @Trace replyCardStyle: string = 'standard'
}

const REPLY_CARD_STYLE_V2_KEY: string = 'v2:replyCardStyle'

/**
 * Returns the app-wide ReplyCardStyleState singleton from AppStorageV2, seeded from the V1
 * AppStorage key so a `@ComponentV2` connecting before `SettingsBootstrap`'s `apply()` write
 * still gets the persisted value (matching the old `@StorageProp` initial-read semantics).
 */
export function connectReplyCardStyle(): ReplyCardStyleState {
  return AppStorageV2.connect(ReplyCardStyleState, REPLY_CARD_STYLE_V2_KEY, () => {
    const state = new ReplyCardStyleState()
    state.replyCardStyle = AppStorage.get<string>(StorageKeys.REPLY_CARD_STYLE) ?? 'standard'
    return state
  })!
}
