#!/usr/bin/env node
/**
 * Reply composer image-host upload contract.
 *
 * The reply composer (a plain text field — V2EX replies are NOT Markdown, bare image URLs auto-embed)
 * gains a single image button to the LEFT of the emphasized send key. Image-host only: tap → pick one
 * image → upload to the configured host → insert the BARE URL at the caret (no `![]()` wrapper, unlike
 * the Markdown topic editor). Mirrors the topic editor's placeholder-swap upload flow.
 *
 * Run: node scripts/test_reply_image_upload_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('feature/detail/src/main/ets/components/ReplyComposerBar.ets', 'utf8')

// ── imports: picker + shared image-upload subsystem ───────────────────────────
assert.match(page, /import\s*\{\s*photoAccessHelper\s*\}\s*from\s*'@kit\.MediaLibraryKit'/, 'must import photoAccessHelper')
for (const sym of ['ImageBytesUtils', 'ImageUploadErrorCode', 'ImageUploadService', 'ImageUploadSettings', 'connectNavStack']) {
  assert.match(page, new RegExp(`\\b${sym}\\b[\\s\\S]*?from 'shared'`), `must import ${sym} from shared`)
}

// ── image button: secondary (NORMAL) picture glyph, focusOnTouch(false), left of the send key ────────
const iImageGlyph = page.indexOf("sys.symbol.picture")
const iSendGlyph = page.indexOf("sys.symbol.paperplane_right_fill")
assert.ok(iImageGlyph >= 0, 'must render a picture glyph (the image button)')
assert.ok(iSendGlyph >= 0, 'must still render the send glyph')
assert.ok(iImageGlyph < iSendGlyph, 'the image button must sit BEFORE (left of) the send button')
// the image button's chrome: NORMAL style (secondary, not the EMPHASIZED send) + focusOnTouch(false)
const imageBtnRegion = page.slice(iImageGlyph, iSendGlyph)
assert.match(imageBtnRegion, /buttonStyle\(ButtonStyleMode\.NORMAL\)/, 'image button must be the secondary NORMAL style')
assert.match(imageBtnRegion, /focusOnTouch\(false\)/, 'image button must not steal focus (keeps the TextArea caret for the insert)')
assert.match(imageBtnRegion, /\.onClick\(\(\) => \{\s*this\.pickAndUploadImage\(\)/, 'image button must trigger pickAndUploadImage')

// ── caret tracking so the insert lands where the user is typing ───────────────
assert.match(page, /\.onTextSelectionChange\(\(start: number, end: number\) => \{\s*this\.selStart = start\s*this\.selEnd = end/, 'must track the caret via onTextSelectionChange')

// ── upload flow: gate on configured host, placeholder → swap to a BARE url ─────
assert.match(page, /private async pickAndUploadImage\(\)/, 'must define pickAndUploadImage')
assert.match(page, /if \(!ImageUploadSettings\.isConfigured\(config\)\)\s*\{\s*this\.promptConfigureHost\(\)/, 'must gate on a configured image host before opening the picker')
assert.match(page, /private uploadPickedImage\(uri: string\)/, 'must define uploadPickedImage')
// The crux: success inserts the BARE url, NOT a `![](url)` Markdown wrapper.
assert.match(page, /this\.replacePlaceholder\(placeholder, uploaded\.url\)/, 'on success the reply must insert the BARE url')
assert.doesNotMatch(page, /replacePlaceholder\(placeholder, `!\[\]\(/, 'the reply must NOT wrap the url in Markdown image syntax')
// failure removes the placeholder
assert.match(page, /this\.replacePlaceholder\(placeholder, ''\)/, 'on failure the placeholder must be removed')

// ── robustness: disposed guard + orphan-placeholder strip on draft load ───────
assert.match(page, /private disposed: boolean = false/, 'must hold a disposed guard')
assert.match(page, /if \(this\.disposed\)\s*\{\s*return/, 'upload completion must bail if the bar was torn down')
assert.match(page, /private stripUploadingPlaceholders\(text: string\): string/, 'must define stripUploadingPlaceholders')
assert.match(page, /this\.content = this\.stripUploadingPlaceholders\(state\.content\)/, 'draft load must strip orphaned uploading placeholders')

console.log('reply image upload contract passed')
