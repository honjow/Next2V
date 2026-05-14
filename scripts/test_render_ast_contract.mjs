#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

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

function attr(tag, name) {
  const re = new RegExp(`${name}\\s*=\\s*(["'])(.*?)\\1`, 'i')
  const m = tag.match(re)
  return m ? decodeHtml(m[2]).trim() : ''
}

function stripTags(value) {
  return decodeHtml(String(value || '').replace(/<[^>]+>/g, ''))
    .replace(/[ \t\f\v\r\n]+/g, ' ')
    .trim()
}

function text(value) {
  return { kind: 'text', text: decodeHtml(value || '') }
}

function link(href, children, raw = '') {
  return { kind: 'link', href, children, raw }
}

function image(src, inline = true, raw = '', alt = '') {
  return { kind: 'image', src, inline, alt, raw }
}

function inlineText(tokens) {
  return tokens.map(t => {
    if (t.kind === 'text') return t.text
    if (t.kind === 'link') return inlineText(t.children)
    if (t.kind === 'strong' || t.kind === 'em' || t.kind === 'codespan') return t.text
    if (t.kind === 'image') return t.src
    return ''
  }).join('')
}

function removeAtBeforeMemberLink(tokens) {
  for (let i = 1; i < tokens.length; i++) {
    if (tokens[i].kind === 'link' && /^\/member\//.test(tokens[i].href) && tokens[i - 1].kind === 'text') {
      tokens[i - 1].text = tokens[i - 1].text.replace(/@\s*$/, '')
    }
  }
  return tokens.filter(t => t.kind !== 'text' || t.text.length > 0)
}

function parseHtmlInline(value) {
  const tokens = []
  const source = value || ''
  const re = /<a\b[^>]*>[\s\S]*?<\/a>|<img\b[^>]*>|<br\s*\/?>|<code\b[^>]*>[\s\S]*?<\/code>|<(strong|b|em|i)\b[^>]*>[\s\S]*?<\/\1>/gi
  let last = 0
  let match
  const append = (s) => {
    const clean = decodeHtml(s || '').replace(/[ \t\f\v\r\n]+/g, ' ')
    if (clean) tokens.push(text(clean))
  }
  while ((match = re.exec(source))) {
    append(source.slice(last, match.index))
    const part = match[0]
    if (/^<br/i.test(part)) tokens.push({ kind: 'break' })
    else if (/^<img/i.test(part)) tokens.push(image(attr(part, 'src'), true, part, attr(part, 'alt')))
    else if (/^<a/i.test(part)) {
      const href = attr(part, 'href')
      const imgs = [...part.matchAll(/<img\b[^>]*>/gi)].map(m => image(attr(m[0], 'src') || href, true, m[0], attr(m[0], 'alt'))).filter(t => t.src)
      if (imgs.length) tokens.push(...imgs)
      else tokens.push(link(href, [text(stripTags(part))], part))
    } else if (/^<code/i.test(part)) tokens.push({ kind: 'codespan', text: stripTags(part) })
    else if (/^<(strong|b)/i.test(part)) tokens.push({ kind: 'strong', text: stripTags(part) })
    else if (/^<(em|i)/i.test(part)) tokens.push({ kind: 'em', text: stripTags(part) })
    last = re.lastIndex
  }
  append(source.slice(last).replace(/<[^>]+>/g, ''))
  while (tokens[0]?.kind === 'text' && !tokens[0].text.trim()) tokens.shift()
  while (tokens[tokens.length - 1]?.kind === 'text' && !tokens[tokens.length - 1].text.trim()) tokens.pop()
  if (tokens[0]?.kind === 'text') tokens[0].text = tokens[0].text.replace(/^\s+/, '')
  if (tokens[tokens.length - 1]?.kind === 'text') tokens[tokens.length - 1].text = tokens[tokens.length - 1].text.replace(/\s+$/, '')
  return removeAtBeforeMemberLink(tokens)
}

