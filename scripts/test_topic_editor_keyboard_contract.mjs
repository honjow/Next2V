#!/usr/bin/env node
/**
 * Topic editor keyboard avoidance contract.
 *
 * Bug: the editor used KeyboardAvoidMode.NONE + a manual bottom-pad (= keyboardHeight). That only let the
 * user scroll — it never brought the caret into view when the keyboard re-appeared (e.g. after a
 * preview↔edit switch with the cursor low in the body), so the cursor sat hidden behind the keyboard and
 * the user had to manually scroll the outer Scroll. Switch to RESIZE so the page compresses to fit above
 * the keyboard: the weight/percentage-sized body TextArea shrinks with it and its built-in caret tracking
 * keeps the cursor visible. The manual bottom-pad must then NOT add keyboardHeight (RESIZE already
 * excludes the keyboard — adding it would push the body up off the keyboard).
 *
 * Run: node scripts/test_topic_editor_keyboard_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('entry/src/main/ets/pages/TopicEditorPage.ets', 'utf8')

// aboutToAppear must set RESIZE, not NONE.
assert.match(page, /setKeyboardAvoidMode\(KeyboardAvoidMode\.RESIZE\)/, 'editor must use KeyboardAvoidMode.RESIZE so the page compresses above the keyboard')
assert.doesNotMatch(page, /setKeyboardAvoidMode\(KeyboardAvoidMode\.NONE\)/, 'editor must not use NONE (no avoidance → caret hidden behind keyboard)')
// aboutToDisappear restores the inherited default.
assert.match(page, /setKeyboardAvoidMode\(KeyboardAvoidMode\.OFFSET\)/, 'editor must restore the default avoid mode on disappear')

// bottomPad must NOT add the keyboard height (RESIZE already sits the page above the keyboard).
const padMatch = page.match(/private bottomPad\(\): number \{([\s\S]*?)\n  \}/)
assert.ok(padMatch, 'editor must define bottomPad()')
const padBody = padMatch[1]
assert.ok(padBody.includes('this.layout.keyboardHeight > 0'), 'bottomPad still branches on keyboard presence')
assert.doesNotMatch(padBody, /return this\.layout\.keyboardHeight/, 'bottomPad must NOT pad by keyboardHeight under RESIZE (it would push the body off the keyboard)')

console.log('topic editor keyboard contract passed')
