#!/usr/bin/env node
/**
 * Topic editor submit loading-guard contract.
 *
 * Bug: after tapping Publish the topic editor went straight back to a "free" state — only the title-bar
 * Submit icon was disabled (isSubmitting). The body TextArea stays mounted, so during the network request
 * it could re-grab focus / re-pop the keyboard and the user could mis-tap the form. The reply composer
 * already guards this with a modal system LoadingDialog (autoCancel:false) opened before the request and
 * closed in .finally(). The topic editor must mirror that: drop focus + open the modal overlay before the
 * createTopic call, close it in .finally(), and defensively close it in aboutToDisappear (the success path
 * navigates away before .finally() runs).
 *
 * Run: node scripts/test_topic_editor_submit_loading_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('entry/src/main/ets/pages/TopicEditorPage.ets', 'utf8')

// ── imports: LoadingDialog from @kit.ArkUI (CustomDialogController is a global ArkUI type, not imported) ──
assert.match(page, /import\s*\{[\s\S]*?LoadingDialog[\s\S]*?\}\s*from\s*'@kit\.ArkUI'/, 'must import LoadingDialog from @kit.ArkUI')

// ── a modal, non-cancelable loading controller, content = editor "submitting" string ──
// Slice a generous window from the field declaration (the formatter may reflow the object literal across
// lines, so match within the block rather than trying to balance braces with a regex).
const ctrlStart = page.indexOf('submitLoadingDialogController: CustomDialogController')
assert.ok(ctrlStart >= 0, 'must declare submitLoadingDialogController as a CustomDialogController')
const ctrl = page.slice(ctrlStart, ctrlStart + 500)
assert.match(ctrl, /new CustomDialogController\(\{/, 'submitLoadingDialogController must be a new CustomDialogController')
assert.match(ctrl, /builder:\s*LoadingDialog\(\{[\s\S]*?content:\s*AppStrings\.R_EDITOR_SUBMITTING/, 'loading dialog content must reuse R_EDITOR_SUBMITTING')
assert.match(ctrl, /autoCancel:\s*false/, 'autoCancel must be false so the overlay blocks touches (prevents mis-tap)')

// ── submit(): clear focus + open BEFORE the request, close in .finally() ──────
const submitMatch = page.match(/private submit\(\):\s*void\s*\{([\s\S]*?)\n {2}\}/)
assert.ok(submitMatch, 'must define submit()')
const submit = submitMatch[1]
const iClearFocus = submit.indexOf('getFocusController().clearFocus()')
const iOpen = submit.indexOf('this.submitLoadingDialogController.open()')
const iRequest = submit.indexOf('createTopicWithCookie')
const iFinally = submit.indexOf('.finally(')
const iClose = submit.indexOf('this.submitLoadingDialogController.close()')
assert.ok(iClearFocus >= 0, 'submit() must clear focus to dismiss the keyboard before the request')
assert.ok(iOpen >= 0, 'submit() must open the loading overlay')
assert.ok(iClose >= 0, 'submit() must close the loading overlay')
assert.ok(iOpen < iRequest, 'the overlay must open BEFORE the createTopic request')
assert.ok(iClearFocus < iRequest, 'focus must be cleared BEFORE the request')
assert.ok(iFinally >= 0 && iClose > iFinally, 'the overlay must be closed inside .finally() (runs on both success and error)')

// ── aboutToDisappear: defensive close (success path navigates away first) ─────
const disappearMatch = page.match(/aboutToDisappear\(\):\s*void\s*\{([\s\S]*?)\n {2}\}/)
assert.ok(disappearMatch, 'must define aboutToDisappear()')
assert.match(disappearMatch[1], /this\.submitLoadingDialogController\.close\(\)/, 'aboutToDisappear must also close the overlay (success path navigates away before .finally())')

console.log('topic editor submit loading contract passed')
