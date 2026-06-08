#!/usr/bin/env node
/**
 * Compose-draft contract — per-topic 附言(append) + 编辑(edit) drafts.
 *
 * Append/edit each persist a draft keyed by `${mode}:${topicId}` in a multi-slot composeDrafts store,
 * separate from the single create topicDraft and the per-topic replyDrafts. This stops an in-progress
 * append/edit from leaking into (or being clobbered by) the new-topic draft, and lets an interrupted
 * (possibly paid) append be restored. Cleared on successful submit and wiped by clear-all.
 *
 * Run: node scripts/test_compose_draft_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'

const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
const check = (cond, label) => { (cond ? ok : failures).push(label) }

// ── DraftSettings: the compose-draft store + API ────────────────────────────────
const draft = read('shared/src/main/ets/settings/DraftSettings.ets')
check(/export interface ComposeDraft/.test(draft), 'ComposeDraft interface defined')
check(/KEY_COMPOSE_DRAFTS/.test(draft), 'composeDrafts store key defined')
for (const fn of ['composeKey', 'loadComposeDraft', 'saveComposeDraft', 'clearComposeDraft']) {
  check(new RegExp(`static (async )?${fn}\\(`).test(draft), `DraftSettings.${fn}() defined`)
}
check(/composeKey\(mode: string, topicId: number\): string \{\s*return `\$\{mode\}:\$\{topicId\}`/.test(draft), 'composeKey = `${mode}:${topicId}`')
const clearAll = draft.slice(draft.indexOf('static async clearAll('), draft.indexOf('static async exportReplyDraftsForBackup('))
check(/deleteKeysAndFlush\(store, \[KEY_TOPIC_DRAFT, KEY_REPLY_DRAFTS, KEY_COMPOSE_DRAFTS\]\)/.test(clearAll), 'clearAll wipes compose drafts too')

// ── logic: composeKey + slot replace semantics (replicated) ─────────────────────
const composeKey = (mode, id) => `${mode}:${id}`
check(composeKey('append', 123) === 'append:123' && composeKey('edit', 123) === 'edit:123', 'append/edit on the same topic get distinct keys')
// upsert by key, newest-first, drop empty
function upsert(all, mode, id, title, content) {
  const key = composeKey(mode, id)
  const cleanTitle = (title || '').trim(); const cleanContent = content || ''
  if (!cleanTitle && !cleanContent.trim()) return all.filter(d => d.key !== key)
  return [{ key, mode, topicId: id, title: cleanTitle, content: cleanContent }].concat(all.filter(d => d.key !== key))
}
let store = []
store = upsert(store, 'append', 1, '', 'note A')
store = upsert(store, 'edit', 1, 't', 'body')
check(store.length === 2 && store[0].key === 'edit:1', 'two drafts for one topic coexist; newest first')
store = upsert(store, 'append', 1, '', '   ')
check(store.length === 1 && store[0].key === 'edit:1', 'clearing append (empty) leaves the edit draft intact')

// ── editor wiring: load on open, overlay edit, clear on submit ──────────────────
const editor = read('entry/src/main/ets/pages/TopicEditorPage.ets')
check(editor.includes('this.loadComposeDraft()'), 'append restores its compose draft on open')
check(editor.includes('this.overlayComposeDraft()') && editor.slice(editor.indexOf('private loadEditForm(')).includes('overlayComposeDraft'), 'edit overlays a saved draft on top of the server prefill')
const persist = editor.slice(editor.indexOf('private persistDraft('), editor.indexOf('private persistDraft(') + 900)
check(persist.includes('saveComposeDraft(context, this.mode, this.targetTopicId') && persist.includes("this.mode === 'append' || this.mode === 'edit'"), 'persistDraft routes append/edit to saveComposeDraft(mode, targetTopicId, …)')
check((editor.match(/this\.clearComposeDraft\(\)/g) || []).length >= 2, 'compose draft cleared on both append + edit submit')
// aboutToDisappear persists for ALL modes now (not just create)
const disappear = editor.slice(editor.indexOf('aboutToDisappear('), editor.indexOf('build()'))
check(/if \(!this\.hasSubmitted\) \{\s*this\.persistDraft\(\)/.test(disappear) && !/this\.mode === 'create' && !this\.hasSubmitted/.test(disappear), 'leaving the editor persists the draft for every mode (create/append/edit)')

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\ncompose-draft contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
if (failures.length) process.exit(1)
