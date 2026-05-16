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

const topic1213097LongCell = '83.33%（10/12，连续多轮任务中成功保持上下文并完成端到端验证）'
const topic1213097HtmlTable = `<table><thead><tr><th>指标</th><th>OpenAgent</th><th>OpenClaw</th></tr></thead><tbody><tr><td>成功率</td><td>${topic1213097LongCell}</td><td>61.11%（11/18，复杂任务中仍保留完整执行记录）</td></tr></tbody></table>`
const topic1213097HtmlToken = htmlTableToToken(topic1213097HtmlTable)
assert.equal(topic1213097HtmlToken.type, 'table')
assert.deepEqual(topic1213097HtmlToken.headers.map(c => c.text), ['指标', 'OpenAgent', 'OpenClaw'])
assert.equal(topic1213097HtmlToken.rows[0][0].text, '成功率')
assert.equal(topic1213097HtmlToken.rows[0][1].text, topic1213097LongCell)
assert.ok(!topic1213097HtmlToken.rows[0][1].text.includes('...'), 'HTML table long cell text must be preserved, not replaced by ellipsis')

const topic1213097MdToken = markdownTableToToken(`| 指标 | OpenAgent | OpenClaw |\n| --- | --- | --- |\n| 成功率 | ${topic1213097LongCell} | 61.11%（11/18，复杂任务中仍保留完整执行记录） |`)
assert.equal(topic1213097MdToken.type, 'table')
assert.deepEqual(topic1213097MdToken.headers.map(c => c.text), topic1213097HtmlToken.headers.map(c => c.text))
assert.equal(topic1213097MdToken.rows[0][1].text, topic1213097LongCell)
assert.ok(!topic1213097MdToken.rows[0][1].text.includes('...'), 'Markdown table long cell text must be preserved, not replaced by ellipsis')
assert.ok(topic1213097MdToken.rows[0][1].text.includes('端到端验证'), 'Markdown table keeps the full long-cell suffix')

const topic1213097ProjectPerformanceMdToken = markdownTableToToken(`| 指标 | OpenAgent | OpenClaw |\n| --- | --- | --- |\n| 冷启动就绪 | \`~2.7 s\` | \`~29.2 s\` |\n| 常驻内存 | \`~110 MB\` | \`~215–245 MB\` |\n| 安装体积 | \`exe ~23 MB\` | \`~382 MB / 42,000+ 文件\` |`)
assert.equal(topic1213097ProjectPerformanceMdToken.type, 'table')
assert.deepEqual(topic1213097ProjectPerformanceMdToken.headers.map(c => c.text), ['指标', 'OpenAgent', 'OpenClaw'])
assert.deepEqual(topic1213097ProjectPerformanceMdToken.rows[0].map(c => c.text), ['冷启动就绪', '~2.7 s', '~29.2 s'])
assert.deepEqual(topic1213097ProjectPerformanceMdToken.rows[1].map(c => c.text), ['常驻内存', '~110 MB', '~215–245 MB'])
assert.deepEqual(topic1213097ProjectPerformanceMdToken.rows[2].map(c => c.text), ['安装体积', 'exe ~23 MB', '~382 MB / 42,000+ 文件'])
for (const row of topic1213097ProjectPerformanceMdToken.rows) {
  for (const cell of row) {
    assert.ok(!cell.text.includes('...'), `3.3 project-performance value must not be ellipsized: ${cell.text}`)
    assert.ok(!cell.text.includes('|'), `3.3 project-performance value must not fall back to raw Markdown pipe text: ${cell.text}`)
  }
}
assert.equal(topic1213097ProjectPerformanceMdToken.rows[0][1].tokens[0]?.type, 'codespan', '3.3 OpenAgent cold-start value keeps codespan token')
assert.equal(topic1213097ProjectPerformanceMdToken.rows[2][2].tokens[0]?.type, 'codespan', '3.3 OpenClaw install-size value keeps codespan token')

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
assert.doesNotMatch(markdownTableStruct[0], /@State private columnWidths|measuredColumnWidth|updateColumnWidth|onSizeChange/, 'MarkdownTable ordinary layout must not use per-cell runtime natural measurement column widths')
assert.match(markdownTableStruct[0], /@State private tableAvailableWidth: number = 0;/, 'MarkdownTable records the measured table container available width')
assert.match(markdownTableStruct[0], /onAreaChange\(\(_oldValue: Area, newValue: Area\) => \{\s*this\.updateTableAvailableWidth\(newValue\);\s*\}\)/, 'MarkdownTable measures availableWidth dynamically from layout instead of a fixed device width')
const tableCellBuilder = markdownTableStruct[0].match(/@Builder TableCell\([\s\S]*?\n  }\n\n  build\(\)/)?.[0] || ''
assert.ok(tableCellBuilder, 'MarkdownTable.TableCell builder is present')
assert.doesNotMatch(tableCellBuilder, /\.maxLines\(1\)[\s\S]{0,120}\.textOverflow\(\{ overflow: TextOverflow\.Ellipsis \}\)/, 'MarkdownTable.TableCell must not force single-line ellipsis')
assert.doesNotMatch(tableCellBuilder, /TextOverflow\.Ellipsis/, 'MarkdownTable.TableCell must not ellipsize ordinary table text')
assert.match(tableCellBuilder, /\.wordBreak\(WordBreak\.BREAK_WORD\)/, 'MarkdownTable.TableCell uses smart word-break wrapping: preserve words at whitespace when possible, still break long unspaced strings')
assert.match(source, /const TABLE_READABLE_MIN_CELL_WIDTH = \d+;/, 'MarkdownTable declares a readable lower bound before horizontal scrolling')

