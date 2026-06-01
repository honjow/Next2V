#!/usr/bin/env node
// Reply submit UX contract (topic-detail reply composer).
//
// Proves the half-modal reply composer no longer self-submits behind a confirmation dialog, and
// that TopicDetailPage owns the network submit: it closes the sheet BEFORE the request (so the
// TextArea can't re-grab focus / re-open the keyboard while pending), opens the system
// LoadingDialog via CustomDialogController, refreshes replies + clears the draft on success, and
// preserves the draft (without auto-reopening / lost-draft) plus surfaces the translated error on
// failure.
//
// Run: node scripts/test_reply_submit_loading_ux_contract.mjs
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const sheetPath = 'feature/detail/src/main/ets/components/ReplyComposerSheet.ets'
const pagePath = 'feature/detail/src/main/ets/pages/TopicDetailPage.ets'
const sheet = readFileSync(sheetPath, 'utf8')
const page = readFileSync(pagePath, 'utf8')

function methodBody(source, name) {
  const marker = `private ${name}(`
  const start = source.indexOf(marker)
  assert.ok(start >= 0, `${name} method missing`)
  const brace = source.indexOf('{', start)
  assert.ok(brace >= 0, `${name} method body missing`)
  let depth = 0
  for (let i = brace; i < source.length; i++) {
    if (source[i] === '{') {
      depth += 1
    } else if (source[i] === '}') {
      depth -= 1
      if (depth === 0) {
        return source.slice(brace + 1, i)
      }
    }
  }
  assert.fail(`${name} method body did not close`)
}

function blockAfter(source, marker) {
  const start = source.indexOf(marker)
  assert.ok(start >= 0, `${marker} block missing`)
  const brace = source.indexOf('{', start)
  assert.ok(brace >= 0, `${marker} block body missing`)
  let depth = 0
  for (let i = brace; i < source.length; i++) {
    if (source[i] === '{') {
      depth += 1
    } else if (source[i] === '}') {
      depth -= 1
      if (depth === 0) {
        return source.slice(brace + 1, i)
      }
    }
  }
  assert.fail(`${marker} block did not close`)
}

const FORBIDDEN_V1 = [
  /@Component\b(?!V2)/, /@State\b/, /@Prop\b/, /@Link\b/, /@Watch\b/, /@StorageLink\b/, /@StorageProp\b/,
  /@Provide\b/, /@Consume\b/, /@ObjectLink\b/, /@Observed\b(?!V2)/, /@LocalStorageLink\b/, /@LocalStorageProp\b/,
]
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')

// ---------------------------------------------------------------------------
// ReplyComposerSheet: editor-only, no normal-submit confirmation dialog, emits snapshot.
// ---------------------------------------------------------------------------
const confirmSubmit = methodBody(sheet, 'confirmSubmit')

// (1) No "Submit this reply?" confirmation dialog for ordinary reply submit.
assert.doesNotMatch(
  confirmSubmit,
  /showAlertDialog/,
  'confirmSubmit() must not show a confirmation dialog for ordinary reply submit',
)

