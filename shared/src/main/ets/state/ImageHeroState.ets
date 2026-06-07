import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Shared-element ("Hero") binding for the image preview, owned by `AppStorageV2`.
 *
 * `activeId` names the single image that is currently morphing between its in-page thumbnail (the OUT node,
 * e.g. an image in `MarkdownContent`) and the full-screen preview (the IN node, `ImagePreviewPage`). A tap
 * sets `activeId` to the tapped image's id BEFORE pushing the preview route; `Index.onDestinationHidden`
 * (the preview's `onHidden`) clears it after the preview closes, so the source stays bound through the whole
 * back morph. Both ends derive the SAME id from the SAME normalized URL via `heroIdForUrl`, which is how
 * `geometryTransition` pairs the two nodes across the route push. Keeping `activeId` set for the whole
 * lifetime of the preview is what lets the BACK morph play (the OUT node stays bound while the preview is open).
 *
 * `@Trace activeId` is the subscription point: a bound thumbnail re-renders to bind/unbind its id when a hero
 * starts/ends, so only the tapped image (activeId match) ever shares an id with the preview — keeping exactly
 * two nodes per id, the hard rule `geometryTransition` requires.
 *
 * Known limitation: if the SAME normalized URL is rendered more than once on one page (e.g. an image repeated
 * in the body and an 附言, or quoted in a reply), every matching OUT node binds the id, so a tap pairs 3+ nodes.
 * geometryTransition only morphs two, so that rare case degrades to a plain `.transition(OPACITY)` fade instead
 * of a morph — cosmetic only, no crash. A per-occurrence id would be needed to morph duplicates exactly.
 */
@ObservedV2
export class ImageHeroState {
  @Trace activeId: string = ''
}

const IMAGE_HERO_V2_KEY: string = 'v2:imageHero'

export function connectImageHero(): ImageHeroState {
  return AppStorageV2.connect(ImageHeroState, IMAGE_HERO_V2_KEY, () => new ImageHeroState())!
}

/**
 * Deterministic, stable, non-empty geometryTransition id for a NORMALIZED image URL (FNV-1a, 32-bit, hex).
 * Must hash identically on both the source thumbnail and the preview so the pair links; callers normalize
 * via `MediaUrlUtils.normalizeUrl` first. Returns '' for an empty URL (which clears any binding — a no-op).
 */
export function heroIdForUrl(url: string): string {
  if (!url) {
    return ''
  }
  let hash: number = 0x811c9dc5
  for (let i = 0; i < url.length; i++) {
    hash = hash ^ url.charCodeAt(i)
    hash = Math.imul(hash, 0x01000193)
  }
  return 'hero_' + (hash >>> 0).toString(16)
}
