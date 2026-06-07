#!/usr/bin/env node
// Image-preview transform-viewer contract.
//
// Locks the rewritten ImagePreviewPage gesture model (transform-based: .scale()+.translate() about CENTER,
// driven by a parallel pinch/pan/double-tap GestureGroup, with swipe-down-to-dismiss) and the pure math in
// ImagePreviewCoordinator. The two MATH identities below are the ones the design review flagged as the
// blocker: with a center-pivot .scale(), the focal/double-tap corrective translate must keep the touched
// screen point stationary. We re-implement the formulas here and assert that invariant numerically.
//
// Run: node scripts/test_imagepreview_transform_contract.mjs
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (p) => readFileSync(path.join(repo, p), 'utf8')
const page = read('entry/src/main/ets/pages/ImagePreviewPage.ets')
const coord = read('entry/src/main/ets/model/ImagePreviewCoordinator.ets')
const index = read('entry/src/main/ets/pages/Index.ets')
const hero = read('shared/src/main/ets/state/ImageHeroState.ets')
const markdown = read('shared/src/main/ets/components/MarkdownContent.ets')
const topicDetail = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const userProfile = read('feature/user/src/main/ets/pages/UserProfilePage.ets')
const userReplies = read('feature/user/src/main/ets/pages/UserRepliesPage.ets')

