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
const codeBlockSource = readFileSync('shared/src/main/ets/components/markdown/MarkdownCodeBlock.ets', 'utf8')
const codeInternalsSource = readFileSync('shared/src/main/ets/components/markdown/MarkdownCodeInternals.ets', 'utf8')
const readingSettingsSource = readFileSync('shared/src/main/ets/settings/ReadingSettings.ets', 'utf8')
const storageKeysSource = readFileSync('shared/src/main/ets/constants/StorageKeys.ets', 'utf8')
const readingSettingsPageSource = readFileSync('feature/settings/src/main/ets/pages/ReadingSettingsPage.ets', 'utf8')
assert.match(readingSettingsSource, /const KEY_TEXT_SCALE: string = StorageKeys\.READING_TEXT_SCALE/)
assert.match(storageKeysSource, /READING_TEXT_SCALE: string = 'readingTextScale'/)
assert.match(readingSettingsSource, /static readonly TEXT_SCALE_DEFAULT: number = 1\.0/)
assert.match(readingSettingsSource, /static normalizeTextScale\(value: number\): number/)
assert.doesNotMatch(readingSettingsSource, /numeric > 2/)
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
assert.doesNotMatch(markdownTableStruct[0], /@State private columnWidths|measuredColumnWidth|updateColumnWidth|onSizeChange/, 'MarkdownTable ordinary layout must not use per-cell runtime natural measurement column widths')
assert.match(markdownTableStruct[0], /@State private tableAvailableWidth: number = 0;/, 'MarkdownTable records measured available width')
assert.match(source, /const TABLE_READABLE_MIN_CELL_WIDTH = \d+;/, 'MarkdownTable declares a readable minimum before horizontal scroll')
assert.doesNotMatch(source, /const TABLE_SHORT_UNBREAKABLE_MIN_CELL_WIDTH = 480;/, 'MarkdownTable must not keep fix3 fixed 480vp protected width')
assert.doesNotMatch(source, /const TABLE_MIN_CELL_WIDTH = \d+;/, 'MarkdownTable must not keep a natural-width floor that overrides actual content estimates')
assert.doesNotMatch(source, /TABLE_SHORT_UNBREAKABLE_(?:MIN_CELL_WIDTH|MAX_CELL_WIDTH|SAFETY_WIDTH)/, 'MarkdownTable must not keep fix4 protected short-token product clamps')
assert.match(source, /const TABLE_CELL_HORIZONTAL_PADDING = ThemeConstants\.SPACE_SM \* 2;/, 'MarkdownTable includes cell horizontal padding in width estimates')
assert.match(markdownTableStruct[0], /textDisplayUnits\(text: string, protectedNoWrap: boolean = false\): number[\s\S]*TABLE_PROTECTED_ASCII_DISPLAY_UNIT[\s\S]*TABLE_ASCII_DISPLAY_UNIT[\s\S]*TABLE_WIDE_DISPLAY_UNIT/, 'MarkdownTable estimates text display units with separate ordinary and protected no-wrap weighting')
assert.match(markdownTableStruct[0], /naturalColumnWidths\(\): number\[\][\s\S]*this\.tableToken\.headers\[index\][\s\S]*for \(const row of this\.tableToken\.rows\)[\s\S]*widths\.push\(width\)/, 'MarkdownTable estimates natural column widths from header and row text without artificial natural caps')
assert.match(source, /const TABLE_OUTER_BORDER_WIDTH = 1;[\s\S]*const TABLE_CELL_VERTICAL_DIVIDER_WIDTH = 1;/, 'MarkdownTable declares explicit border width constants')
assert.match(markdownTableStruct[0], /tableHorizontalBorderBudget\(\): number[\s\S]*TABLE_OUTER_BORDER_WIDTH \* 2[\s\S]*TABLE_CELL_VERTICAL_DIVIDER_WIDTH[\s\S]*columnAvailableWidth\(\): number[\s\S]*this\.tableAvailableWidth - this\.tableHorizontalBorderBudget\(\)/, 'MarkdownTable declares a border budget helper for outer border and vertical dividers')
assert.match(markdownTableStruct[0], /allocatedColumnWidths\(\): number\[\][\s\S]*const availableWidth = this\.columnAvailableWidth\(\);[\s\S]*TABLE_READABLE_MIN_CELL_WIDTH/, 'MarkdownTable allocates columns with measured border-adjusted availableWidth and readable minimum')
assert.match(markdownTableStruct[0], /compressionCap = Math\.floor\(availableWidth \/ Math\.max\(1, natural\.length\) \* 1\.5\)[\s\S]*cappedTargets[\s\S]*return this\.distributeColumnWidths\(readableMin, cappedTargets, availableWidth\)/, 'MarkdownTable uses measured fair-share compression cap instead of proportional long-prose domination')
assert.match(markdownTableStruct[0], /columnWidth\(index: number\): number[\s\S]*return this\.allocatedColumnWidths\(\)\[index\]/, 'MarkdownTable columnWidth uses responsive allocated widths')
assert.match(markdownTableStruct[0], /tableMinWidth\(\): number[\s\S]*const allocated = this\.allocatedColumnWidths\(\)[\s\S]*width \+= allocated\[index\]/, 'MarkdownTable table min width sums responsive allocations')
assert.match(markdownTableStruct[0], /private tableContentWidth\(\): number[\s\S]*return this\.tableMinWidth\(\);/, 'MarkdownTable has explicit content width for ArkUI Scroll child')
assert.match(markdownTableStruct[0], /Text\(\)[\s\S]*\.constraintSize\(\{ minWidth: this\.columnWidth\(columnIndex\), maxWidth: this\.columnWidth\(columnIndex\) \}\)/, 'MarkdownTable cells constrain Text min/max width to allocated column width')
assert.match(markdownTableStruct[0], /Flex\(\{ direction: FlexDirection\.Row, alignItems: ItemAlign\.Stretch \}\)[\s\S]*\.width\(this\.tableContentWidth\(\)\)/, 'MarkdownTable rows use explicit content width with stretch alignment so cell containers span the tallest cell')
assert.match(markdownTableStruct[0], /Column\(\)[\s\S]*\.width\(this\.tableContentWidth\(\)\)[\s\S]*\.constraintSize\(\{ minWidth: this\.tableContentWidth\(\), maxWidth: this\.tableContentWidth\(\) \}\)/, 'MarkdownTable content column avoids minWidth-only stretch')
assert.match(markdownTableStruct[0], /\.border\(\{[\s\S]*width: \{ right: columnIndex < this\.columnCount\(\) - 1 \? TABLE_CELL_VERTICAL_DIVIDER_WIDTH : 0 \}[\s\S]*color: TABLE_BORDER_COLOR/, 'MarkdownTable draws internal vertical separators with per-cell right borders using the shared divider constant')
assert.match(markdownTableStruct[0], /\.border\(\{ width: TABLE_OUTER_BORDER_WIDTH, color: TABLE_BORDER_COLOR \}\)/, 'MarkdownTable outer border uses the shared outer border constant')
assert.doesNotMatch(markdownTableStruct[0], /verticalDividerIndexes\(|verticalDividerOffset\(|@Builder TableRow\(/, 'MarkdownTable must not keep row-level overlay divider helpers')
assert.doesNotMatch(markdownTableStruct[0], /Stack\(\{ alignContent: Alignment\.TopStart \}\)[\s\S]*Blank\(\)[\s\S]*\.height\("100%"\)[\s\S]*\.position\(/, 'MarkdownTable must not draw vertical separators with row-level Stack/Blank 100%-height positioned overlays')
assert.doesNotMatch(markdownTableStruct[0], /Divider\(\)[\s\S]*\.height\("100%"\)|Blank\(\)[\s\S]*\.height\("100%"\)[\s\S]*\.position\(/, 'MarkdownTable must not rely on 100%-height divider overlays')
assert.match(markdownTableStruct[0], /cellTextAlign\(cell: RenderTableCell\): TextAlign[\s\S]*cell\.align === "center"[\s\S]*cell\.align === "right"[\s\S]*TextAlign\.Start/, 'MarkdownTable applies parsed cell align with Start fallback')
assert.match(markdownTableStruct[0], /paddedRow\(row: RenderTableCell\[\]\): RenderTableCell\[\][\s\S]*const count = this\.columnCount\(\)[\s\S]*cells\.push\(row\[index\] \?\? this\.emptyCell\(\)\)/, 'MarkdownTable pads ragged rows to columnCount for consistent widths/dividers')
assert.doesNotMatch(source, /lexer\(MarkdownContent\.convertHtmlTable\(raw\)/)
const standaloneImageLineCheck = source.match(/private static isImageTokenAloneOnInlineLine[\s\S]*?return before\.trim\(\)\.length === 0 && after\.trim\(\)\.length === 0;/)
assert.ok(standaloneImageLineCheck, 'production image standalone role requires empty same-line text before and after image')
assert.match(source, /roleDecision: "source structure \/ Markdown block semantics; never intrinsic big\/small"/)
assert.match(source, /roleDecision: "source structure \/ Markdown inline semantics; rendered dimensions come from actual image size \+ content container max constraint"/)
assert.doesNotMatch(source, /INLINE_IMAGE_CONTENT_MAX_WIDTH\s*=\s*360/)
assert.match(source, /const INLINE_IMAGE_PENDING_SIZE = 24;/)
assert.match(source, /function _inlineImageRenderSize\(token: Token, sizeRecords: InlineImageSizeRecord\[\], availableWidth: number\)/)
assert.match(source, /@State private paragraphAvailableWidth: number = 0;/)
assert.match(source, /this\.updateParagraphAvailableWidth\(newValue\);/)
assert.match(source, /this\.inlineContentMaxWidth\(\)/)
assert.doesNotMatch(source, /_classifyInlineImageSize|inlineSmall|blockLarge|INLINE_IMAGE_(?:SMALL|LARGE)|INLINE_IMAGE_FALLBACK_(?:MIN|MAX)_SIZE|_inlineImageSize\(|INLINE_IMAGE_SPAN_MAX_(?:WIDTH|HEIGHT)/)
assert.match(source, /const RENDER_BODY_FONT_SIZE = 14;/)
assert.match(source, /const RENDER_BODY_LINE_HEIGHT = 20;/)
assert.match(source, /const RENDER_H1_FONT_SIZE = 22;[\s\S]*const RENDER_H1_LINE_HEIGHT = 28;/)
assert.match(source, /const RENDER_H2_FONT_SIZE = 20;[\s\S]*const RENDER_H2_LINE_HEIGHT = 26;/)
assert.match(source, /const RENDER_H3_FONT_SIZE = 18;[\s\S]*const RENDER_H3_LINE_HEIGHT = 24;/)
assert.match(source, /const RENDER_H4_FONT_SIZE = 16;[\s\S]*const RENDER_H4_LINE_HEIGHT = 22;/)
assert.match(source, /const RENDER_H5_FONT_SIZE = 15;[\s\S]*const RENDER_H5_LINE_HEIGHT = 21;/)
assert.match(source, /const RENDER_H6_FONT_SIZE = 14;[\s\S]*const RENDER_H6_LINE_HEIGHT = 20;/)
assert.match(codeInternalsSource, /export const RENDER_CODE_FONT_SIZE = 12;/)
assert.match(codeInternalsSource, /export const RENDER_CODE_LINE_HEIGHT = 18;/)
assert.match(source, /name: "h1"[\s\S]*fontSize: "fixed base 22 \* readingTextScale"[\s\S]*lineHeight: "fixed base 28 \* readingTextScale"/)
assert.match(source, /name: "h6"[\s\S]*fontSize: "fixed base 14 \* readingTextScale"[\s\S]*lineHeight: "fixed base 20 \* readingTextScale"/)
assert.match(source, /name: "code\/pre"[\s\S]*fontSize: "fixed base 12 \* readingTextScale"[\s\S]*lineHeight: "fixed base 18 \* readingTextScale"/)
assert.match(source, /private headingBaseFontSize\(token: Token\): number/)
assert.match(source, /private headingBaseLineHeight\(token: Token\): number/)
assert.match(source, /return ReadingSettings\.scaleTypographyToken\(this\.headingBaseFontSize\(token\), this\.readingTextScale\);/)
assert.match(source, /return ReadingSettings\.scaleTypographyToken\(this\.headingBaseLineHeight\(token\), this\.readingTextScale\);/)
const codeBlockBody = codeBlockSource.match(/struct MarkdownCodeBlock[\s\S]*?\n}/)[0]
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
  ['topic1212780 image-first mixed text', '![pic](https://example.com/topic1212780.png)效果已经不是当下 Agent 的主要矛盾', '<p><img src="https://example.com/topic1212780.png" alt="pic">效果已经不是当下 Agent 的主要矛盾</p>'],
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