assert.doesNotMatch(source, /const TABLE_MAX_CELL_WIDTH = 320;/, 'MarkdownTable must not keep the old fixed 320vp max as the allocation lock')
assert.match(source, /const TABLE_CELL_HORIZONTAL_PADDING = ThemeConstants\.SPACE_SM \* 2;/, 'MarkdownTable includes cell horizontal padding in width estimates')
assert.match(markdownTableStruct[0], /textDisplayUnits\(text: string, protectedNoWrap: boolean = false\): number[\s\S]*TABLE_PROTECTED_ASCII_DISPLAY_UNIT[\s\S]*TABLE_ASCII_DISPLAY_UNIT[\s\S]*TABLE_WIDE_DISPLAY_UNIT/, 'MarkdownTable estimates text display units with separate ordinary and protected no-wrap weighting')
assert.match(markdownTableStruct[0], /naturalColumnWidths\(\): number\[\][\s\S]*this\.tableToken\.headers\[index\][\s\S]*for \(const row of this\.tableToken\.rows\)[\s\S]*widths\.push\(width\)/, 'MarkdownTable estimates natural column widths from header and row text without artificial caps')
assert.match(markdownTableStruct[0], /tableHorizontalBorderBudget\(\): number[\s\S]*TABLE_OUTER_BORDER_WIDTH \* 2[\s\S]*TABLE_CELL_VERTICAL_DIVIDER_WIDTH[\s\S]*columnAvailableWidth\(\): number[\s\S]*this\.tableAvailableWidth - this\.tableHorizontalBorderBudget\(\)/, 'MarkdownTable declares an explicit border budget helper for outer border and vertical dividers')
assert.match(markdownTableStruct[0], /allocatedColumnWidths\(\): number\[\][\s\S]*const availableWidth = this\.columnAvailableWidth\(\);[\s\S]*TABLE_READABLE_MIN_CELL_WIDTH/, 'MarkdownTable allocates columns with measured border-adjusted availableWidth and readable minimum')
assert.match(markdownTableStruct[0], /compressionCap = Math\.floor\(availableWidth \/ Math\.max\(1, natural\.length\) \* 1\.5\)[\s\S]*cappedTargets[\s\S]*return this\.distributeColumnWidths\(readableMin, cappedTargets, availableWidth\)/, 'MarkdownTable uses a measured fair-share compression cap so one prose-heavy column cannot hide protected columns')
assert.match(markdownTableStruct[0], /columnWidth\(index: number\): number[\s\S]*return this\.allocatedColumnWidths\(\)\[index\]/, 'MarkdownTable columnWidth uses responsive allocated widths')
assert.match(markdownTableStruct[0], /tableMinWidth\(\): number[\s\S]*const allocated = this\.allocatedColumnWidths\(\)[\s\S]*width \+= allocated\[index\]/, 'MarkdownTable table width sums responsive allocations')
assert.match(markdownTableStruct[0], /private tableContentWidth\(\): number[\s\S]*return this\.tableMinWidth\(\);/, 'MarkdownTable owns an explicit content width separate from Scroll viewport width')
assert.match(markdownTableStruct[0], /Text\(\)[\s\S]*\.width\(this\.columnWidth\(columnIndex\)\)[\s\S]*\.constraintSize\(\{ minWidth: this\.columnWidth\(columnIndex\), maxWidth: this\.columnWidth\(columnIndex\) \}\)/, 'MarkdownTable.TableCell fixes each Text to the allocated column width so Row stretch cannot donate viewport slack')
assert.match(markdownTableStruct[0], /Row\(\)[\s\S]*\.width\(this\.tableContentWidth\(\)\)/, 'MarkdownTable rows use explicit content width, not only minWidth')
assert.match(markdownTableStruct[0], /Column\(\)[\s\S]*\.width\(this\.tableContentWidth\(\)\)[\s\S]*\.constraintSize\(\{ minWidth: this\.tableContentWidth\(\), maxWidth: this\.tableContentWidth\(\) \}\)/, 'MarkdownTable content column uses explicit min/max width to avoid ArkUI viewport stretch')
assert.doesNotMatch(markdownTableStruct[0], /\.constraintSize\(\{ minWidth: this\.tableMinWidth\(\) \}\)/, 'MarkdownTable must not rely on minWidth-only table layout constraints')

const TABLE_READABLE_MIN_CELL_WIDTH_FOR_TEST = Number(source.match(/const TABLE_READABLE_MIN_CELL_WIDTH = (\d+);/)?.[1] ?? 128)
const BODY_FONT_SIZE_FOR_TEST = Number(source.match(/const RENDER_BODY_FONT_SIZE = (\d+);/)?.[1] ?? 14)
const TABLE_CELL_HORIZONTAL_PADDING_FOR_TEST = 16
const TABLE_OUTER_BORDER_WIDTH_FOR_TEST = Number(source.match(/const TABLE_OUTER_BORDER_WIDTH = (\d+);/)?.[1] ?? 1)
const TABLE_CELL_VERTICAL_DIVIDER_WIDTH_FOR_TEST = Number(source.match(/const TABLE_CELL_VERTICAL_DIVIDER_WIDTH = (\d+);/)?.[1] ?? 1)
const TABLE_ASCII_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_ASCII_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? 0.56)
const TABLE_NUMERIC_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_NUMERIC_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? 0.48)
const TABLE_SYMBOL_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_SYMBOL_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? TABLE_ASCII_DISPLAY_UNIT_FOR_TEST)
const TABLE_SPACE_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_SPACE_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? 0.33)
const TABLE_WIDE_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_WIDE_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? 1.0)
const TABLE_PROTECTED_ASCII_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_PROTECTED_ASCII_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? TABLE_ASCII_DISPLAY_UNIT_FOR_TEST)
const TABLE_PROTECTED_NUMERIC_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_PROTECTED_NUMERIC_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? TABLE_NUMERIC_DISPLAY_UNIT_FOR_TEST)
const TABLE_PROTECTED_SYMBOL_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_PROTECTED_SYMBOL_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? TABLE_SYMBOL_DISPLAY_UNIT_FOR_TEST)
const TABLE_PROTECTED_SPACE_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_PROTECTED_SPACE_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? TABLE_SPACE_DISPLAY_UNIT_FOR_TEST)
const TABLE_PROTECTED_WIDE_DISPLAY_UNIT_FOR_TEST = Number(source.match(/const TABLE_PROTECTED_WIDE_DISPLAY_UNIT = ([0-9.]+);/)?.[1] ?? TABLE_WIDE_DISPLAY_UNIT_FOR_TEST)
const DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST = 837
const DEVICE_230_PIXEL_RATIO_FOR_TEST = 2
const DEVICE_237_NARROW_CONTENT_WIDTH_VP_FOR_TEST = 408
const DEVICE_230_NARROW_CONTENT_WIDTH_VP_FOR_TEST = 408

