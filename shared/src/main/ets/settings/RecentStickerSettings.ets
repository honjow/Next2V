import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StickerItem } from '../model/StickerTypes'
import { connectRecentStickers } from '../state/RecentStickerState'
import { STORE_NAME_SETTINGS, readJsonArray, writeJsonValue } from './SettingsStorage'

const KEY_RECENT_STICKERS: string = 'recentStickers'

/**
 * Recently-used stickers, persisted in the unified `next2v_settings` store (so it rides the whole-store
 * backup). Device-global and non-sensitive — NOT owner-scoped and NOT cloud-synced (which sticker a user
 * recently tapped is not account data, unlike the blocked list). Most-recent-first; deduped by name; capped.
 *
 * `apply()` is the single writer of the `RecentStickerState` V2 mirror. The context is captured at load()
 * time so `record()` (called on every sticker tap) needs no context argument.
 */
export class RecentStickerSettings {
  // Cap stored count high enough to fill two rows on the widest screens (a ~15-column tablet shows ~30 in
  // two rows); the picker still slices to exactly two rows at render time per the live column count.
  static readonly MAX_RECENT: number = 40

  private static context: common.UIAbilityContext | null = null

  static apply(items: StickerItem[]): void {
    connectRecentStickers().items = items
  }

  /** The live recent list, read from the V2 mirror apply() keeps in lockstep with the persisted key. */
  static current(): StickerItem[] {
    return connectRecentStickers().items
  }

  static async load(context: common.UIAbilityContext): Promise<void> {
    RecentStickerSettings.context = context
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    const raw = readJsonArray<StickerItem>(store, KEY_RECENT_STICKERS, [])
    RecentStickerSettings.apply(RecentStickerSettings.normalize(raw))
  }

  /**
   * Move `item` to the front of the recent list (dedup by name), cap it, mirror to the holder immediately,
   * and persist in the background. Called on every sticker pick; safe to call before load() set the context
   * (it still updates the in-memory holder, just skips the disk write).
   */
  static record(item: StickerItem): void {
    const name = (item.name || '').trim()
    const url = (item.url || '').trim()
    if (!name || !url) {
      return
    }
    const head: StickerItem = { name: name, url: url }
    const next: StickerItem[] = [head]
    for (const existing of connectRecentStickers().items) {
      if (existing.name !== name && next.length < RecentStickerSettings.MAX_RECENT) {
        next.push(existing)
      }
    }
    RecentStickerSettings.apply(next)
    RecentStickerSettings.persist(next)
  }

  private static persist(items: StickerItem[]): void {
    const ctx = RecentStickerSettings.context
    if (!ctx) {
      return
    }
    preferences
      .getPreferences(ctx, STORE_NAME_SETTINGS)
      .then((store: preferences.Preferences) => {
        writeJsonValue(store, KEY_RECENT_STICKERS, items)
      })
      .catch((_error: Error) => {
        // Best-effort persistence; the in-memory holder already reflects the change this session.
      })
  }

  private static normalize(items: StickerItem[]): StickerItem[] {
    const out: StickerItem[] = []
    const seen: Set<string> = new Set()
    const source = Array.isArray(items) ? items : []
    for (const it of source) {
      const name = (it.name || '').trim()
      const url = (it.url || '').trim()
      if (name && url && !seen.has(name) && out.length < RecentStickerSettings.MAX_RECENT) {
        out.push({ name: name, url: url })
        seen.add(name)
      }
    }
    return out
  }
}
