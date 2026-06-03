#!/usr/bin/env node
/**
 * Topic-create Markdown-syntax contract.
 *
 * V2EX's /new/<node> compose form renders the syntax control as <select name="syntax" id="select_syntax">
 * whose Markdown <option> VALUE is numeric "1" (its visible label is "Markdown"). Posting the label string
 * ("markdown") is silently ignored, so the body renders in V2EX's DEFAULT syntax and all Markdown — images
 * (`![](url)`), bold, links — shows as plain text. This locks the fix: the client must parse the option's
 * real value from the live form and post THAT, never hardcode "markdown" to /new.
 *
 * Run: node scripts/test_topic_markdown_syntax_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'

const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
const check = (cond, label) => { (cond ? ok : failures).push(label) }

// ── static: parser exposes the parsed value; ApiService uses it ────────────────
const parser = read('shared/src/main/ets/parser/V2exWriteFormParser.ets')
check(/markdownSyntaxValue:\s*string/.test(parser), 'form interface carries markdownSyntaxValue')
check(/static extractSyntaxMarkdownValue\(/.test(parser), 'parser defines extractSyntaxMarkdownValue()')
check(parser.includes('select_syntax') && parser.includes("name=['\"]syntax['\"]"), 'parser matches the syntax select by name/id')

const api = read('shared/src/main/ets/network/ApiService.ets')
check(/fields\['syntax'\]\s*=\s*form\.markdownSyntaxValue/.test(api), 'createTopic posts the PARSED syntax value (not a hardcoded label) on the /new path')
check(!/fields\['syntax'\]\s*=\s*'markdown'[\s\S]{0,40}form\.actionPath/.test(api), 'createTopic does not hardcode syntax="markdown" to the /new form action')

// ── logic: replicate the parser regex and assert it extracts the VALUE ─────────
function extractSyntaxMarkdownValue(formHtml) {
  const selRe = /<select\b[^>]*(?:name=['"]syntax['"]|id=['"]select_syntax['"])[^>]*>[\s\S]*?<\/select>/i
  const sel = (formHtml.match(selRe) || [''])[0]
  if (!sel) return ''
  const re = /<option\b([^>]*)>([\s\S]*?)<\/option>/gi
  let m
  while ((m = re.exec(sel)) !== null) {
    const text = m[2].replace(/<[^>]*>/g, '').trim()
    if (/markdown/i.test(text)) {
      const v = m[1].match(/value\s*=\s*(['"])(.*?)\1/i)
      return v ? v[2] : ''
    }
  }
  return ''
}
// numeric-value form (the real V2EX /new/<node> shape, confirmed on device)
check(extractSyntaxMarkdownValue(
  '<select id="select_syntax" name="syntax" class="sl"><option value="0" selected="selected">Default</option><option value="1">Markdown</option></select>'
) === '1', 'regex extracts numeric "1" for the Markdown option (V2EX /new shape)')
// string-value variant still works
check(extractSyntaxMarkdownValue(
  '<select name="syntax"><option value="default">Default</option><option value="markdown">Markdown</option></select>'
) === 'markdown', 'regex extracts "markdown" when the option value is the string')
// no syntax select → empty (caller falls back to /write)
check(extractSyntaxMarkdownValue('<form><textarea name="content"></textarea></form>') === '', 'no syntax select → empty value')

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\ntopic markdown-syntax contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
process.exit(failures.length === 0 ? 0 : 1)
