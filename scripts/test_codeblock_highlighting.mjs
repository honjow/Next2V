#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
// Syntax-highlighting helpers were extracted into a dedicated module; the block-token
// orchestration (normalizeCodeBlockTokens/buildCodeBlockToken/extractPre*) stays in MarkdownContent.
const internals = readFileSync('shared/src/main/ets/components/markdown/MarkdownCodeInternals.ets', 'utf8')

assert.match(internals, /function normalizeCodeLanguage\(lang: string\): string/)
assert.match(internals, /function highlightCodeLine\(code: string, lang: string\): CodeToken\[\]/)
assert.match(internals, /function highlightXmlLine\(code: string\): CodeToken\[\]/)
assert.match(internals, /function highlightJsonLine\(code: string\): CodeToken\[\]/)
assert.match(source, /private static normalizeCodeBlockTokens\(tokens: Token\[\]\): void/)
assert.match(source, /MarkdownContent\.normalizeCodeBlockTokens\(tokens\);/)
assert.match(source, /private static buildCodeBlockToken\(text: string, lang: string, raw: string\): Tokens\.Code/)
assert.match(source, /lang: normalizeCodeLanguage\(lang \|\| ''\)/)
assert.match(source, /private static extractPreCodeLanguageFromRenderedHtml\(raw: string, body: string\): string/)
assert.match(source, /MarkdownContent\.extractPreCodeLanguageFromRenderedHtml\(raw, body\)/)
assert.ok(source.includes("const codeOpen = /^\\s*(<code\\b[^>]*>)/i.exec(body || '')"))
assert.match(source, /data-language/)
assert.match(source, /data-lang/)
assert.match(source, /language-\(\[A-Za-z0-9_\+\.\-\]\+\)/)
assert.match(source, /lang-\(\[A-Za-z0-9_\+\.\-\]\+\)/)
assert.match(source, /brush\\s\*:\\s\*/)
assert.ok(source.includes("|pre|code)\\b/i.test(value)"))
assert.doesNotMatch(source.match(/if \(tag === 'pre'\) \{[\s\S]*?\n    \}/)?.[0] || '', /stripHtmlTags\(body\)/)

