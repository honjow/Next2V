import { AppStorageV2 } from '@kit.ArkUI'
import { StickerItem } from '../model/StickerTypes'

/**
 * V2 mirror of the recently-used stickers, most-recent-first. `RecentStickerSettings` is the single
 * imperative writer (it reassigns `items` and persists to the unified `next2v_settings` store). The sticker
 * picker reads this list at open time (snapshot) to render the "recent" group at the top, so picking a
 * sticker does not reshuffle the grid under the user's finger mid-session — the next open reflects it.
 *
 * No V1 AppStorage half: this is a new setting with no `@StorageLink` readers; the mirror is the only live
 * channel.
 */
@ObservedV2
export class RecentStickerState {
  @Trace items: StickerItem[] = []
}

const RECENT_STICKER_V2_KEY: string = 'v2:recentStickers'

/** Returns the app-wide RecentStickerState singleton from AppStorageV2. */
export function connectRecentStickers(): RecentStickerState {
  return AppStorageV2.connect(
    RecentStickerState,
    RECENT_STICKER_V2_KEY,
    () => new RecentStickerState(),
  )!
}