function displayUnitsForTest(text, protectedNoWrap = false) {
  const asciiUnit = protectedNoWrap ? TABLE_PROTECTED_ASCII_DISPLAY_UNIT_FOR_TEST : TABLE_ASCII_DISPLAY_UNIT_FOR_TEST
  const numericUnit = protectedNoWrap ? TABLE_PROTECTED_NUMERIC_DISPLAY_UNIT_FOR_TEST : TABLE_NUMERIC_DISPLAY_UNIT_FOR_TEST
  const symbolUnit = protectedNoWrap ? TABLE_PROTECTED_SYMBOL_DISPLAY_UNIT_FOR_TEST : TABLE_SYMBOL_DISPLAY_UNIT_FOR_TEST
  const spaceUnit = protectedNoWrap ? TABLE_PROTECTED_SPACE_DISPLAY_UNIT_FOR_TEST : TABLE_SPACE_DISPLAY_UNIT_FOR_TEST
  const wideUnit = protectedNoWrap ? TABLE_PROTECTED_WIDE_DISPLAY_UNIT_FOR_TEST : TABLE_WIDE_DISPLAY_UNIT_FOR_TEST
  let units = 0
  for (const char of text || '') {
    const code = char.charCodeAt(0)
    if (char === ' ' || char === '\\t') units += spaceUnit
    else if (code >= 48 && code <= 57) units += numericUnit
    else if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) units += asciiUnit
    else if (code >= 0 && code <= 127) units += symbolUnit
    else units += wideUnit
  }
  return units
}

function isProtectedNoWrapCellForTest(text, header = false) {
  const value = String(text || '').trim()
  return /^\d+(?:\.\d+)?%（\s*\d+\s*\/\s*\d+\s*）$/.test(value) || (header && /^(?=.{6,16}$)(?=.*[A-Za-z])[A-Za-z][A-Za-z0-9_-]*$/.test(value))
}

function shortUnbreakableIntrinsicMinForTest(text, header = false) {
  const value = String(text || '').trim()
  if (isProtectedNoWrapCellForTest(value, header)) {
    const noBreakDisplayValue = value.replace(/\s+/g, '')
    return Math.ceil(displayUnitsForTest(noBreakDisplayValue, true) * BODY_FONT_SIZE_FOR_TEST + TABLE_CELL_HORIZONTAL_PADDING_FOR_TEST)
  }
  return 0
}

function noBreakWidthTextForTest(text, header = false) {
  const value = String(text || '')
  if (/^\s*\d+(?:\.\d+)?%（\s*\d+\s*\/\s*\d+\s*）\s*$/.test(value) || (header && /^(?=.{6,16}$)(?=.*[A-Za-z])[A-Za-z][A-Za-z0-9_-]*$/.test(value.trim()))) {
    return value.trim().replace(/\s+/g, '')
  }
  return value
}

function cellEstimatedWidthForTest(cell) {
  if (!cell) return TABLE_CELL_HORIZONTAL_PADDING_FOR_TEST
  const text = typeof cell === 'string' ? cell : cell.text
  const header = typeof cell === 'string' ? false : cell.header === true
  const natural = Math.ceil(displayUnitsForTest(noBreakWidthTextForTest(text, header)) * BODY_FONT_SIZE_FOR_TEST + TABLE_CELL_HORIZONTAL_PADDING_FOR_TEST)
  return Math.max(natural, shortUnbreakableIntrinsicMinForTest(text, header))
}

function columnReadableMinWidthsForTest(headers, rows) {
  const count = Math.max(headers.length, ...rows.map(row => row.length), 1)
  const widths = []
  for (let index = 0; index < count; index++) {
    const cells = [headers[index], ...rows.map(row => row[index])].filter(Boolean)
    const intrinsic = Math.max(...cells.map(cell => shortUnbreakableIntrinsicMinForTest(cell.text, cell.header === true)), 0)
    widths.push(Math.max(TABLE_READABLE_MIN_CELL_WIDTH_FOR_TEST, intrinsic))
  }
  return widths
}

function naturalColumnWidthsForTest(headers, rows) {
  const count = Math.max(headers.length, ...rows.map(row => row.length), 1)
  const widths = []
  for (let index = 0; index < count; index++) {
    const cells = [headers[index], ...rows.map(row => row[index])].filter(Boolean)
    const estimated = Math.max(...cells.map(cell => cellEstimatedWidthForTest(cell)), TABLE_CELL_HORIZONTAL_PADDING_FOR_TEST)
    widths.push(estimated)
  }
  return widths
}

function visibleCompactMinWidthForTest() {
  return Math.ceil(BODY_FONT_SIZE_FOR_TEST * 4 + TABLE_CELL_HORIZONTAL_PADDING_FOR_TEST)
}

function longestUnbreakableSegmentForTest(text) {
  const segments = String(text || '').match(/[^\s\u3000]+/g) || []
  return segments.reduce((longest, segment) => segment.length > longest.length ? segment : longest, '')
}

function hardUnbreakableIntrinsicMinForTest(text) {
  const segment = longestUnbreakableSegmentForTest(text)
  if (!segment) return 0
  const looksHard = /^https?:\/\//i.test(segment) || /^[A-Fa-f0-9]{32,}$/.test(segment) || (/^[\x21-\x7E]+$/.test(segment) && segment.length >= 48)
  if (!looksHard) return 0
  return Math.ceil(displayUnitsForTest(segment) * BODY_FONT_SIZE_FOR_TEST + TABLE_CELL_HORIZONTAL_PADDING_FOR_TEST)
}