function parseMarkdownInline(value) {
  const tokens = []
  const source = value || ''
  const re = /!\[([^\]]*)\]\(\s*([^\s)]+)\s*\)|\[([^\]\n]+)\]\(\s*([^\s)]+)\s*\)|\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`/g
  let last = 0
  let match
  while ((match = re.exec(source))) {
    if (match.index > last) tokens.push(text(source.slice(last, match.index)))
    if (match[2]) tokens.push(image(match[2], true, match[0], match[1] || ''))
    else if (match[4]) tokens.push(link(match[4], [text(match[3])], match[0]))
    else if (match[5]) tokens.push({ kind: 'strong', text: match[5] })
    else if (match[6]) tokens.push({ kind: 'em', text: match[6] })
    else if (match[7]) tokens.push({ kind: 'codespan', text: match[7] })
    last = match.index + match[0].length
  }
  if (last < source.length) tokens.push(text(source.slice(last)))
  return removeAtBeforeMemberLink(tokens)
}

function parseMarkdown(md) {
  const lines = String(md || '').replace(/\r\n/g, '\n').split('\n')
  const blocks = []
  for (let i = 0; i < lines.length;) {
    const line = lines[i]
    if (!line.trim()) { i++; continue }
    const heading = /^(#{1,6})\s+(.*)$/.exec(line)
    if (heading) {
      blocks.push({ kind: 'heading', level: heading[1].length, children: parseMarkdownInline(heading[2]), text: heading[2] })
      i++; continue
    }
    if (/^>\s?/.test(line)) {
      const body = []
      while (i < lines.length && /^>\s?/.test(lines[i])) body.push(lines[i++].replace(/^>\s?/, ''))
      blocks.push({ kind: 'blockquote', children: parseMarkdown(body.join('\n')) })
      continue
    }
    if (/^```/.test(line)) {
      const lang = line.replace(/^```/, '').trim()
      i++
      const body = []
      while (i < lines.length && !/^```/.test(lines[i])) body.push(lines[i++])
      if (i < lines.length) i++
      blocks.push({ kind: 'code', text: body.join('\n'), lang })
      continue
    }
    if (/^\s*(?:[-*+] |\d+\. )/.test(line)) {
      const ordered = /^\s*\d+\. /.test(line)
      const items = []
      while (i < lines.length && (ordered ? /^\s*\d+\. /.test(lines[i]) : /^\s*[-*+] /.test(lines[i]))) {
        items.push({ children: parseMarkdownInline(lines[i].replace(/^\s*(?:[-*+] |\d+\. )/, '')) })
        i++
      }
      blocks.push({ kind: 'list', ordered, start: 1, items })
      continue
    }
    const para = []
    while (i < lines.length && lines[i].trim() && !/^(#{1,6})\s+/.test(lines[i]) && !/^>\s?/.test(lines[i]) && !/^```/.test(lines[i]) && !/^\s*(?:[-*+] |\d+\. )/.test(lines[i])) para.push(lines[i++])
    const children = parseMarkdownInline(para.join(' '))
    blocks.push({ kind: 'paragraph', children, text: inlineText(children) })
  }
  return blocks
}

