#!/usr/bin/env node
/**
 * Image-link insert caret position contract (topic editor).
 *
 * When inserting an image link with nothing selected, the caret should land inside the URL parens
 * (`![](https://|)`), not between the `![ ]` alt markers — the alt is usually left empty, the URL is what
 * you fill in. insertInlineMarkdown takes an optional emptyCaretOffset that overrides the default
 * (caret-between-markers) position; onInsertImageLink passes the offset to the URL.
 *
 * Run: node scripts/test_editor_image_link_caret_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('entry/src/main/ets/pages/TopicEditorPage.ets', 'utf8')

// Source: insertInlineMarkdown accepts an emptyCaretOffset and the image insert passes the URL offset.
assert.match(page, /insertInlineMarkdown\(prefix: string, suffix: string, emptyCaretOffset: number = -1\)/, 'insertInlineMarkdown must accept an emptyCaretOffset override')
assert.match(page, /this\.insertInlineMarkdown\('!\[', '\]\(https:\/\/\)', '!\[\]\(https:\/\/'\.length\)/, 'onInsertImageLink must drop the caret into the URL (offset = "![](https://".length)')

// Logic replica of insertInlineMarkdown's caret math.
function caretFor(content, selStart, selEnd, prefix, suffix, emptyCaretOffset = -1) {
  const len = content.length
  const start = Math.min(Math.max(selStart, 0), len)
  const rawEnd = Math.min(Math.max(selEnd, 0), len)
  const end = rawEnd >= start ? rawEnd : start
  const selected = content.substring(start, end)
  const insertion = `${prefix}${selected}${suffix}`
  const newContent = content.substring(0, start) + insertion + content.substring(end)
  const caret = selected.length === 0
    ? start + (emptyCaretOffset >= 0 ? emptyCaretOffset : prefix.length)
    : start + insertion.length
  return { newContent, caret }
}

// Empty selection at the end of "hi": image link → caret inside the URL parens, alt left empty.
const r = caretFor('hi', 2, 2, '![', '](https://)', '![](https://'.length)
assert.equal(r.newContent, 'hi![](https://)', 'inserts ![](https://) with an empty alt')
assert.equal(r.caret, 'hi'.length + '![](https://'.length, 'caret offset computed from start')
// The caret must sit right before the closing ) — i.e. inside the URL after https://.
assert.equal(r.newContent[r.caret], ')', 'caret lands just before the closing ) (inside the URL)')
assert.equal(r.newContent.substring(0, r.caret), 'hi![](https://', 'everything before the caret is the alt + https:// — the alt is empty')

// Regular inline (no offset) still lands the caret between the markers (e.g. bold).
const b = caretFor('', 0, 0, '**', '**')
assert.equal(b.caret, 2, 'bold without an offset keeps the caret between the markers')

console.log('editor image-link caret contract passed')
