#!/usr/bin/env node
/**
 * Edit-topic write-form contract.
 *
 * V2EX serves /edit/topic/<id> only to the author and only within the 600s edit window. The form mirrors
 * the create form but the title input + content textarea come PRE-FILLED and the syntax <select> has the
 * topic's current option pre-selected. Submit is POST to /edit/topic/<id>; success = redirect to /t/<id>.
 * Editing is free. This contract locks extractTopicEditForm (incl. the prefill extraction) and the edit
 * API + UI wiring so a V2EX form change or a regression is caught before edit silently breaks.
 *
 * Run: node scripts/test_topic_edit_form_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'

const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
const check = (cond, label) => { (cond ? ok : failures).push(label) }

// ── static: parser exposes extractTopicEditForm + prefill helpers ───────────────
const parser = read('shared/src/main/ets/parser/V2exWriteFormParser.ets')
check(/export interface V2exTopicEditForm/.test(parser), 'parser exports V2exTopicEditForm interface')
check(/static extractTopicEditForm\(/.test(parser), 'parser defines extractTopicEditForm()')
for (const field of ['prefillTitle', 'prefillContent', 'currentSyntaxValue']) {
  check(parser.includes(field), `edit form carries ${field}`)
}
check(/findTextareaInnerText\(/.test(parser) && /extractSelectedSyntaxValue\(/.test(parser), 'parser has prefill helpers (textarea inner text, selected syntax)')
check(/findTextareaName\(formHtml, 'topic_title'\)/.test(parser), 'edit title read as a textarea (name=title, id=topic_title), not an <input>')
check(/extractPageOnce\(/.test(parser) && /pageOnce/.test(parser), 'parser extracts the page-level once (edit form has no hidden once)')

// ── logic: replicate the prefill extraction against a realistic edit form ────────
const attr = (tag, name) => {
  const m = tag.match(new RegExp(`${name}\\s*=\\s*(['"])(.*?)\\1`, 'i'))
  return m ? m[2] : ''
}
const decode = (s) => (s || '').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>')
function parseEdit(html) {
  const open = html.lastIndexOf('<form', html.search(/id=['"]topic_content['"]/i))
  const close = html.indexOf('</form>', open)
  const formHtml = html.substring(open, close + 7)
  const action = attr(formHtml.slice(0, formHtml.indexOf('>') + 1), 'action')
  // The edit form's title is a <textarea name="title">, not an <input> (see test_topic_edit on device).
  const tt = formHtml.match(/<textarea\b[^>]*name=['"]title['"][^>]*>([\s\S]*?)<\/textarea>/i)
  const prefillTitle = tt ? decode(tt[1]) : ''
  const ta = formHtml.match(/<textarea\b[^>]*name=['"]content['"][^>]*>([\s\S]*?)<\/textarea>/i)
  const prefillContent = ta ? decode(ta[1]) : ''
  const sel = (formHtml.match(/<select\b[^>]*name=['"]syntax['"][^>]*>[\s\S]*?<\/select>/i) || [''])[0]
  let currentSyntaxValue = ''
  for (const m of sel.matchAll(/<option\b([^>]*)>([\s\S]*?)<\/option>/gi)) {
    if (/\bselected\b/i.test(m[1])) { currentSyntaxValue = attr(`<option ${m[1]}>`, 'value'); break }
  }
  // once is page-level (NOT a hidden field) on the edit form — V2EX takes it as a ?once= query param.
  const pageOnce = (html.match(/[?&]once=(\d+)/) || html.match(/once=(\d+)/) || [])[1] || ''
  return { action, prefillTitle, prefillContent, currentSyntaxValue, pageOnce }
}

const EDIT_FORM = `
<a href="/?once=55667788" class="light-toggle"><img src="/static/x.png"></a>
<div id="Main"><form method="post" action="/edit/topic/1217446" id="topic_form">
  <textarea name="title" id="topic_title" class="sl">我的沙盒主题 &amp; 测试</textarea>
  <select name="syntax" id="select_syntax"><option value="0">Default</option><option value="1" selected="selected">Markdown</option></select>
  <textarea name="content" id="topic_content" class="mle">这是正文\n第二行 &lt;b&gt;</textarea>
  <input type="submit" value="保存" />
</form></div>`

const e = parseEdit(EDIT_FORM)
check(e.action === '/edit/topic/1217446', 'edit action = /edit/topic/<id>')
check(e.prefillTitle === '我的沙盒主题 & 测试', 'title prefilled + HTML-decoded from the title textarea inner text')
check(e.prefillContent === '这是正文\n第二行 <b>', 'body prefilled + HTML-decoded from the content textarea inner text')
check(e.currentSyntaxValue === '1', 'current syntax = the pre-selected option value (Markdown=1)')
check(e.pageOnce === '55667788', 'page-level once extracted (edit form has no hidden once)')

// ── static: edit API mirrors create/reply, with the window-closed guard ─────────
const api = read('shared/src/main/ets/network/ApiService.ets')
check(/async fetchTopicEditFormWithCookie\(/.test(api), 'ApiService.fetchTopicEditFormWithCookie defined')
check(/async editTopicWithCookie\(/.test(api), 'ApiService.editTopicWithCookie defined')
const editApi = api.slice(api.indexOf('async fetchTopicEditFormWithCookie('), api.indexOf('async syncBlockedListsFromCookieHtmlSources('))
check(editApi.includes('/edit/topic/${topicId}'), 'edit hits /edit/topic/<id>')
check(editApi.includes('extractTopicEditForm(') && editApi.includes('ApiErrors.editWindowClosed()'), 'no editable form served → EDIT_WINDOW_CLOSED')
check(editApi.includes('?once=') && editApi.includes('form.pageOnce'), 'edit submit appends ?once= (edit form has no hidden once; without it the POST is a silent no-op)')
check(editApi.includes('不是你创建的主题') && editApi.includes('ApiErrors.notTopicOwner()'), 'edit maps 不是你创建的主题 → notTopicOwner')
check(editApi.includes('ApiService.isTopicLocation(res.location, topicId)'), 'edit success = redirect back to /t/<id>')
const apiErr = read('shared/src/main/ets/network/ApiError.ets')
check(apiErr.includes("EDIT_WINDOW_CLOSED = 'EDIT_WINDOW_CLOSED'") && /static editWindowClosed\(/.test(apiErr), 'EDIT_WINDOW_CLOSED code + factory defined')

// ── static: ownership canEdit + menu/dispatch + editor edit mode ────────────────
const ownership = read('shared/src/main/ets/state/TopicDetailOwnershipState.ets')
check(/@Trace canEdit/.test(ownership) && /ageSec < TOPIC_EDIT_WINDOW_SEC/.test(ownership), 'canEdit gated on OP + within the edit window')

const coord = read('entry/src/main/ets/model/TopicDetailTitleBarCoordinator.ets')
check(coord.includes("'editTopic'") && /\$r\('app\.string\.topic_action_edit'\)/.test(coord), 'coordinator declares the editTopic action')

const index = read('entry/src/main/ets/pages/Index.ets')
const visible = index.slice(index.indexOf('private isTopicActionVisible('), index.indexOf('private topicDetailTitleActionIcon('))
check(visible.includes("action === 'editTopic'") && visible.includes('topicDetailOwnership.canEdit'), 'Index gates editTopic by ownership.canEdit')
check(index.includes("composeMode === 'edit'") && /\$r\('app\.string\.topic_action_edit'\)/.test(index), 'Index titles the editor 编辑主题 in edit mode')

const editor = read('entry/src/main/ets/pages/TopicEditorPage.ets')
check(editor.includes("this.mode === 'edit'") && editor.includes('loadEditForm(') && editor.includes('submitEdit('), 'editor has an edit mode (prefill + submit)')
check(editor.includes('this.api.fetchTopicEditFormWithCookie(') && editor.includes('this.api.editTopicWithCookie('), 'editor prefills from + submits to the edit API')
check(!/confirmAppendSubmit[\s\S]{0,400}this\.mode === 'edit'/.test(editor) || editor.includes("Edit is free"), 'edit has no cost dialog (free)')

const detail = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
check(detail.includes("action === 'editTopic'") && detail.includes('openEditEditor(') && detail.includes("publishTopicComposeTarget('edit'"), 'detail dispatches editTopic → edit editor')

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\ntopic edit-form contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
if (failures.length) process.exit(1)