// ── Title bar: HIDDEN for image preview; the page draws its own legible-on-any-image overlay control ────────
// hideTitleBar(true) removes the WHOLE bar (back+menu); hideTitleArea/dynamicHide only hides the title text on
// scroll and would leave the HDS back/menu buttons doubling up with our overlay one.
assert.match(index, /\.hideTitleBar\(descriptor\.family === 'imagePreview'\)/, 'imagePreview must fully hide the HDS title bar via hideTitleBar(true)')
// The page draws a single white download glyph in a dark translucent circle, anchored bottom-right via
// position() edge anchors. There is NO explicit back button — swipe-down-to-dismiss and the system back
// gesture both pop the page.
assert.match(page, /ButtonType\.Circle/, 'the overlay save control must be a circular button')
assert.match(page, /\.backgroundColor\('#[0-9A-Fa-f]{2}000000'\)/, 'overlay save button needs a translucent black backplate for legibility on any image')
assert.match(page, /sys\.symbol\.arrow_down_to_line/, 'save (download) glyph must be present in the overlay')
assert.match(page, /\.position\(\{[\s\S]*?bottom:\s*this\.layout\.bottomAvoidHeight/, 'save button must be anchored bottom-right via position() with the bottom safe-area inset')
assert.doesNotMatch(page, /sys\.symbol\.chevron_backward/, 'the explicit back button was removed (dismiss via swipe-down / system back)')

// ── Source contract: the page uses the transform model, not the old width-scaling + nested Scroll ──────────
assert.match(page, /\.scale\(\{\s*x:\s*this\.scaleValue,\s*y:\s*this\.scaleValue\s*\}\)/, 'image must be scaled via .scale() (center-pivot transform), not width-scaling')
assert.match(page, /\.translate\(\{\s*x:\s*this\.offsetX,\s*y:\s*this\.offsetY\s*\+\s*this\.dismissY\s*\}\)/, 'image must be panned via .translate() with dismissY riding the y axis')
assert.match(page, /\.renderGroup\(true\)/, 'transformed image must be a single render layer')
assert.match(page, /GestureGroup\(\s*GestureMode\.Parallel/, 'gestures must compose in a parallel GestureGroup')
assert.match(page, /PinchGesture\(\{\s*fingers:\s*2\s*\}\)/, 'must keep 2-finger pinch')
assert.match(page, /PanGesture\(\{\s*fingers:\s*1/, 'must add single-finger pan')
assert.match(page, /TapGesture\(\{\s*count:\s*2\s*\}\)/, 'must add double-tap')
assert.match(page, /this\.getUIContext\(\)\.animateTo\(/, 'release animations must use getUIContext().animateTo (V2-correct)')
assert.match(page, /curves\.springMotion\(\)/, 'snap-back/reset must use a spring curve')
assert.match(page, /this\.isPinching/, 'pan must stand down while a pinch is in flight (isPinching gate)')
assert.match(page, /this\.stack\.pop\(false\)/, 'swipe-to-dismiss must pop the nav stack with animated=false, inside animateTo (Hero back morph)')
// The back morph must start from the RELEASE position, not the centered frame: geometryTransition reads the
// LAYOUT rect (not the render .translate), so the drag is baked into a layout .offset before the pop.
assert.match(page, /\.offset\(\{\s*x:\s*0,\s*y:\s*this\.dismissLayoutY\s*\}\)/, 'preview image must expose a layout .offset(dismissLayoutY) so the dismiss morph starts from where the finger let go')
assert.match(page, /this\.dismissLayoutY = this\.dismissY/, 'dismiss must bake the drag (render translate) into the layout offset before popping (geometryTransition reads layout, not translate)')
// No regressions: the old width-scaling path and nested Scroll are gone; save flow + black canvas stay.
assert.doesNotMatch(page, /ImagePreviewCoordinator\.imageWidth|getImageWidth/, 'the dead width-scaling path must be removed from the page')
assert.doesNotMatch(page, /Scroll\(\)/, 'the nested Scroll pan model must be gone')
assert.match(page, /@Monitor\('imgAction\.command'\)[\s\S]*?saveImage\(\)/, 'save command bus must stay intact')
assert.match(page, /showAssetsCreationDialog/, 'gallery-save path must stay intact')
assert.match(page, /MediaUrlUtils\.normalizeUrl/, 'url normalization must stay')
assert.match(page, /\.onAreaChange\([\s\S]*?this\.viewportWidth[\s\S]*?this\.viewportHeight/, 'both viewport axes must be measured (height is needed for vertical clamp/focal)')
// State Management V2 only (no V1 decorators in the rewritten page).
for (const v1 of [/@State\b/, /@Prop\b/, /@Link\b/, /@Watch\b/, /@Provide\b/, /@Consume\b/, /@ObjectLink\b/, /@StorageLink\b/]) {
  assert.doesNotMatch(page.replace(/\/\/.*$/gm, ''), v1, `no V1 decorator ${v1} in ImagePreviewPage`)
}

// ── Immersive status bar without a return jump ──────────────────────────────────────────────────────────────
// Hidden on enter (onShown, after the push transition, when the topic page is already covered) and restored
// on onWillHide (BEFORE the pop transition starts), so the avoid-area reflow never shows under the topic page.
assert.match(index, /setImagePreviewImmersive/, 'Index must toggle status-bar immersion for the preview route')
assert.match(index, /onWillHide[\s\S]{0,80}onDestinationWillHide/, 'status bar must be restored on onWillHide (ahead of the pop transition)')

// ── Shared-element (Hero) transition: cross-page geometryTransition driven by an animateTo-wrapped route swap ─
// Mechanism (verified on-device): pushing/popping with animated=false skips HdsNavigation's customNavContentTransition
// delegate ENTIRELY, so the morph is driven by wrapping the push/pop in getUIContext().animateTo() at the call site
// (the route mount/unmount then happens inside the animateTo window, which is what geometryTransition interpolates).
// The dead customNavContentTransition delegate must therefore be gone.
assert.doesNotMatch(index, /customNavContentTransition/, 'customNavContentTransition must be removed — animated=false skips it, so it never fired (no morph)')
// Holder: a V2-only @ObservedV2/@Trace activeId + a deterministic url->id hash so both ends pair on the same id.
assert.match(hero, /@ObservedV2[\s\S]*?class ImageHeroState[\s\S]*?@Trace activeId/, 'ImageHeroState must be an @ObservedV2 holder with a @Trace activeId')
assert.match(hero, /export function heroIdForUrl\(/, 'heroIdForUrl hash must be exported')
// IN node (preview image) binds its hero id + keeps a .transition so it survives the morph.
assert.match(page, /\.geometryTransition\(this\.heroGid\(\)\)/, 'preview image (IN node) must bind geometryTransition by its hero id')
assert.match(page, /\.transition\(TransitionEffect\.OPACITY\)/, 'IN node needs .transition(OPACITY) to survive the morph')
// OUT node (the tapped MarkdownContent image) binds the SAME id ONLY when it is the active hero (activeId match),
// with follow:true + a .transition, so exactly two nodes ever share an id.
assert.match(markdown, /this\.hero\.activeId === id \? id : ""/, 'OUT image must bind its id ONLY on activeId match (keeps exactly two nodes per id)')
assert.match(markdown, /\.geometryTransition\(this\.heroGid\(\),\s*\{\s*follow:\s*true\s*\}\)/, 'OUT image must bind geometryTransition with follow:true')
// The binding is cleared only AFTER the preview is fully hidden (onHidden), so the source stays bound through the
// whole close morph; clearing earlier would unbind the OUT node and kill the back morph.
assert.match(index, /onHidden\([\s\S]{0,80}onDestinationHidden/, 'imagePreview must clear the hero binding via onHidden (after the back morph)')
assert.match(index, /connectImageHero\(\)\.activeId = ''/, 'onDestinationHidden must clear the hero activeId')
// System back also pops INSIDE animateTo (animated=false) so the back morph plays on the hardware/gesture back.
assert.match(index, /animateTo\([\s\S]{0,120}this\.ns\.pop\(false\)/, 'system back for imagePreview must pop inside animateTo with animated=false')
// Every tap entry point arms activeId BEFORE the push, then pushes INSIDE animateTo with animated=false.
for (const [name, src] of [['TopicDetailPage', topicDetail], ['UserProfilePage', userProfile], ['UserRepliesPage', userReplies]]) {
  assert.match(src, /connectImageHero\(\)\.activeId = heroIdForUrl\(MediaUrlUtils\.normalizeUrl\(normalized\)\)/, `${name}.openImagePreview must arm the hero activeId before pushing`)
  assert.match(src, /animateTo\([\s\S]{0,160}pushPathByName\('ImagePreview', p as Object, false\)/, `${name}.openImagePreview must push INSIDE animateTo with animated=false (drives the Hero morph)`)
}

// ── Coordinator helpers exist ─────────────────────────────────────────────────────────────────────────────
assert.match(coord, /static readonly DOUBLE_TAP_SCALE:\s*number\s*=\s*2\.5/, 'DOUBLE_TAP_SCALE must be 2.5')
assert.match(coord, /static doubleTapTarget\(/, 'doubleTapTarget helper required')
assert.match(coord, /static fitScale\(/, 'fitScale helper required (Contain fit-factor)')
assert.match(coord, /static maxOffset\(/, 'maxOffset helper required')
assert.match(coord, /static clampOffset\(/, 'clampOffset helper required')
assert.match(coord, /value\s*>\s*4[\s\S]*?return\s*4/, 'clampScale ceiling must stay 4')

// ── Math invariants (re-implemented from the coordinator) ───────────────────────────────────────────────
const clampScale = (v) => (!Number.isFinite(v) ? 1 : v < 1 ? 1 : v > 4 ? 4 : v)
const fitScale = (vw, vh, iw, ih) => {
  if (vw <= 0 || vh <= 0 || iw <= 0 || ih <= 0) return 1
  const f = Math.min(vw / iw, vh / ih)
  return f > 0 ? f : 1
}
const maxOffset = (viewport, disp, scale) => {
  const over = disp * scale - viewport
  return over > 0 ? over / 2 : 0
}
const clampOffset = (v, viewport, disp, scale) => {
  const m = maxOffset(viewport, disp, scale)
  return v > m ? m : v < -m ? -m : v
}
const doubleTapTarget = (cur) => (cur > 1.01 ? 1 : 2.5)

assert.equal(clampScale(0.5), 1)
assert.equal(clampScale(9), 4)
assert.equal(clampScale(Number.NaN), 1)
assert.equal(fitScale(360, 640, 1000, 1000), 0.36, 'fit-factor = min axis ratio')
assert.equal(maxOffset(360, 300, 1), 0, 'no pan when the fitted image is within the viewport')
assert.equal(maxOffset(360, 360, 2), 180, 'overflow splits symmetrically: (720-360)/2')
assert.equal(clampOffset(1000, 360, 360, 2), 180, 'pan clamps to +max')
assert.equal(clampOffset(-1000, 360, 360, 2), -180, 'pan clamps to -max')
assert.equal(doubleTapTarget(1), 2.5)
assert.equal(doubleTapTarget(2.5), 1)

// CENTER-PIVOT double-tap: ox = (1-T)*(tap-center). The content point under the tap must stay under the tap
// after scaling about the center: screen' = center + ox + T*(tap-center) === tap.
const center = 180 // viewport/2 for a 360 viewport
const T = 2.5
for (const tap of [0, 90, 180, 270, 360]) {
  const ox = (1 - T) * (tap - center)
  const screenAfter = center + ox + T * (tap - center)
  assert.ok(Math.abs(screenAfter - tap) < 1e-9, `double-tap focal must pin the tapped point (tap=${tap})`)
}

// CENTER-PIVOT pinch focal: with start offset o0, start scale s0, start pinch-center pc, new scale s1=s0*k,
// ox = (pc-center)*(1-k) + k*o0  keeps the content point that was under pc stationary (no finger drift).
const pinchPins = (center2, pc, s0, o0, k) => {
  const o1 = (pc - center2) * (1 - k) + k * o0
  // content point under pc at start sits at (pc - (center2 + o0)) from the (scaled) bitmap center, i.e. its
  // unscaled position u = (pc - center2 - o0)/s0; after: screen = center2 + o1 + s1*u.
  const s1 = s0 * k
  const u = (pc - center2 - o0) / s0
  return center2 + o1 + s1 * u
}
for (const pc of [40, 180, 320]) {
  for (const k of [1.5, 0.7, 3]) {
    const screen = pinchPins(180, pc, 1.2, 25, k)
    assert.ok(Math.abs(screen - pc) < 1e-9, `pinch focal must pin pc=${pc} k=${k}`)
  }
}

console.log('image-preview transform-viewer contract passed')