function columnHardUnbreakableMinWidthsForTest(headers, rows) {
  const count = Math.max(headers.length, ...rows.map(row => row.length), 1)
  const widths = []
  for (let index = 0; index < count; index++) {
    const cells = [headers[index], ...rows.map(row => row[index])].filter(Boolean)
    widths.push(Math.max(...cells.map(cell => hardUnbreakableIntrinsicMinForTest(cell.text)), 0))
  }
  return widths
}

function tableColumnCountForTest(headers, rows) {
  return Math.max(headers.length, ...rows.map(row => row.length), 1)
}

function tableHorizontalBorderBudgetForTest(headers, rows) {
  return TABLE_OUTER_BORDER_WIDTH_FOR_TEST * 2 + Math.max(0, tableColumnCountForTest(headers, rows) - 1) * TABLE_CELL_VERTICAL_DIVIDER_WIDTH_FOR_TEST
}

function tableAllocationResultForTest(widths, borderBudget) {
  const tableWidth = widths.reduce((sum, width) => sum + width, 0)
  return { widths, tableWidth, renderedOuterWidth: tableWidth + borderBudget }
}

function allocateTableForTest(headers, rows, availableWidth) {
  const borderBudget = tableHorizontalBorderBudgetForTest(headers, rows)
  const columnAvailableWidth = Math.max(0, availableWidth - borderBudget)
  const natural = naturalColumnWidthsForTest(headers, rows)
  const readableMin = columnReadableMinWidthsForTest(headers, rows)
  const naturalTotal = natural.reduce((sum, width) => sum + width, 0)
  if (!columnAvailableWidth || naturalTotal <= columnAvailableWidth) return tableAllocationResultForTest(natural, borderBudget)
  const minTotal = readableMin.reduce((sum, width) => sum + width, 0)
  const hardMin = columnHardUnbreakableMinWidthsForTest(headers, rows)
  const hardTotal = hardMin.reduce((sum, width) => sum + width, 0)
  if (hardTotal > columnAvailableWidth) {
    const widths = hardMin.map((width, index) => Math.max(width, visibleCompactMinWidthForTest(), Math.min(readableMin[index], visibleCompactMinWidthForTest())))
    return tableAllocationResultForTest(widths, borderBudget)
  }
  if (minTotal > columnAvailableWidth) {
    const hardMin = columnHardUnbreakableMinWidthsForTest(headers, rows)
    const hardTotal = hardMin.reduce((sum, width) => sum + width, 0)
    if (hardTotal > columnAvailableWidth) {
      const widths = hardMin.map((width, index) => Math.max(width, visibleCompactMinWidthForTest(), readableMin[index]))
      return tableAllocationResultForTest(widths, borderBudget)
    }
    const compactMin = natural.map((_, index) => Math.max(hardMin[index], Math.min(readableMin[index], visibleCompactMinWidthForTest())))
    const compactMinTotal = compactMin.reduce((sum, width) => sum + width, 0)
    if (compactMinTotal > columnAvailableWidth) {
      return tableAllocationResultForTest(compactMin, borderBudget)
    }
    const compressionCap = Math.floor(columnAvailableWidth / Math.max(1, natural.length) * 1.5)
    const cappedTargets = natural.map((width, index) => Math.max(compactMin[index], Math.min(width, compressionCap)))
    const widths = compactMin.slice()
    let remaining = columnAvailableWidth - compactMinTotal
    while (remaining > 0) {
      const flexible = widths.map((width, index) => width < cappedTargets[index] ? index : -1).filter(index => index >= 0)
      if (flexible.length === 0) break
      const share = Math.max(1, Math.floor(remaining / flexible.length))
      let consumed = 0
      for (const index of flexible) {
        if (remaining <= 0) break
        const add = Math.min(share, remaining, cappedTargets[index] - widths[index])
        widths[index] += add
        remaining -= add
        consumed += add
      }
      if (consumed === 0) break
    }
    for (let index = 0; remaining > 0 && widths.length > 0; index = (index + 1) % widths.length) {
      widths[index] += 1
      remaining -= 1
    }
    return tableAllocationResultForTest(widths, borderBudget)
  }
  const compressionCap = Math.floor(columnAvailableWidth / Math.max(1, natural.length) * 1.5)
  const cappedTargets = natural.map((width, index) => Math.max(readableMin[index], Math.min(width, compressionCap)))
  const widths = readableMin.slice()
  let remaining = columnAvailableWidth - minTotal
  while (remaining > 0) {
    const flexible = widths.map((width, index) => width < cappedTargets[index] ? index : -1).filter(index => index >= 0)
    if (flexible.length === 0) break
    const share = Math.max(1, Math.floor(remaining / flexible.length))
    let consumed = 0
    for (const index of flexible) {
      if (remaining <= 0) break
      const add = Math.min(share, remaining, cappedTargets[index] - widths[index])
      widths[index] += add
      remaining -= add
      consumed += add
    }
    if (consumed === 0) break
  }
  return tableAllocationResultForTest(widths, borderBudget)
}

function formatTableCellTextForLayoutForTest(text) {
  return String(text || '').replace(/(\d+(?:\.\d+)?%)（\s*(\d+)\s*\/\s*(\d+)\s*）/g, (_match, percent, numerator, denominator) => `${percent}\u2060（\u00A0${numerator}/${denominator}\u00A0）`)
}

function formattedCellTokenForTest(token) {
  const originalText = String(token?.text ?? '')
  if (originalText.length === 0) return token
  const formattedText = formatTableCellTextForLayoutForTest(originalText)
  if (formattedText === originalText) return token
  const formattedRecord = {}
  Object.keys(token).forEach((key) => {
    formattedRecord[key] = token[key]
  })
  formattedRecord.text = formattedText
  return formattedRecord
}

