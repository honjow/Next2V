/**
 * Sticker value types. Kept in `model/` (not in the StickerPickerPanel component) so the recent-sticker
 * state holder / settings can reference StickerItem without importing the component — which would create a
 * holder <-> component import cycle (same reason RouteParams lives here).
 */

/**
 * One selectable sticker = a display name + an image URL. V2EX has no native sticker system, so a "sticker"
 * is just an image: tapping one inserts a readable placeholder code "[name]" while editing, and the composer
 * expands codes to the bare image URL on submit (V2EX auto-embeds whitelisted hosts such as i.imgur.com).
 */
export interface StickerItem {
  name: string
  url: string
}

/**
 * A visually-separated section of the picker. The panel renders one auto-stretch grid and inserts a full-row
 * separator between groups, so each group after the first starts on a fresh row with a little breathing room
 * — no group titles, just a hairline break.
 */
export interface StickerGroup {
  key: string
  stickers: StickerItem[]
}