// (2) Validates via the existing coordinator and emits a CLEAN snapshot to the parent.
assert.match(
  confirmSubmit,
  /ReplyComposerCoordinator\.checkSubmit\(/,
  'confirmSubmit() must validate via ReplyComposerCoordinator.checkSubmit',
)
assert.match(
  confirmSubmit,
  /this\.submitAction\(check\.content\)/,
  'confirmSubmit() must emit the clean content snapshot (check.content) to the parent',
)
// Login/empty guards still short-circuit BEFORE any emit (auth not bypassed).
const emitIndex = confirmSubmit.indexOf('this.submitAction(check.content)')
const loginGuardIndex = confirmSubmit.indexOf("check.reason === 'loginRequired'")
assert.ok(
  loginGuardIndex >= 0 && loginGuardIndex < emitIndex,
  'confirmSubmit() must keep the loginRequired guard before emitting',
)

// (3) The sheet declares the snapshot-carrying event and no longer owns the network submit.
assert.match(
  sheet,
  /@Event\s+submitAction\?:\s*\(content:\s*string\)\s*=>\s*void/,
  'ReplyComposerSheet must declare @Event submitAction?: (content: string) => void',
)
assert.doesNotMatch(
  sheet,
  /submitReplyWithCookie/,
  'ReplyComposerSheet must not call submitReplyWithCookie (network submit moved to the page)',
)
assert.doesNotMatch(
  sheet,
  /@Event\s+submittedAction/,
  'ReplyComposerSheet must drop the old submittedAction event',
)

// ---------------------------------------------------------------------------
// TopicDetailPage: owns pending state, the system LoadingDialog, and the network submit.
// ---------------------------------------------------------------------------

// (4) Page-level pending flag + system LoadingDialog controller. This is an implementation
// boundary: do not replace LoadingDialog with a hand-written LoadingProgress/card/scrim overlay.
assert.match(
  page,
  /import \{[^}]*LoadingDialog[^}]*promptAction[^}]*\} from '@kit\.ArkUI'|import \{[^}]*promptAction[^}]*LoadingDialog[^}]*\} from '@kit\.ArkUI'/s,
  'TopicDetailPage must import the system LoadingDialog from @kit.ArkUI',
)
assert.match(
  page,
  /@Local\s+private\s+isReplySubmitting:\s*boolean\s*=\s*false/,
  'TopicDetailPage must own an @Local isReplySubmitting pending flag',
)
assert.match(
  page,
  /private\s+replySubmitLoadingDialogController:\s*CustomDialogController\s*=\s*new\s+CustomDialogController\(\s*\{[\s\S]*builder:\s*LoadingDialog\(\s*\{[\s\S]*content:\s*\$r\('app\.string\.reply_submitting'\)/,
  'TopicDetailPage must back reply submit waiting UI with system LoadingDialog + CustomDialogController',
)
assert.doesNotMatch(
  page,
  /@Builder\s+ReplySubmitLoadingOverlay|REPLY_SUBMIT_SCRIM|ReplySubmitLoadingOverlay\(/,
  'reply submit must not use a hand-written overlay/scrim builder',
)

// (5) The composer builder wires submitAction -> page submit handler.
const composerBuilder = blockAfter(page, '@Builder ReplyComposerSheetBuilder()')
assert.match(
  composerBuilder,
  /submitAction:\s*\(content:\s*string\)\s*=>\s*\{\s*this\.submitReplyFromComposer\(content\)/,
  'ReplyComposerSheetBuilder must route submitAction to submitReplyFromComposer',
)

// (6) Submit handler closes the sheet BEFORE the network request and raises the pending flag.
const submit = methodBody(page, 'submitReplyFromComposer')
const closeIndex = submit.indexOf('this.replyComposerVisible = false')
const pendingIndex = submit.indexOf('this.isReplySubmitting = true')
const requestIndex = submit.indexOf('this.api')
const submitCallIndex = submit.indexOf('.submitReplyWithCookie(')
assert.ok(closeIndex >= 0, 'submit handler must close the composer sheet')
assert.ok(requestIndex >= 0 && submitCallIndex >= 0, 'submit handler must call submitReplyWithCookie')
assert.ok(
  closeIndex < requestIndex,
  'submit handler must close replyComposerVisible BEFORE calling submitReplyWithCookie',
)
assert.ok(
  pendingIndex >= 0 && pendingIndex < requestIndex,
  'submit handler must raise isReplySubmitting BEFORE the request (guards duplicate submit)',
)
const openDialogIndex = submit.indexOf('this.replySubmitLoadingDialogController.open()')
assert.ok(
  openDialogIndex >= 0 && pendingIndex >= 0 && pendingIndex < openDialogIndex && openDialogIndex < requestIndex,
  'submit handler must open the system LoadingDialog after setting pending and before the request',
)
// Cookie/auth pre-check toasts (never silently bypasses login).
assert.match(
  submit,
  /reply_login_required/,
  'submit handler must surface a login-required message when no cookie',
)

// (7) Success: clears the draft AND refreshes reply page state.
const success = blockAfter(submit, '.then(() =>')
assert.match(success, /this\.clearReplyDraftAfterSuccess\(\)/, 'success must clear the saved draft')
assert.match(success, /this\.v\.load\(\)/, 'success must refresh the reply list (v.load)')
const clearDraft = methodBody(page, 'clearReplyDraftAfterSuccess')
assert.match(
  clearDraft,
  /ReplyComposerDraftCoordinator\.clearDraft\(/,
  'clearReplyDraftAfterSuccess must clear the draft via ReplyComposerDraftCoordinator',
)

// (8) Failure: preserve draft (no clear, no lost-draft) and DO NOT auto-reopen the composer.
const failure = blockAfter(submit, '.catch((error: Error) =>')
assert.match(failure, /translateApiError\(error\)/, 'failure must surface the translated API error')
assert.doesNotMatch(
  failure,
  /clearReplyDraftAfterSuccess|clearDraft/,
  'failure must NOT clear the draft (preserve user content)',
)
assert.doesNotMatch(
  failure,
  /replyComposerVisible\s*=\s*true/,
  'failure must NOT auto-reopen the composer (avoids TextArea auto-focus / keyboard)',
)

// (9) finally clears the pending flag and closes the system LoadingDialog regardless of outcome.
const fin = blockAfter(submit, '.finally(() =>')
assert.match(fin, /this\.replySubmitLoadingDialogController\.close\(\)/, 'finally must close the system LoadingDialog')
assert.match(fin, /this\.isReplySubmitting = false/, 'finally must lower isReplySubmitting')

// ---------------------------------------------------------------------------
// (10) No new State Management V1 decorators in the touched files.
// ---------------------------------------------------------------------------
for (const [rel, code] of [[sheetPath, sheet], [pagePath, page]]) {
  const stripped = strip(code)
  for (const re of FORBIDDEN_V1) {
    assert.doesNotMatch(stripped, re, `V1 decorator ${re} found in ${rel}`)
  }
}

console.log('PASS: reply submit loading-ux contract')