const spacedSuccessRateForTest = '83.33%（ 30/36 ）'
const spacedSuccessRateDisplayForTest = formatTableCellTextForLayoutForTest(spacedSuccessRateForTest)
assert.equal(spacedSuccessRateDisplayForTest, '83.33%\u2060（\u00A030/36\u00A0）', 'table-cell success rate display removes the percent/bracket break and replaces bracket-edge regular spaces with NBSP')
assert.ok(!/% +（/.test(spacedSuccessRateDisplayForTest), 'table-cell success rate display has no breakable regular space between percent and bracket')
assert.ok(!/（ +\d/.test(spacedSuccessRateDisplayForTest), 'table-cell success rate display has no breakable regular space after full-width left bracket')
assert.ok(!/\d +）/.test(spacedSuccessRateDisplayForTest), 'table-cell success rate display has no breakable regular space before full-width right bracket')
assert.equal(formatTableCellTextForLayoutForTest('61.11%（22/36）'), '61.11%\u2060（\u00A022/36\u00A0）', 'compact success-rate values also gain non-breaking display guards')
const metadataTokenForTest = {
  type: 'link',
  raw: '[83.33%（ 30/36 ）](https://example.com/rate)',
  text: spacedSuccessRateForTest,
  href: 'https://example.com/rate',
  title: 'success-rate title metadata',
  inlineImage: true,
  customMeta: { parser: 'regression-sentinel', ordinal: 7 },
  tokens: [{ type: 'text', text: spacedSuccessRateForTest, title: 'nested text metadata' }],
}
const formattedMetadataTokenForTest = formattedCellTokenForTest(metadataTokenForTest)
assert.notEqual(formattedMetadataTokenForTest, metadataTokenForTest, 'formatted token is cloned only when display text changes')
assert.equal(formattedMetadataTokenForTest.text, spacedSuccessRateDisplayForTest, 'formatted token overrides only display text')
assert.equal(formattedMetadataTokenForTest.href, metadataTokenForTest.href, 'formatted token keeps link href')
assert.equal(formattedMetadataTokenForTest.title, metadataTokenForTest.title, 'formatted token keeps non-whitelisted link title metadata')
assert.equal(formattedMetadataTokenForTest.inlineImage, true, 'formatted token keeps inlineImage metadata')
assert.deepEqual(formattedMetadataTokenForTest.customMeta, metadataTokenForTest.customMeta, 'formatted token keeps arbitrary parser metadata')
assert.deepEqual(formattedMetadataTokenForTest.tokens, metadataTokenForTest.tokens, 'formatted token keeps nested inline tokens unchanged')
assert.match(markdownTableStruct[0], /const formattedRecord: TokenRecord = \{\};[\s\S]*Object\.keys\(record\)\.forEach[\s\S]*formattedRecord\[key\] = record\[key\];[\s\S]*formattedRecord\["text"\] = formattedText;[\s\S]*return formattedRecord as Token;/, 'formattedCellToken clones all original token record keys and overrides only text')
assert.doesNotMatch(markdownTableStruct[0], /type: record\["type"\][\s\S]{0,180}href: record\["href"\][\s\S]{0,120}tokens: record\["tokens"\]/, 'formattedCellToken must not rebuild tokens through a metadata-dropping whitelist')
assert.equal(topic1213097MdToken.rows[0][1].text, topic1213097LongCell, 'table cell token text remains original semantic source, separate from display normalization')
assert.match(markdownTableStruct[0], /formatTableCellTextForLayout\(text: string\): string[\s\S]*\\u00A0/, 'MarkdownTable owns a table-cell-only short-value layout formatter using NBSP')
assert.match(markdownTableStruct[0], /formattedCellToken\(token: Token\): Token[\s\S]*this\.formatTableCellTextForLayout[\s\S]*cellTokens\(cell: RenderTableCell\): Token\[\][\s\S]*this\.formattedCellToken/, 'MarkdownTable.TableCell display-token path applies table-cell-only layout formatting')
assert.doesNotMatch(source.slice(0, markdownTableStruct.index), /formatTableCellTextForLayout/, 'success-rate layout formatting is scoped to MarkdownTable, not parser/token normalization')

const shortHeaders = [
  { text: '指标', header: true },
  { text: 'OpenAgent', header: true },
  { text: 'OpenClaw', header: true },
]
const shortRows = [[
  { text: '成功率' },
  { text: spacedSuccessRateForTest },
  { text: '61.11%（ 22/36 ）' },
]]
const firstTable230 = allocateTableForTest(shortHeaders, shortRows, DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST)
assert.equal(firstTable230.tableWidth, firstTable230.widths.reduce((sum, width) => sum + width, 0), 'layout mirror: first 230 table width is content-derived total')
assert.deepEqual(firstTable230.widths, naturalColumnWidthsForTest(shortHeaders, shortRows), 'naturalTotal <= availableWidth returns natural widths exactly: no stretch, no compression')
assert.equal(firstTable230.renderedOuterWidth, firstTable230.tableWidth + tableHorizontalBorderBudgetForTest(shortHeaders, shortRows), 'layout mirror: rendered outer width adds table outer border and internal vertical dividers')
assert.ok(firstTable230.renderedOuterWidth <= DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST, `first 230 rendered outer table must initially fit when protected minima fit, got total ${firstTable230.renderedOuterWidth}`)
assert.ok(firstTable230.tableWidth < DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST, `naturalTotal <= availableWidth does not force the table to fill the viewport, got total ${firstTable230.tableWidth}`)
assert.ok(firstTable230.widths[1] >= shortUnbreakableIntrinsicMinForTest(spacedSuccessRateForTest), '83.33%（30/36） column keeps its no-wrap natural estimate, not a fixed protected clamp')
assert.ok(firstTable230.widths[2] >= shortUnbreakableIntrinsicMinForTest('61.11%（ 22/36 ）'), '61.11%（22/36） column keeps its no-wrap natural estimate, not a fixed protected clamp')
assert.ok(firstTable230.widths[1] * DEVICE_230_PIXEL_RATIO_FOR_TEST >= 390, `83.33%（30/36） no-wrap natural width must clear the 230 split bound, got ${firstTable230.widths[1]}vp`)
assert.ok(firstTable230.widths[2] * DEVICE_230_PIXEL_RATIO_FOR_TEST >= 390, `61.11%（22/36） no-wrap natural width must clear the 230 split bound, got ${firstTable230.widths[2]}vp`)

