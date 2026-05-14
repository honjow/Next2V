#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')

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
      .replace(/&gt;/g, '>')
      .replace(/&#62;/g, '>')
      .replace(/&nbsp;/g, ' ')
      .replace(/&#160;/g, ' ')
      .replace(/&amp;/g, '&')
    if (next === decoded) break
    decoded = next
  }
  return decoded
}

function stripTags(value) {
  return decodeHtml(String(value || '').replace(/<[^>]+>/g, ''))
    .replace(/[ \t\f\v\r\n]+/g, ' ')
    .trim()
}

function htmlAttr(tag, name) {
  const re = new RegExp(`${name}\\s*=\\s*(["'])(.*?)\\1`, 'i')
  const match = re.exec(tag || '')
  return match ? decodeHtml(match[2]).trim() : ''
}

function inlineHtmlTokens(value) {
  const tokens = []
  const source = value || ''
  const re = /<a\b[^>]*>[\s\S]*?<\/a>|<code\b[^>]*>[\s\S]*?<\/code>|<(strong|b|em|i)\b[^>]*>[\s\S]*?<\/\1>/gi
  let last = 0
  let match
  const append = (text) => {
    const clean = decodeHtml(text || '').replace(/[ \t\f\v\r\n]+/g, ' ')
    if (clean) tokens.push({ type: 'text', text: clean })
  }
  while ((match = re.exec(source))) {
    append(source.slice(last, match.index))
    const part = match[0]
    if (/^<a/i.test(part)) tokens.push({ type: 'link', href: htmlAttr(part, 'href'), text: stripTags(part), tokens: [{ type: 'text', text: stripTags(part) }] })
    else if (/^<code/i.test(part)) tokens.push({ type: 'codespan', text: stripTags(part) })
    else if (/^<(strong|b)/i.test(part)) tokens.push({ type: 'strong', text: stripTags(part), tokens: [{ type: 'text', text: stripTags(part) }] })
    else if (/^<(em|i)/i.test(part)) tokens.push({ type: 'em', text: stripTags(part), tokens: [{ type: 'text', text: stripTags(part) }] })
    last = re.lastIndex
  }
  append(source.slice(last).replace(/<[^>]+>/g, ''))
  return tokens
}

function cell(raw, header = false) {
  const tokens = inlineHtmlTokens(raw)
  return { text: tokens.map(t => t.text || '').join(''), tokens, header }
}

function htmlTableToToken(html) {
  const rows = []
  for (const tr of html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)) {
    const cells = []
    for (const td of tr[1].matchAll(/<(th|td)\b[^>]*>([\s\S]*?)<\/\1>/gi)) {
      cells.push(cell(td[2], td[1].toLowerCase() === 'th'))
    }
    if (cells.length) rows.push(cells)
  }
  const firstBody = rows.findIndex(row => !row.every(c => c.header))
  const headerRows = rows.filter(row => row.every(c => c.header))
  return {
    type: 'table',
    headers: headerRows[0] ?? [],
    rows: rows.slice(firstBody < 0 ? headerRows.length : firstBody),
  }
}