function decodeHtml(value) {
  if (!value) return ''
  let decoded = value
  for (let i = 0; i < 2; i++) {
    const next = decoded
      .replace(/&quot;/g, '"')
      .replace(/&#34;/g, '"')
      .replace(/&#x22;/gi, '"')
      .replace(/&#39;/g, "'")
      .replace(/&#x27;/gi, "'")
      .replace(/&apos;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&#60;/g, '<')
      .replace(/&#x3c;/gi, '<')
      .replace(/&gt;/g, '>')
      .replace(/&#62;/g, '>')
      .replace(/&#x3e;/gi, '>')
      .replace(/&nbsp;/g, ' ')
      .replace(/&#160;/g, ' ')
      .replace(/&#xa0;/gi, ' ')
      .replace(/&amp;/g, '&')
    if (next === decoded) break
    decoded = next
  }
  return decoded
}

function attr(tag, name) {
  const re = new RegExp(`${name}\\s*=\\s*(["'])(.*?)\\1`, 'i')
  const m = re.exec(tag || '')
  return m ? decodeHtml(m[2]).trim() : ''
}

function normalizeCodeLanguage(lang) {
  const raw = (lang || '').trim().toLowerCase()
  if (!raw) return ''
  const first = raw.split(/[\s,;]+/)[0].replace(/^language-/, '').replace(/^lang-/, '')
  if (first === 'js' || first === 'javascript' || first === 'jsx') return 'javascript'
  if (first === 'ts' || first === 'typescript' || first === 'tsx' || first === 'ets' || first === 'arkts') return 'typescript'
  if (first === 'xml' || first === 'html' || first === 'xhtml' || first === 'svg') return first === 'xml' ? 'xml' : 'html'
  if (first === 'json' || first === 'jsonc') return 'json'
  if (first === 'shell' || first === 'bash' || first === 'sh' || first === 'zsh') return 'shell'
  if (first === 'css') return 'css'
  return first || 'generic'
}

function extractCodeLanguageFromTag(tag) {
  if (!tag) return ''
  const dataLanguage = attr(tag, 'data-language')
  if (dataLanguage) return dataLanguage
  const dataLang = attr(tag, 'data-lang')
  if (dataLang) return dataLang
  const className = attr(tag, 'class')
  if (className) {
    let m = /(?:^|\s)language-([A-Za-z0-9_+.-]+)/i.exec(className)
    if (m?.[1]) return m[1]
    m = /(?:^|\s)lang-([A-Za-z0-9_+.-]+)/i.exec(className)
    if (m?.[1]) return m[1]
    m = /(?:^|\s)brush\s*:\s*([A-Za-z0-9_+.-]+)/i.exec(className)
    if (m?.[1]) return m[1]
  }
  return ''
}

function extractPreCodeLanguageFromRenderedHtml(raw, body) {
  const codeOpen = /^\s*(<code\b[^>]*>)/i.exec(body || '')
  const codeTag = codeOpen ? codeOpen[1] : ''
  const preOpen = /^(<pre\b[^>]*>)/i.exec(raw || '')
  const preTag = preOpen ? preOpen[1] : ''
  return normalizeCodeLanguage(extractCodeLanguageFromTag(codeTag) || extractCodeLanguageFromTag(preTag))
}

function extractPreCodeTextFromRenderedHtml(preHtml) {
  const pre = /^<pre\b[^>]*>([\s\S]*?)<\/pre>$/i.exec(preHtml || '')
  let body = pre ? pre[1] : (preHtml || '')
  const code = /^\s*<code\b[^>]*>([\s\S]*?)<\/code>\s*$/i.exec(body)
  if (code) body = code[1]
  return decodeHtml(body).replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim()
}

function markdownFenceToCodeBlock(markdown) {
  const m = /^```([^\n`]*)\n([\s\S]*?)\n```\s*$/m.exec(markdown || '')
  assert.ok(m, 'markdown fence fixture must parse')
  return { type: 'code', text: m[2], lang: normalizeCodeLanguage(m[1] || '') }
}

function renderedPreToCodeBlock(html) {
  const m = /^(<pre\b[^>]*>([\s\S]*?)<\/pre>)$/i.exec(html || '')
  assert.ok(m, 'rendered pre fixture must parse')
  return {
    type: 'code',
    text: extractPreCodeTextFromRenderedHtml(m[1]),
    lang: extractPreCodeLanguageFromRenderedHtml(m[1], m[2]),
  }
}

const xmlCode = '<video>\n  <graphics api="webgpu">ok</graphics>\n</video>'
assert.deepEqual(
  markdownFenceToCodeBlock('```xml\n' + xmlCode + '\n```'),
  renderedPreToCodeBlock(`<pre><code class="language-xml">${xmlCode.replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')}</code></pre>`),
)

const escaped = '<pre><code>&lt;video&gt;\n  &lt;model name=&quot;cube&quot; /&gt;\n  &lt;graphics api=&quot;webgpu&quot;&gt;ok&lt;/graphics&gt;\n&lt;/video&gt;</code></pre>'
const escapedText = renderedPreToCodeBlock(escaped).text
assert.match(escapedText, /<video>/)
assert.match(escapedText, /<graphics api="webgpu">ok<\/graphics>/)
assert.equal(escapedText.includes('&lt;'), false)

const langFixtures = [
  ['<pre><code class="language-xml">x</code></pre>', 'xml'],
  ['<pre><code class="lang-js">x</code></pre>', 'javascript'],
  ['<pre><code class="brush: js">x</code></pre>', 'javascript'],
  ['<pre><code data-lang="json">x</code></pre>', 'json'],
  ['<pre><code data-language="bash">x</code></pre>', 'shell'],
  ['<pre class="language-html"><code>x</code></pre>', 'html'],
  ['<pre><code>x</code></pre>', ''],
]
for (const [html, lang] of langFixtures) assert.equal(renderedPreToCodeBlock(html).lang, lang, html)

function push(tokens, type, text) {
  if (!text) return
  const last = tokens[tokens.length - 1]
  if (last?.type === type) last.text += text
  else tokens.push({ type, text })
}
function tokenizeXmlTag(tag) {
  const tokens = []
  let index = 0
  const open = /^<\/?/.exec(tag || '')
  if (open) { push(tokens, 'punctuation', open[0]); index = open[0].length }
  const name = /^[A-Za-z_:\-][\w:.\-]*/.exec(tag.slice(index))
  if (name) { push(tokens, 'tag', name[0]); index += name[0].length }
  while (index < tag.length) {
    const rest = tag.slice(index)
    const close = /^\s*\/?>$/.exec(rest)
    if (close) {
      const spaces = rest.slice(0, rest.length - (rest.endsWith('/>') ? 2 : 1))
      push(tokens, 'text', spaces)
      push(tokens, 'punctuation', rest.endsWith('/>') ? '/>' : '>')
      break
    }
    const a = /^(\s+)([A-Za-z_:\-][\w:.\-]*)(\s*=\s*)?((?:"[^"]*"|'[^']*'))?/.exec(rest)
    if (!a || a[0].length === 0) { push(tokens, 'text', rest[0]); index++; continue }
    push(tokens, 'text', a[1] || '')
    push(tokens, 'attr', a[2] || '')
    push(tokens, 'punctuation', a[3] || '')
    push(tokens, 'string', a[4] || '')
    index += a[0].length
  }
  return tokens
}
function highlightXmlLine(code) {
  const tokens = []
  const re = /<!--[\s\S]*?-->|<\/?[A-Za-z][^>]*?\/?>/g
  let last = 0, m
  while ((m = re.exec(code || ''))) {
    if (m.index > last) push(tokens, 'text', code.slice(last, m.index))
    if (m[0].startsWith('<!--')) push(tokens, 'comment', m[0])
    else for (const t of tokenizeXmlTag(m[0])) push(tokens, t.type, t.text)
    last = re.lastIndex
  }
  if (last < (code || '').length) push(tokens, 'text', code.slice(last))
  return tokens
}
function highlightJsonLine(code) {
  const tokens = []
  const re = /"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\],:]/g
  let last = 0, m
  while ((m = re.exec(code || ''))) {
    if (m.index > last) push(tokens, 'text', code.slice(last, m.index))
    const v = m[0]
    const after = code.slice(re.lastIndex).replace(/^\s+/, '')
    if (v.startsWith('"')) push(tokens, after.startsWith(':') ? 'key' : 'string', v)
    else if (/^-?\d/.test(v)) push(tokens, 'number', v)
    else if (v === 'true' || v === 'false' || v === 'null') push(tokens, 'boolean', v)
    else push(tokens, 'punctuation', v)
    last = re.lastIndex
  }
  if (last < (code || '').length) push(tokens, 'text', code.slice(last))
  return tokens
}

const xmlTokens = highlightXmlLine('<!-- hi --><video muted="true">text</video>')
assert.deepEqual(xmlTokens.map(t => t.type), ['comment', 'punctuation', 'tag', 'text', 'attr', 'punctuation', 'string', 'punctuation', 'text', 'punctuation', 'tag', 'punctuation'])
assert.equal(xmlTokens.find(t => t.type === 'tag')?.text, 'video')
assert.equal(xmlTokens.find(t => t.type === 'attr')?.text, 'muted')
assert.equal(xmlTokens.find(t => t.type === 'string')?.text, '"true"')

const jsonTokens = highlightJsonLine('{"name":"v2", "count":2, "ok":true, "none":null}')
assert.deepEqual(jsonTokens.filter(t => t.type !== 'text').map(t => t.type), [
  'punctuation', 'key', 'punctuation', 'string', 'punctuation', 'key', 'punctuation', 'number', 'punctuation', 'key', 'punctuation', 'boolean', 'punctuation', 'key', 'punctuation', 'boolean', 'punctuation',
])

console.log('PASS: codeblock language extraction, unified block shape, escaped literal code, and XML/JSON token classifications')