const firstTableLongOrdinaryRows = [
  [
    { text: '成功率' },
    { text: '83.33%（ 30/36 ）' },
    { text: '61.11%（ 22/36 ）' },
  ],
  [
    { text: '平均耗时' },
    { text: 'ordinary prose with many ASCII words that explains how OpenAgent completed multi step tool calls, validated output, tracked logs, and compared latency without needing this prose column to remain single-line' },
    { text: '短文本' },
  ],
]
const firstTableBalanced230 = allocateTableForTest(shortHeaders, firstTableLongOrdinaryRows, DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST)
assert.ok(firstTableBalanced230.renderedOuterWidth <= DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST, `compressed first table rendered outer width must not overflow when protected minima fit, got ${firstTableBalanced230.renderedOuterWidth}`)
assert.ok(firstTableBalanced230.widths[2] >= shortUnbreakableIntrinsicMinForTest('61.11%（ 22/36 ）'), `OpenClaw/61.11% column keeps protected no-wrap minimum, got ${firstTableBalanced230.widths[2]}`)
assert.ok(firstTableBalanced230.widths[2] * DEVICE_230_PIXEL_RATIO_FOR_TEST > 390, `OpenClaw column must not become a right-edge sliver, got ${firstTableBalanced230.widths[2]}vp`)
assert.ok(Math.max(...firstTableBalanced230.widths) * DEVICE_230_PIXEL_RATIO_FOR_TEST < 1200, `no column may repeat the ~1300px OpenAgent over-wide regression, got ${firstTableBalanced230.widths.join(',')}vp`)
assert.ok(firstTableBalanced230.widths[1] <= Math.floor(DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST / 3 * 1.5), `ordinary long prose column is capped by measured fair-share compression, got ${firstTableBalanced230.widths[1]}`)
assert.ok(firstTable230.widths[1] * DEVICE_230_PIXEL_RATIO_FOR_TEST < 1320 && firstTable230.widths[2] * DEVICE_230_PIXEL_RATIO_FOR_TEST < 1320, 'percent/fraction columns must not repeat fix3 pathological width')
const table237Narrow = allocateTableForTest(shortHeaders, firstTableLongOrdinaryRows, DEVICE_237_NARROW_CONTENT_WIDTH_VP_FOR_TEST)
assert.ok(table237Narrow.renderedOuterWidth <= DEVICE_237_NARROW_CONTENT_WIDTH_VP_FOR_TEST, `237-like ordinary comparison table rendered outer width must fit measured availableWidth, got ${table237Narrow.renderedOuterWidth}`)
assert.ok(table237Narrow.widths[2] >= Math.floor(DEVICE_237_NARROW_CONTENT_WIDTH_VP_FOR_TEST / 4), `237 OpenClaw column must remain visible, not a right-edge sliver, got ${table237Narrow.widths[2]}vp`)
assert.ok(table237Narrow.widths.every(width => width >= visibleCompactMinWidthForTest()), `237 all columns keep compact readable minima, got ${table237Narrow.widths.join(',')}`)
const table230Narrow = allocateTableForTest(shortHeaders, firstTableLongOrdinaryRows, DEVICE_230_NARROW_CONTENT_WIDTH_VP_FOR_TEST)
assert.ok(table230Narrow.renderedOuterWidth <= DEVICE_230_NARROW_CONTENT_WIDTH_VP_FOR_TEST, `230 current/narrow ordinary comparison table rendered outer width must fit measured availableWidth, got ${table230Narrow.renderedOuterWidth}`)
assert.ok(table230Narrow.widths[2] >= Math.floor(DEVICE_230_NARROW_CONTENT_WIDTH_VP_FOR_TEST / 4), `230 current/narrow OpenClaw column must not be clipped to OpenC..., got ${table230Narrow.widths[2]}vp`)
assert.ok(table230Narrow.widths[1] > table230Narrow.widths[0] && table230Narrow.widths[2] > table230Narrow.widths[0], `comparison columns should receive visible shares, got ${table230Narrow.widths.join(',')}`)
const secondTable230 = allocateTableForTest(shortHeaders, [[{ text: '完成率' }, { text: '100%' }, { text: '95%' }]], DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST)
assert.ok(secondTable230.renderedOuterWidth <= DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST, `second compact table rendered outer width must fit the initial 230 viewport when protected minima fit, got ${secondTable230.renderedOuterWidth}`)
assert.deepEqual(secondTable230.widths, naturalColumnWidthsForTest(shortHeaders, [[{ text: '完成率' }, { text: '100%' }, { text: '95%' }]]), 'second compact table uses natural widths exactly when they fit')
assert.equal(secondTable230.widths[1], shortUnbreakableIntrinsicMinForTest('OpenAgent', true), 'OpenAgent column uses protected header min, not a fixed clamp')
assert.equal(secondTable230.widths[2], shortUnbreakableIntrinsicMinForTest('OpenClaw', true), 'OpenClaw column uses protected header min, not a fixed clamp')
assert.ok(secondTable230.widths[1] * DEVICE_230_PIXEL_RATIO_FOR_TEST >= 390, `OpenAgent protected header width must clear the 230 split bound, got ${secondTable230.widths[1]}vp`)
assert.ok(secondTable230.widths[2] * DEVICE_230_PIXEL_RATIO_FOR_TEST >= 390, `OpenClaw protected header width must clear the 230 split bound, got ${secondTable230.widths[2]}vp`)
assert.ok(secondTable230.widths[2] * DEVICE_230_PIXEL_RATIO_FOR_TEST > 74, `OpenClaw must exceed the observed 74px sliver, got ${secondTable230.widths[2]}vp`)
assert.ok(secondTable230.widths[1] * DEVICE_230_PIXEL_RATIO_FOR_TEST < 1320 && secondTable230.widths[2] * DEVICE_230_PIXEL_RATIO_FOR_TEST < 1320, 'OpenAgent/OpenClaw must not repeat fix3 pathological width')
const projectPerformanceRows = topic1213097ProjectPerformanceMdToken.rows
const projectPerformance237Narrow = allocateTableForTest(shortHeaders, projectPerformanceRows, DEVICE_237_NARROW_CONTENT_WIDTH_VP_FOR_TEST)
assert.ok(projectPerformance237Narrow.renderedOuterWidth <= DEVICE_237_NARROW_CONTENT_WIDTH_VP_FOR_TEST, `3.3 project-performance table rendered outer width must fit 237-like measured availableWidth, got ${projectPerformance237Narrow.renderedOuterWidth}`)
assert.ok(projectPerformance237Narrow.widths[2] >= Math.floor(DEVICE_237_NARROW_CONTENT_WIDTH_VP_FOR_TEST / 4), `3.3 237-like OpenClaw/right-value column must not be a sliver, got ${projectPerformance237Narrow.widths[2]}vp`)
assert.ok(projectPerformance237Narrow.widths[2] >= TABLE_READABLE_MIN_CELL_WIDTH_FOR_TEST, `3.3 237-like OpenClaw install-size value should remain readable with wrapping, got ${projectPerformance237Narrow.widths[2]}vp`)
assert.ok(projectPerformanceRows[0][2].text.includes('~29.2 s') && projectPerformanceRows[2][2].text.includes('42,000+ 文件'), '3.3 narrow OpenClaw values remain present in table tokens')
const projectPerformance230Narrow = allocateTableForTest(shortHeaders, projectPerformanceRows, DEVICE_230_NARROW_CONTENT_WIDTH_VP_FOR_TEST)
assert.ok(projectPerformance230Narrow.renderedOuterWidth <= DEVICE_230_NARROW_CONTENT_WIDTH_VP_FOR_TEST, `3.3 project-performance table rendered outer width must fit 230-narrow measured availableWidth, got ${projectPerformance230Narrow.renderedOuterWidth}`)
assert.ok(projectPerformance230Narrow.widths[2] >= Math.floor(DEVICE_230_NARROW_CONTENT_WIDTH_VP_FOR_TEST / 4), `3.3 230-narrow OpenClaw/right-value column must not be a right-edge sliver, got ${projectPerformance230Narrow.widths[2]}vp`)
assert.ok(projectPerformance230Narrow.widths[1] > visibleCompactMinWidthForTest() && projectPerformance230Narrow.widths[2] > visibleCompactMinWidthForTest(), `3.3 230-narrow comparison columns should keep readable shares, got ${projectPerformance230Narrow.widths.join(',')}`)
const projectPerformance230Wide = allocateTableForTest(shortHeaders, projectPerformanceRows, DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST)
assert.ok(projectPerformance230Wide.renderedOuterWidth <= DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST, `3.3 project-performance table rendered outer width must fit wide 230 measured availableWidth, got ${projectPerformance230Wide.renderedOuterWidth}`)
assert.deepEqual(projectPerformance230Wide.widths, naturalColumnWidthsForTest(shortHeaders, projectPerformanceRows), '3.3 wide 230 keeps natural content widths when they fit instead of needless over-compression')
assert.ok(projectPerformance230Wide.tableWidth < DEVICE_230_CONTENT_WIDTH_VP_FOR_TEST, `3.3 wide 230 should not stretch a naturally fitting table to full viewport, got ${projectPerformance230Wide.tableWidth}`)
assert.ok(projectPerformance230Wide.widths[1] >= shortUnbreakableIntrinsicMinForTest('OpenAgent', true), `3.3 wide 230 OpenAgent column remains readable, got ${projectPerformance230Wide.widths[1]}vp`)
assert.ok(projectPerformance230Wide.widths[2] >= cellEstimatedWidthForTest(projectPerformanceRows[2][2]), `3.3 wide 230 OpenClaw value column is not needlessly slivered, got ${projectPerformance230Wide.widths[2]}vp`)
assert.ok(projectPerformance230Wide.widths[2] > projectPerformance230Wide.widths[0], `3.3 wide 230 OpenClaw/value column should have more room than label column, got ${projectPerformance230Wide.widths.join(',')}`)
const naturalShort = allocateTableForTest([{ text: 'A', header: true }, { text: 'B', header: true }], [[{ text: 'foo' }, { text: 'bar' }]], 900)
assert.equal(naturalShort.tableWidth, naturalShort.widths.reduce((sum, width) => sum + width, 0), 'layout mirror: natural table width is content total')
assert.ok(naturalShort.tableWidth < 900, 'naturalTotal <= availableWidth keeps ordinary short table narrower than body instead of stretching')
const compressedShort = allocateTableForTest([{ text: 'Alpha', header: true }, { text: 'Beta', header: true }, { text: 'Gamma', header: true }], [[{ text: 'moderately long ordinary text that should wrap within a readable column' }, { text: 'short' }, { text: 'short' }]], 350)
assert.equal(compressedShort.renderedOuterWidth, 350, 'compressible non-protected tables fill availableWidth including table borders when naturalTotal exceeds availableWidth but readable minima fit')
assert.ok(compressedShort.widths.every(width => width >= TABLE_READABLE_MIN_CELL_WIDTH_FOR_TEST), 'compressed columns stay readable')
const scrollNeeded = allocateTableForTest([{ text: 'Alpha', header: true }, { text: 'Beta', header: true }, { text: 'Gamma', header: true }, { text: 'Delta', header: true }, { text: 'Epsilon', header: true }], [[{ text: 'long ordinary text' }, { text: 'long ordinary text' }, { text: 'long ordinary text' }, { text: 'long ordinary text' }, { text: 'long ordinary text' }]], 300)
assert.ok(scrollNeeded.renderedOuterWidth > 300, 'when all columns cannot remain minimally readable, rendered outer width exceeds availableWidth for horizontal scroll')
assert.ok(scrollNeeded.widths.every(width => width >= visibleCompactMinWidthForTest()), 'horizontal-scroll case preserves compact visible column widths instead of hard squeezing')
const protectedSoftWrap = allocateTableForTest([{ text: 'OpenAgent', header: true }, { text: 'OpenClaw', header: true }], [[{ text: '83.33%（ 30/36 ）' }, { text: '61.11%（ 22/36 ）' }]], 200)
assert.ok(protectedSoftWrap.renderedOuterWidth <= 200, `protected short semantic tokens are soft preferences and must fit ordinary comparison tables including borders, got ${protectedSoftWrap.renderedOuterWidth}`)
assert.ok(protectedSoftWrap.widths.every(width => width >= visibleCompactMinWidthForTest()), `protected soft-wrap columns remain visible, got ${protectedSoftWrap.widths.join(',')}`)
const hardUrlTextForTest = 'https://example.com/' + 'a'.repeat(80)
const hardUnbreakableOverflow = allocateTableForTest([{ text: 'Key', header: true }, { text: 'Value', header: true }], [[{ text: 'url' }, { text: hardUrlTextForTest }]], 260)
assert.ok(hardUnbreakableOverflow.renderedOuterWidth > 260, 'truly hard unbreakable URL/hash-like content may exceed availableWidth and scroll')
assert.ok(hardUnbreakableOverflow.widths[1] >= hardUnbreakableIntrinsicMinForTest(hardUrlTextForTest), 'hard unbreakable column preserves its intrinsic unbroken width')
assert.doesNotMatch(source, /const TABLE_SHORT_UNBREAKABLE_MIN_CELL_WIDTH = 480;/, 'MarkdownTable must not keep fix3 fixed 480vp protected width')
assert.doesNotMatch(source, /const TABLE_MIN_CELL_WIDTH = \d+;/, 'MarkdownTable must not keep a natural-width floor that overrides actual content estimates')
assert.doesNotMatch(source, /TABLE_SHORT_UNBREAKABLE_(?:MIN_CELL_WIDTH|MAX_CELL_WIDTH|SAFETY_WIDTH)/, 'MarkdownTable must not keep fix4 protected short-token product clamps')
assert.match(markdownTableStruct[0], /isProtectedNoWrapCell\(cell: RenderTableCell \| undefined\): boolean[\s\S]*shortUnbreakableIntrinsicMinWidth\(cell: RenderTableCell \| undefined\): number[\s\S]*textDisplayUnits\(noBreakDisplayText, true\)[\s\S]*TABLE_CELL_HORIZONTAL_PADDING/, 'MarkdownTable estimates protected short-token width from separate no-wrap content units plus padding')
assert.match(markdownTableStruct[0], /columnReadableMinWidths\(\): number\[\][\s\S]*shortUnbreakableIntrinsicMinWidth[\s\S]*TABLE_READABLE_MIN_CELL_WIDTH/, 'MarkdownTable uses protected short-token intrinsic minima as roomy-layout preferences')
assert.match(markdownTableStruct[0], /visibleCompactMinWidth\(\): number[\s\S]*this\.bodyFontSize\(\) \* 4[\s\S]*hardUnbreakableIntrinsicMinWidth\(cell: RenderTableCell \| undefined\): number[\s\S]*longestUnbreakableSegment/, 'MarkdownTable distinguishes soft protected tokens from truly hard unbreakable overflow')
assert.match(markdownTableStruct[0], /hardUnbreakableColumnMinWidths[\s\S]*if \(hardUnbreakableTotal > availableWidth\)[\s\S]*if \(readableTotal > availableWidth\)[\s\S]*compactMin[\s\S]*return this\.distributeColumnWidths/, 'MarkdownTable squeezes ordinary tables into measured availableWidth before falling back to hard-unbreakable scroll')
assert.match(tableCellBuilder, /\.border\(\{[\s\S]*width: \{ right: columnIndex < this\.columnCount\(\) - 1 \? TABLE_CELL_VERTICAL_DIVIDER_WIDTH : 0 \}[\s\S]*color: TABLE_BORDER_COLOR/, 'MarkdownTable draws internal vertical separators with per-cell right borders using the shared divider constant')
assert.match(markdownTableStruct[0], /\.border\(\{ width: TABLE_OUTER_BORDER_WIDTH, color: TABLE_BORDER_COLOR \}\)/, 'MarkdownTable outer border uses the shared outer border constant')
assert.doesNotMatch(markdownTableStruct[0], /verticalDividerIndexes\(|verticalDividerOffset\(|@Builder TableRow\(/, 'MarkdownTable must not keep row-level overlay divider helpers')
assert.doesNotMatch(markdownTableStruct[0], /Stack\(\{ alignContent: Alignment\.TopStart \}\)[\s\S]*Blank\(\)[\s\S]*\.height\("100%"\)[\s\S]*\.position\(/, 'MarkdownTable must not draw vertical separators with row-level Stack/Blank 100%-height positioned overlays')
assert.doesNotMatch(markdownTableStruct[0], /Divider\(\)[\s\S]*\.height\("100%"\)|Blank\(\)[\s\S]*\.height\("100%"\)[\s\S]*\.position\(/, 'MarkdownTable must not rely on 100%-height divider overlays')
assert.match(markdownTableStruct[0], /cellTextAlign\(cell: RenderTableCell\): TextAlign[\s\S]*cell\.align === "center"[\s\S]*cell\.align === "right"[\s\S]*TextAlign\.Start/, 'MarkdownTable applies parsed cell align with Start fallback')
assert.match(markdownTableStruct[0], /paddedRow\(row: RenderTableCell\[\]\): RenderTableCell\[\][\s\S]*const count = this\.columnCount\(\)[\s\S]*cells\.push\(row\[index\] \?\? this\.emptyCell\(\)\)/, 'MarkdownTable pads ragged rows to columnCount for consistent widths/dividers')

console.log('markdown table render token tests passed')