function markdownInlineTokens(value) {
  const tokens = []
  const re = /\[([^\]\n]+)\]\(\s*([^\s)]+)\s*\)|\*\*([^*]+)\*\*|`([^`]+)`/g
  let last = 0
  let match
  while ((match = re.exec(value || ''))) {
    if (match.index > last) tokens.push({ type: 'text', text: value.slice(last, match.index) })
    if (match[2]) tokens.push({ type: 'link', href: match[2], text: match[1], tokens: [{ type: 'text', text: match[1] }] })
    else if (match[3]) tokens.push({ type: 'strong', text: match[3], tokens: [{ type: 'text', text: match[3] }] })
    else if (match[4]) tokens.push({ type: 'codespan', text: match[4] })
    last = match.index + match[0].length
  }
  if (last < (value || '').length) tokens.push({ type: 'text', text: value.slice(last) })
  return tokens
}

function splitMdRow(line) {
  const value = line.trim().replace(/^\|/, '').replace(/\|$/, '')
  return value.split('|').map(cell => cell.replace(/\\\|/g, '|').trim())
}

function markdownTableToToken(markdown) {
  const lines = markdown.trim().split(/\r?\n/)
  const headers = splitMdRow(lines[0]).map(value => ({ text: markdownInlineTokens(value).map(t => t.text || '').join(''), tokens: markdownInlineTokens(value), header: true }))
  const rows = lines.slice(2).map(line => splitMdRow(line).map(value => ({ text: markdownInlineTokens(value).map(t => t.text || '').join(''), tokens: markdownInlineTokens(value), header: false })))
  return { type: 'table', headers, rows }
}

const topic1212780Table = `<table><thead><tr><th>Agent</th><th>总成本</th><th>请求数</th><th>Cache 命中率</th></tr></thead><tbody><tr><td><strong>OpenClacky</strong></td><td><strong>$5.10</strong></td><td><strong>51</strong></td><td><strong>90.6%</strong></td></tr><tr><td>Codex</td><td>$5.35</td><td>34</td><td>88.9%</td></tr><tr><td>Claude Code</td><td>$6.25</td><td>40</td><td>85.1%</td></tr><tr><td>Gemini CLI</td><td>$7.12</td><td>38</td><td>80.2%</td></tr></tbody></table>`
const topic1212780Rows = [...topic1212780Table.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)]
assert.equal(topic1212780Rows.length, 5, '1212780 HTML table fixture row regex extracts header + 4 body rows')
assert.ok(topic1212780Rows[0][1].includes('<th>Agent</th>'), '1212780 extracted header row includes Agent header')
assert.ok(topic1212780Rows[1][1].includes('<strong>OpenClacky</strong>'), '1212780 extracted first body row includes OpenClacky')
const corruptedBackspaceRows = [...topic1212780Table.matchAll(/<tr\u0008[^>]*>([\s\S]*?)<\/tr>/gi)]
assert.equal(corruptedBackspaceRows.length, 0, 'test fixture proves a literal backspace in row regex would swallow the table')

const htmlToken = htmlTableToToken(topic1212780Table)
assert.equal(htmlToken.type, 'table')
assert.deepEqual(htmlToken.headers.map(c => c.text), ['Agent', '总成本', '请求数', 'Cache 命中率'])
assert.equal(htmlToken.rows.length, 4)
assert.deepEqual(htmlToken.rows[0].map(c => c.text), ['OpenClacky', '$5.10', '51', '90.6%'])
assert.ok(htmlToken.rows[0].every(c => c.tokens[0]?.type === 'strong'), '1212780 first body row strong tokens are preserved')

const mdToken = markdownTableToToken(`| Agent | 总成本 | 请求数 | Cache 命中率 |\n| --- | ---: | ---: | ---: |\n| **OpenClacky** | **$5.10** | **51** | **90.6%** |\n| [Codex](https://example.com/codex) | \`$5.35\` | 34 | 88.9% |`)
assert.equal(mdToken.type, 'table')
assert.deepEqual(mdToken.headers.map(c => c.text), htmlToken.headers.map(c => c.text))
assert.equal(mdToken.rows[0][0].tokens[0].type, 'strong')
assert.equal(mdToken.rows[1][0].tokens[0].type, 'link')
assert.equal(mdToken.rows[1][1].tokens[0].type, 'codespan')

assert.match(source, /type RenderBlockKind = [^;]*"table"/, 'RenderBlockKind includes table')
assert.match(source, /interface RenderTableToken[\s\S]*headers: RenderTableCell\[\][\s\S]*rows: RenderTableCell\[\]\[\]/, 'RenderTableToken shape is declared')
const htmlTableParserStart = source.indexOf('private static htmlTableToRenderTableToken')
const htmlTableParserEnd = source.indexOf('private static htmlTableCellToRenderCell', htmlTableParserStart)
const htmlTableParserSource = htmlTableParserStart >= 0 && htmlTableParserEnd > htmlTableParserStart ? source.slice(htmlTableParserStart, htmlTableParserEnd) : ''
assert.ok(htmlTableParserSource, 'HTML table parser source is present')
assert.doesNotMatch(htmlTableParserSource, /\u0008/, 'HTML table parser source must not contain literal backspace control characters')
assert.doesNotMatch(htmlTableParserSource, /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/, 'HTML table parser regex-relevant source must not contain ASCII control characters')
assert.ok(source.includes(String.raw`const rowRe = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;`), 'production HTML table row regex uses a source-level \\b word boundary')
assert.match(source, /htmlTableToRenderTableToken\(raw: string[\s\S]*const cellRe = \/<\(th\|td\)\\b\(\[\^>\]\*\)>\(\[\\s\\S\]\*\?\)<\\\/\\1>\/gi;[\s\S]*type: 'table'/, 'HTML table parser creates V2Next-owned table tokens with th/td parsing')
assert.match(source, /normalizeMarkdownTableToken\(token: Token\): RenderTableToken \| null[\s\S]*type: 'table'/, 'Markdown GFM table tokens normalize into V2Next table tokens')
assert.match(source, /parseMarkdownInlineTextTokens\(text: string\)[\s\S]*type: 'strong'[\s\S]*type: 'em'[\s\S]*type: 'codespan'/, 'Markdown fallback table cells preserve strong/em/codespan inline tokens')
assert.doesNotMatch(source, /\u0001|\x01/, 'production table parser must not contain a corrupted regex backreference')
assert.match(source, /if \(token\.type === "table"\)[\s\S]*MarkdownTable\(/, 'RenderProcessedToken renders table tokens before plain fallback')
assert.doesNotMatch(source, /lexer\(MarkdownContent\.convertHtmlTable\(raw\)/, 'ordinary HTML table path must not lexer(convertHtmlTable(raw))')
assert.match(source, /token\.type === "table"[\s\S]*MarkdownTable/, 'Markdown table character fallback regression is covered by structured renderer')
assert.match(source, /token\.type === IMAGE_TABLE_MONO[\s\S]*MarkdownImageTable/, 'image table special case remains separate')
const markdownTableStruct = source.match(/struct MarkdownTable[\s\S]*?\n}\n\n@Component/)
assert.ok(markdownTableStruct, 'MarkdownTable component is present')
assert.doesNotMatch(markdownTableStruct[0], /MarkdownContent\.buildTextToken\(/, 'MarkdownTable must not call MarkdownContent private helpers from outside the class')
assert.doesNotMatch(markdownTableStruct[0], /cellWidth\(\): number \{\s*return 116;\s*\}/, 'MarkdownTable must not use the old fixed 116vp cell width strategy')
assert.doesNotMatch(markdownTableStruct[0], /columnCount\(\)\s*\*\s*this\.cellWidth\(\)/, 'MarkdownTable width must not be columnCount()*cellWidth() fixed strategy')
assert.doesNotMatch(markdownTableStruct[0], /@State private columnWidths|measuredColumnWidth|updateColumnWidth|onSizeChange/, 'MarkdownTable ordinary layout must not use runtime natural measurement column widths')
assert.match(source, /const TABLE_MIN_CELL_WIDTH = \d+;/, 'MarkdownTable declares a systematic min column width clamp')
assert.match(source, /const TABLE_MAX_CELL_WIDTH = \d+;/, 'MarkdownTable declares a systematic max column width clamp')
assert.match(source, /const TABLE_CELL_HORIZONTAL_PADDING = ThemeConstants\.SPACE_SM \* 2;/, 'MarkdownTable includes cell horizontal padding in width estimates')
assert.match(markdownTableStruct[0], /textDisplayUnits\(text: string\): number[\s\S]*TABLE_ASCII_DISPLAY_UNIT[\s\S]*TABLE_WIDE_DISPLAY_UNIT/, 'MarkdownTable estimates text display units with ASCII and wide-character weighting')
assert.match(markdownTableStruct[0], /estimatedColumnWidth\(index: number\): number[\s\S]*this\.tableToken\.headers\[index\][\s\S]*for \(const row of this\.tableToken\.rows\)[\s\S]*Math\.min\(TABLE_MAX_CELL_WIDTH, Math\.max\(TABLE_MIN_CELL_WIDTH, width\)\)/, 'MarkdownTable estimates each column from header and row text with min/max clamp')
assert.match(markdownTableStruct[0], /columnWidth\(index: number\): number[\s\S]*return this\.estimatedColumnWidth\(index\)/, 'MarkdownTable columnWidth is data-estimated, not fixed equal width')
assert.match(markdownTableStruct[0], /tableMinWidth\(\): number[\s\S]*width \+= this\.columnWidth\(index\)/, 'MarkdownTable table min width sums estimated column widths')
assert.match(markdownTableStruct[0], /\.border\(\{[\s\S]*width: \{ right: columnIndex < this\.columnCount\(\) - 1 \? 1 : 0 \}[\s\S]*color: TABLE_BORDER_COLOR/, 'MarkdownTable draws vertical separators with explicit cell right borders')
assert.doesNotMatch(markdownTableStruct[0], /Divider\(\)[\s\S]*\.height\("100%"\)/, 'MarkdownTable must not rely on 100%-height Divider as the only vertical separator')
assert.match(markdownTableStruct[0], /cellTextAlign\(cell: RenderTableCell\): TextAlign[\s\S]*cell\.align === "center"[\s\S]*cell\.align === "right"[\s\S]*TextAlign\.Start/, 'MarkdownTable applies parsed cell align with Start fallback')
assert.match(markdownTableStruct[0], /paddedRow\(row: RenderTableCell\[\]\): RenderTableCell\[\][\s\S]*const count = this\.columnCount\(\)[\s\S]*cells\.push\(row\[index\] \?\? this\.emptyCell\(\)\)/, 'MarkdownTable pads ragged rows to columnCount for consistent widths/dividers')

console.log('markdown table render token tests passed')