function parseHtml(html) {
  const blocks = []
  const source = String(html || '').replace(/^<div\b[^>]*class=(["'])[^"']*markdown_body[^"']*\1[^>]*>/i, '').replace(/<\/div>\s*$/i, '')
  const blockRe = /<(h[1-6]|p|ul|ol|blockquote|pre)\b[^>]*>([\s\S]*?)<\/\1>/gi
  let last = 0
  let match
  const pushParagraph = (chunk) => {
    const children = parseHtmlInline(chunk)
    if (children.length) blocks.push({ kind: 'paragraph', children, text: inlineText(children) })
  }
  while ((match = blockRe.exec(source))) {
    if (match.index > last) pushParagraph(source.slice(last, match.index))
    const tag = match[1].toLowerCase()
    const body = match[2]
    if (/^h[1-6]$/.test(tag)) blocks.push({ kind: 'heading', level: Number(tag.slice(1)), children: parseHtmlInline(body), text: stripTags(body) })
    else if (tag === 'p') pushParagraph(body)
    else if (tag === 'blockquote') blocks.push({ kind: 'blockquote', children: parseHtml(body) })
    else if (tag === 'pre') blocks.push({ kind: 'code', text: stripTags(body), lang: '' })
    else if (tag === 'ul' || tag === 'ol') {
      const items = []
      for (const li of body.matchAll(/<li\b[^>]*>([\s\S]*?)<\/li>/gi)) items.push({ children: parseHtmlInline(li[1]) })
      blocks.push({ kind: 'list', ordered: tag === 'ol', start: 1, items })
    }
    last = blockRe.lastIndex
  }
  if (last < source.length) pushParagraph(source.slice(last))
  return blocks
}

function canonical(blocks) {
  return JSON.parse(JSON.stringify(blocks, (key, value) => {
    if (key === 'raw') return undefined
    if (key === 'inline') return value
    return value
  }))
}

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
const readingSettingsSource = readFileSync('shared/src/main/ets/settings/ReadingSettings.ets', 'utf8')
const readingSettingsPageSource = readFileSync('feature/settings/src/main/ets/pages/ReadingSettingsPage.ets', 'utf8')
assert.match(readingSettingsSource, /const KEY_FONT_SIZE: string = 'readingFontSize'/)
assert.match(readingSettingsSource, /value is now a reading text scale source/)
assert.match(readingSettingsSource, /static readonly TEXT_SCALE_DEFAULT: number = 1\.0/)
assert.match(readingSettingsSource, /static normalizeTextScale\(value: number\): number/)
assert.match(readingSettingsSource, /const scale = numeric > 2 \? numeric \/ ThemeConstants\.FONT_SIZE_BODY : numeric/)
assert.match(readingSettingsSource, /static scaleTypographyToken\(baseValue: number, textScaleSource: number\): number/)
assert.match(source, /type RenderBlockKind = "paragraph" \| "heading" \| "list" \| "blockquote" \| "code" \| "imageBlock" \| "imageTable" \| "table"/)
assert.match(source, /type RenderInlineKind = "text" \| "link" \| "strong" \| "em" \| "codespan" \| "image" \| "break"/)
assert.match(source, /const RENDER_STYLE_CONTRACT_TABLE: RenderContractStyleRow\[\]/)
assert.match(source, /name: "table"[\s\S]*semanticKind: "table"[\s\S]*fontSize: "fixed base 14 \* readingTextScale"[\s\S]*lineHeight: "fixed base 20 \* readingTextScale"/)
assert.match(source, /parseMarkdownToRenderAst\(source: string/)
assert.match(source, /parseRenderedHtmlToRenderAst\(contentRendered: string/)
const processTokens = source.match(/private static processTokens[\s\S]*?return tokens;/)[0]
assert.doesNotMatch(processTokens, /renderedHtmlToMarkdown/)
assert.match(processTokens, /parseRenderedHtmlToRenderAst\(decodedSource, sizeRecords\)/)
assert.match(processTokens, /parseMarkdownToRenderAst\(decodedSource, sizeRecords\)/)
assert.match(source, /htmlTableToRenderTableToken\(raw: string/)
assert.match(source, /normalizeMarkdownTableToken\(token: Token\): RenderTableToken \| null/)
assert.match(source, /if \(token\.type === "table"\)[\s\S]*MarkdownTable\(/)
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
assert.doesNotMatch(source, /lexer\(MarkdownContent\.convertHtmlTable\(raw\)/)
const standaloneImageLineCheck = source.match(/private static isImageTokenAloneOnInlineLine[\s\S]*?return before\.trim\(\)\.length === 0 && after\.trim\(\)\.length === 0;/)
assert.ok(standaloneImageLineCheck, 'production image standalone role requires empty same-line text before and after image')
assert.match(source, /roleDecision: "source structure \/ Markdown block semantics; never intrinsic big\/small"/)
assert.match(source, /roleDecision: "source structure \/ Markdown inline semantics; measured size only affects rendered dimensions"/)
assert.doesNotMatch(source, /_classifyInlineImageSize|inlineSmall|blockLarge|INLINE_IMAGE_(?:SMALL|LARGE)/)
assert.match(source, /const RENDER_BODY_FONT_SIZE = 14;/)
assert.match(source, /const RENDER_BODY_LINE_HEIGHT = 20;/)
assert.match(source, /const RENDER_H1_FONT_SIZE = 22;[\s\S]*const RENDER_H1_LINE_HEIGHT = 28;/)
assert.match(source, /const RENDER_H2_FONT_SIZE = 20;[\s\S]*const RENDER_H2_LINE_HEIGHT = 26;/)
assert.match(source, /const RENDER_H3_FONT_SIZE = 18;[\s\S]*const RENDER_H3_LINE_HEIGHT = 24;/)
assert.match(source, /const RENDER_H4_FONT_SIZE = 16;[\s\S]*const RENDER_H4_LINE_HEIGHT = 22;/)
assert.match(source, /const RENDER_H5_FONT_SIZE = 15;[\s\S]*const RENDER_H5_LINE_HEIGHT = 21;/)
assert.match(source, /const RENDER_H6_FONT_SIZE = 14;[\s\S]*const RENDER_H6_LINE_HEIGHT = 20;/)
assert.match(source, /const RENDER_CODE_FONT_SIZE = 12;/)
assert.match(source, /const RENDER_CODE_LINE_HEIGHT = 18;/)
assert.match(source, /name: "h1"[\s\S]*fontSize: "fixed base 22 \* readingTextScale"[\s\S]*lineHeight: "fixed base 28 \* readingTextScale"/)
assert.match(source, /name: "h6"[\s\S]*fontSize: "fixed base 14 \* readingTextScale"[\s\S]*lineHeight: "fixed base 20 \* readingTextScale"/)
assert.match(source, /name: "code\/pre"[\s\S]*fontSize: "fixed base 12 \* readingTextScale"[\s\S]*lineHeight: "fixed base 18 \* readingTextScale"/)
assert.match(source, /private headingBaseFontSize\(token: Token\): number/)
assert.match(source, /private headingBaseLineHeight\(token: Token\): number/)
assert.match(source, /return ReadingSettings\.scaleTypographyToken\(this\.headingBaseFontSize\(token\), this\.readingFontSize\);/)
assert.match(source, /return ReadingSettings\.scaleTypographyToken\(this\.headingBaseLineHeight\(token\), this\.readingFontSize\);/)
const codeBlockBody = source.match(/struct MarkdownCodeBlock[\s\S]*?\n}\n\n@Component\nstruct MarkdownAutoImage/)[0]
assert.match(codeBlockBody, /private codeFontSize\(\): number \{[\s\S]*RENDER_CODE_FONT_SIZE/)
assert.match(codeBlockBody, /private codeLineHeight\(\): number \{[\s\S]*RENDER_CODE_LINE_HEIGHT/)
assert.match(codeBlockBody, /\.fontSize\(this\.codeFontSize\(\)\)/)
assert.doesNotMatch(codeBlockBody, /theme\?\.code\?\.fontSize/)
const markdownOptionsBody = source.match(/private markdownOptions\(\): MarkdownOptions \{[\s\S]*?\n  }\n\n  private tokenKey/)[0]
const markdownOptionsCodeTheme = markdownOptionsBody.match(/code: \{[\s\S]*?\n        },\n        codeSpan:/)[0]
assert.doesNotMatch(markdownOptionsCodeTheme, /fontSize:\s*this\.bodyFontSize\(\)/)
assert.match(source, /private headingWeight\(token: Token\): FontWeight \{/)
assert.match(source, /private headingColor\(_token: Token\): ResourceColor \{\n    return ThemeConstants\.TEXT_PRIMARY;/)
assert.doesNotMatch(source, /bodyFontSize\(\) \+ \d/)
assert.doesNotMatch(source, /min\(bodyFontSize\(\) \+/)
assert.doesNotMatch(source, /Math\.min\(body \+/)
assert.doesNotMatch(source, /name: "h[2-6]"[^{\n]*fontSize: "bodyFontSize\(\)"/)
assert.match(readingSettingsPageSource, /Text\('文字缩放'\)/)
assert.match(readingSettingsPageSource, /拖动下面的滑块后，正文、标题、列表、引用和代码会按同一比例缩放/)
assert.doesNotMatch(readingSettingsPageSource, /Text\('行距'\)|updateReadingLineHeight|readingLineHeightMin|@StorageLink\(StorageKeys\.READING_LINE_HEIGHT\)|value:\s*this\.readingLineHeight/)
assert.doesNotMatch(readingSettingsPageSource, /将字号和行距恢复为默认值/)
assert.match(readingSettingsPageSource, /将文字缩放恢复为默认值/)

for (let level = 1; level <= 6; level++) {
  const md = `${'#'.repeat(level)} Heading ${level}`
  const html = `<h${level}>Heading ${level}</h${level}>`
  assert.deepEqual(canonical(parseMarkdown(md)), canonical(parseHtml(html)), `h${level} AST equivalence`)
}

const pairs = [
  ['paragraph', 'hello paragraph', '<p>hello paragraph</p>'],
  ['unordered list', '- one\n- two', '<ul><li>one</li><li>two</li></ul>'],
  ['ordered list', '1. one\n2. two', '<ol><li>one</li><li>two</li></ol>'],
  ['blockquote', '> quoted text', '<blockquote><p>quoted text</p></blockquote>'],
  ['code', '```\nconst a = 1\n```', '<pre><code>const a = 1</code></pre>'],
  ['link', '[site](https://example.com)', '<p><a href="https://example.com">site</a></p>'],
  ['strong/em/codespan', '**bold** *em* `code`', '<p><strong>bold</strong> <em>em</em> <code>code</code></p>'],
  ['mixed text+image', 'before ![pic](https://example.com/a.png) after', '<p>before <img src="https://example.com/a.png" alt="pic"> after</p>'],
  ['image-first mixed text', '![pic](https://example.com/a.png) after', '<p><img src="https://example.com/a.png" alt="pic"> after</p>'],
  ['member link', '[name](/member/name)', '<p>@<a href="/member/name">name</a></p>']
]
for (const [name, md, html] of pairs) {
  assert.deepEqual(canonical(parseMarkdown(md)), canonical(parseHtml(html)), `${name} AST equivalence`)
}

const duplicate = parseHtml('<p><a href="https://example.com/a.png"><img src="https://example.com/a.png"></a><a href="https://example.com/a.png"><img src="https://example.com/a.png"></a></p>')
assert.equal(duplicate[0].children.filter(t => t.kind === 'image' && t.src === 'https://example.com/a.png').length, 2)
assert.deepEqual(duplicate[0].children.map(t => t.kind), ['image', 'image'])

const imageFirstMixed = parseHtml('<p><img src="https://example.com/a.png" alt="pic"> after</p>')
assert.deepEqual(imageFirstMixed[0].children.map(t => t.kind), ['image', 'text'])
assert.equal(imageFirstMixed[0].children[0].inline, true)
assert.equal(imageFirstMixed[0].children[1].text, ' after')

console.log('PASS: render AST contract mirror/static validation preserves Markdown/rendered-HTML semantic equivalence and source-boundary checks')
