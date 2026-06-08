#!/usr/bin/env node
/**
 * 附言(append) write-form contract.
 *
 * The 附言 form at GET /append/topic/<id> (login-gated, owner-only) was captured live and is the
 * topic-create form minus the title: a content <textarea id="topic_supplement" name="content">, a
 * syntax <select name="syntax"> (Default=0 selected / Markdown=1), and a hidden <input name="once">.
 * Submit is POST to the same /append/topic/<id>; success is a 301/302 redirect back to /t/<id>.
 * V2EX rule (printed on the form): 每个主题至多 3 条附言; 每千字 20 铜币. This contract locks the parser
 * (extractAppendForm) so a V2EX form-structure change is caught before it silently breaks appending.
 *
 * Run: node scripts/test_topic_append_form_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'

const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
const check = (cond, label) => { (cond ? ok : failures).push(label) }

// ── static: parser exposes extractAppendForm + the append form interface ───────
const parser = read('shared/src/main/ets/parser/V2exWriteFormParser.ets')
check(/export interface V2exAppendWriteForm/.test(parser), 'parser exports V2exAppendWriteForm interface')
check(/static extractAppendForm\(/.test(parser), 'parser defines extractAppendForm()')
check(parser.includes('topic_supplement'), 'extractAppendForm targets the append textarea id=topic_supplement')
check(/markdownSyntaxValue/.test(parser.slice(parser.indexOf('V2exAppendWriteForm'))), 'append form carries markdownSyntaxValue (syntax select exists on the real form)')

// ── logic: replicate the parser against the REAL captured append-form HTML ──────
// Mirrors V2exWriteFormParser.extractAppendForm's helper logic.
function extractFormHtml(html, markers) {
  for (const marker of markers) {
    const pos = html.search(marker)
    if (pos < 0) continue
    const open = html.lastIndexOf('<form', pos)
    const close = html.indexOf('</form>', pos)
    if (open < 0 || close < 0) continue
    return html.substring(open, close + '</form>'.length)
  }
  return ''
}
const attr = (tag, name) => {
  const m = tag.match(new RegExp(`${name}\\s*=\\s*(['"])(.*?)\\1`, 'i'))
  return m ? m[2] : ''
}
function parseAppend(html) {
  const formHtml = extractFormHtml(html, [/id=['"]topic_supplement['"]/i, /<textarea[^>]*name=['"]content['"][^>]*>/i])
  if (!formHtml) return null
  const action = attr(formHtml.slice(0, formHtml.indexOf('>') + 1), 'action')
  const hidden = {}
  for (const m of formHtml.matchAll(/<input\b[^>]*>/gi)) {
    if ((attr(m[0], 'type') || 'text').toLowerCase() === 'hidden' && attr(m[0], 'name')) hidden[attr(m[0], 'name')] = attr(m[0], 'value')
  }
  let content = ''
  for (const m of formHtml.matchAll(/<textarea\b[^>]*>/gi)) {
    if (attr(m[0], 'id') === 'topic_supplement' && attr(m[0], 'name')) { content = attr(m[0], 'name'); break }
    if (!content && attr(m[0], 'name')) content = attr(m[0], 'name')
  }
  const sel = (formHtml.match(/<select\b[^>]*(?:name=['"]syntax['"]|id=['"]select_syntax['"])[^>]*>[\s\S]*?<\/select>/i) || [''])[0]
  let md = ''
  for (const m of sel.matchAll(/<option\b([^>]*)>([\s\S]*?)<\/option>/gi)) {
    if (/markdown/i.test(m[2].replace(/<[^>]*>/g, '').trim())) { md = attr(`<option ${m[1]}>`, 'value'); break }
  }
  if (!action || !content) return null
  return { actionPath: action, contentField: content, hiddenFields: hidden, markdownSyntaxValue: md }
}

// Verbatim shape of the live append form (captured from /append/topic/1217446).
const APPEND_FORM = `
<div id="Main"><div class="box"><div class="cell">
<form method="post" action="/append/topic/1217446">
  <textarea class="mle tall" name="content" placeholder="附言内容" id="topic_supplement"></textarea>
  <select name="syntax" id="select_syntax" class="super normal button editor_syntax"><option value="0" selected="selected">Default</option><option value="1">Markdown</option></select>
  <input type="hidden" value="98213abc" name="once" />
  <input type="submit" class="super normal button" value="提交" />
</form>
</div></div></div>`

const f = parseAppend(APPEND_FORM)
check(f !== null, 'extractAppendForm parses the live append form')
check(f && f.actionPath === '/append/topic/1217446', 'action = /append/topic/<id>')
check(f && f.contentField === 'content', 'content field name = content (id=topic_supplement)')
check(f && f.hiddenFields.once === '98213abc', 'once hidden field captured')
check(f && f.markdownSyntaxValue === '1', 'Markdown syntax option VALUE = 1 (Default=0 is the form default)')
// a page that is NOT the append form (signin gate / window closed) → null, never a bogus submit
check(parseAppend('<form action="/signin"><input name="next"></form>') === null, 'non-append form (signin gate) → null')

// ── static: ApiService.appendTopicWithCookie wires the form → POST correctly ────
const api = read('shared/src/main/ets/network/ApiService.ets')
const append = api.slice(api.indexOf('async appendTopicWithCookie('), api.indexOf('async syncBlockedListsFromCookieHtmlSources('))
check(append.length > 0, 'ApiService defines appendTopicWithCookie')
check(/\/append\/topic\/\$\{topicId\}/.test(append), 'GET/POST targets /append/topic/<id>')
check(append.includes('V2exWriteFormParser.extractAppendForm('), 'append uses extractAppendForm')
check(append.includes("fields['content']") && /fields\['syntax'\]\s*=\s*form\.markdownSyntaxValue/.test(append), 'append posts content + the parsed Markdown syntax value')
check(append.includes('不是你创建的主题') && append.includes('ApiErrors.notTopicOwner()'), 'append maps 不是你创建的主题 → notTopicOwner')
check(append.includes('ApiService.isTopicLocation(res.location, topicId)'), 'append success = redirect back to /t/<id>')
check(append.includes('ApiErrors.appendBodyRequired()'), 'append guards empty body')
check(/allowErrorWithLocation|,\s*\n\s*true,\s*\n\s*\)/.test(append) || append.includes('true,\n    )'), 'append tolerates redirect-with-non-2xx (allowErrorWithLocation)')

// ── static: ApiError carries the new typed codes + factories ────────────────────
const apiErr = read('shared/src/main/ets/network/ApiError.ets')
for (const code of ['APPEND_BODY_REQUIRED', 'PARSE_APPEND_FORM_FAILED', 'NOT_TOPIC_OWNER', 'APPEND_SUBMIT_UNCONFIRMED']) {
  check(apiErr.includes(`${code} = '${code}'`), `ApiErrorCode.${code} defined`)
}
for (const fn of ['appendBodyRequired', 'parseAppendFormFailed', 'notTopicOwner', 'appendSubmitUnconfirmed']) {
  check(new RegExp(`static ${fn}\\(`).test(apiErr), `ApiErrors.${fn}() factory defined`)
}

// ── static: ownership gate + menu wiring + editor append mode ───────────────────
const ownership = read('shared/src/main/ets/state/TopicDetailOwnershipState.ets')
check(/@Trace canAppend/.test(ownership) && /TOPIC_APPEND_UNLOCK_SEC/.test(ownership), 'TopicDetailOwnershipState has canAppend gated on the append-unlock window')
check(/ageSec >= TOPIC_APPEND_UNLOCK_SEC/.test(ownership) && /isCurrentUserOp/.test(ownership), 'canAppend requires OP + >= unlock seconds')

const coord = read('entry/src/main/ets/model/TopicDetailTitleBarCoordinator.ets')
check(coord.includes("'appendTopic'") && /R_TOPIC_ACTION_APPEND/.test(coord), 'coordinator declares the appendTopic action with its label')

const index = read('entry/src/main/ets/pages/Index.ets')
const visible = index.slice(index.indexOf('private isTopicActionVisible('), index.indexOf('private topicDetailTitleActionIcon('))
check(visible.includes("action === 'appendTopic'") && visible.includes('topicDetailOwnership.canAppend') && visible.includes('routeTopicId === topicId'), 'Index gates appendTopic by ownership.canAppend + routeTopicId')
check(/connectTopicComposeTarget\(\)\.mode/.test(index) && index.includes('R_TOPIC_ACTION_APPEND'), 'Index titles the editor 增加附言 in append mode')
check(index.includes("publishTopicComposeTarget('create', 0)"), 'Home compose resets the compose target to create')

const editor = read('entry/src/main/ets/pages/TopicEditorPage.ets')
check(/@Local private mode: string/.test(editor) && editor.includes("this.mode === 'append'"), 'editor carries a compose mode and branches on append')
check(editor.includes('this.api.appendTopicWithCookie(') && editor.includes('submitAppend('), 'editor append submit calls appendTopicWithCookie')
check(editor.includes('confirmAppendSubmit(') && editor.includes('R_EDITOR_CONFIRM_APPEND_FORMAT'), 'editor shows an append cost-confirm dialog')
check(/if \(this\.mode === 'append'\)\s*\{\s*return\s*\}/.test(editor.slice(editor.indexOf('private scheduleSaveDraft('))), 'append mode never persists a topic draft (scheduleSaveDraft gated)')

const detail = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
check(detail.includes("action === 'appendTopic'") && detail.includes('openAppendEditor('), 'detail dispatches appendTopic to the append editor')
check(detail.includes("publishTopicComposeTarget('append'") && detail.includes('publishTopicDetailOwnership('), 'detail publishes ownership + sets append compose target')

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\ntopic append-form contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
if (failures.length) process.exit(1)
