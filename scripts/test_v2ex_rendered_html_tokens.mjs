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
  const re = new RegExp(`(?:^|\\s)${name}\\s*=\\s*(?:(["'])(.*?)\\1|([^\\s"'=<>]+))`, 'i')
  const m = tag.match(re)
  const value = m ? (m[2] || m[3] || '') : ''
  return value ? decodeHtml(value).trim() : ''
}

function hasHtmlClass(tag, className) {
  return attr(tag, 'class').split(/\s+/).includes(className)
}

function decodeCfEmail(cfemail) {
  const value = (cfemail || '').trim()
  if (value.length < 4 || value.length % 2 !== 0 || !/^[0-9a-f]+$/i.test(value)) return ''
  const key = parseInt(value.slice(0, 2), 16)
  let out = ''
  for (let i = 2; i < value.length; i += 2) {
    out += String.fromCharCode(parseInt(value.slice(i, i + 2), 16) ^ key)
  }
  return out
}

function stripTags(value) {
  return decodeHtml((value || '').replace(/<[^>]+>/g, ''))
    .replace(/[ \t\f\v\r\n]+/g, ' ')
    .trim()
}

function extractPreCodeTextFromRenderedHtml(preHtml) {
  const bodyMatch = (preHtml || '').match(/^<pre\b[^>]*>([\s\S]*?)<\/pre>$/i)
  let body = bodyMatch ? bodyMatch[1] : (preHtml || '')
  const codeMatch = body.match(/^\s*<code\b[^>]*>([\s\S]*?)<\/code>\s*$/i)
  if (codeMatch) body = codeMatch[1]
  return decodeHtml(body)
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .trim()
}

function parseMarkdownInlineTextTokens(text) {
  const result = []
  const re = /\[([^\]\n]+)\]\(\s*(https?:\/\/[^\s)]+)\s*\)/g
  let last = 0
  let match
  while ((match = re.exec(text || ''))) {
    if (match.index > last) result.push({ type: 'text', text: text.slice(last, match.index) })
    result.push({ type: 'link', href: match[2], text: match[1] })
    last = match.index + match[0].length
  }
  if (last === 0) return [{ type: 'text', text }]
  if (last < text.length) result.push({ type: 'text', text: text.slice(last) })
  return result
}

function appendText(tokens, text) {
  const value = decodeHtml(text).replace(/[ \t\f\v\r\n]+/g, ' ')
  if (!value) return
  for (const token of parseMarkdownInlineTextTokens(value)) {
    const last = tokens[tokens.length - 1]
    if (token.type === 'text' && last && last.type === 'text') last.text += token.text
    else tokens.push(token)
  }
}

function trimTextEdges(tokens) {
  while (tokens.length && tokens[0].type === 'text' && !tokens[0].text.trim()) tokens.shift()
  while (tokens.length && tokens[tokens.length - 1].type === 'text' && !tokens[tokens.length - 1].text.trim()) tokens.pop()
  if (tokens[0]?.type === 'text') tokens[0].text = tokens[0].text.replace(/^\s+/, '')
  const last = tokens[tokens.length - 1]
  if (last?.type === 'text') last.text = last.text.replace(/\s+$/, '')
}

function inlineHtmlToTokens(html) {
  const tokens = []
  let index = 0
  const re = /<a\b[^>]*>[\s\S]*?<\/a>|<img\b[^>]*>|<br\s*\/?>|<code\b[^>]*>[\s\S]*?<\/code>|<(strong|b|em|i)\b[^>]*>[\s\S]*?<\/\1>/gi
  let match
  while ((match = re.exec(html || ''))) {
    appendText(tokens, html.slice(index, match.index))
    const part = match[0]
    if (/^<br/i.test(part)) tokens.push({ type: 'br' })
    else if (/^<img/i.test(part)) tokens.push({ type: 'image', href: attr(part, 'src') })
    else if (/^<a/i.test(part)) {
      const href = attr(part, 'href')
      const imgs = [...part.matchAll(/<img\b[^>]*>/gi)].map(m => attr(m[0], 'src') || href).filter(Boolean)
      if (imgs.length) imgs.forEach(src => tokens.push({ type: 'image', href: src }))
      else {
        const label = stripTags(part)
        if (hasHtmlClass(part, '__cf_email__')) {
          const decodedEmail = decodeCfEmail(attr(part, 'data-cfemail'))
          tokens.push({ type: 'text', text: decodedEmail || label })
          index = re.lastIndex
          continue
        }
        if (/^\/member\//.test(href) && tokens[tokens.length - 1]?.type === 'text') {
          tokens[tokens.length - 1].text = tokens[tokens.length - 1].text.replace(/@\s*$/, '')
        }
        tokens.push({ type: 'link', href, text: label })
      }
    } else if (/^<code/i.test(part)) tokens.push({ type: 'codespan', text: stripTags(part) })
    else if (/^<(strong|b)/i.test(part)) tokens.push({ type: 'strong', text: stripTags(part) })
    else if (/^<(em|i)/i.test(part)) tokens.push({ type: 'em', text: stripTags(part) })
    index = re.lastIndex
  }
  appendText(tokens, (html || '').slice(index).replace(/<[^>]+>/g, ''))
  trimTextEdges(tokens)
  return tokens
}

const exact117 = '@<a href="/member/vipfts">vipfts</a> <a target="_blank" href="https://i.imgur.com/U3hKhrT.png"><img src="https://i.imgur.com/U3hKhrT.png"></a><a target="_blank" href="https://i.imgur.com/U3hKhrT.png"><img src="https://i.imgur.com/U3hKhrT.png"></a>'
const tokens117 = inlineHtmlToTokens(exact117)
assert.deepEqual(tokens117.map(t => t.type), ['link', 'text', 'image', 'image'])
assert.equal(tokens117[0].href, '/member/vipfts')
assert.equal(tokens117[0].text, 'vipfts')
assert.equal(tokens117.filter(t => t.type === 'image' && t.href === 'https://i.imgur.com/U3hKhrT.png').length, 2)

const exact127 = '@<a href="/member/iixy">iixy</a> #6 要黑丝也可以 <a target="_blank" href="https://i.imgur.com/MA8YqTP.png"><img src="https://i.imgur.com/MA8YqTP.png"></a>'
const tokens127 = inlineHtmlToTokens(exact127)
assert.deepEqual(tokens127.map(t => t.type), ['link', 'text', 'image'])
assert.equal(tokens127[1].text, ' #6 要黑丝也可以 ')
assert.equal(tokens127[2].href, 'https://i.imgur.com/MA8YqTP.png')

const topic1212780Mixed = '<p><img src="https://example.com/topic1212780.png" alt="pic">效果已经不是当下 Agent 的主要矛盾</p>'
const topic1212780Tokens = inlineHtmlToTokens(topic1212780Mixed.replace(/^<p>|<\/p>$/g, ''))
assert.deepEqual(topic1212780Tokens.map(t => t.type), ['image', 'text'])
assert.equal(topic1212780Tokens[0].href, 'https://example.com/topic1212780.png')
assert.equal(topic1212780Tokens[1].text, '效果已经不是当下 Agent 的主要矛盾')

const imageFirstMixed = '<p><img src="https://example.com/a.png" alt="pic"> after</p>'
const imageFirstMixedTokens = inlineHtmlToTokens(imageFirstMixed.replace(/^<p>|<\/p>$/g, ''))
assert.deepEqual(imageFirstMixedTokens.map(t => t.type), ['image', 'text'])
assert.equal(imageFirstMixedTokens[0].href, 'https://example.com/a.png')
assert.equal(imageFirstMixedTokens[1].text, ' after')

const markdownLink = '<p>[coolpace/V2EX_Polish](https://github.com/coolpace/V2EX_Polish/tree/main)</p>'
const markdownLinkTokens = inlineHtmlToTokens(markdownLink.replace(/^<p>|<\/p>$/g, ''))
assert.deepEqual(markdownLinkTokens.map(t => t.type), ['link'])
assert.equal(markdownLinkTokens[0].text, 'coolpace/V2EX_Polish')
assert.equal(markdownLinkTokens[0].href, 'https://github.com/coolpace/V2EX_Polish/tree/main')

const spacedMarkdownLink = '<p>[coolpace/V2EX_Polish]( https://github.com/coolpace/V2EX_Polish/tree/main )</p>'
const spacedMarkdownLinkTokens = inlineHtmlToTokens(spacedMarkdownLink.replace(/^<p>|<\/p>$/g, ''))
assert.deepEqual(spacedMarkdownLinkTokens.map(t => t.type), ['link'])
assert.equal(spacedMarkdownLinkTokens[0].text, 'coolpace/V2EX_Polish')
assert.equal(spacedMarkdownLinkTokens[0].href, 'https://github.com/coolpace/V2EX_Polish/tree/main')

const topic1212851Reply2 = '谢谢老板，<a href="/cdn-cgi/l/email-protection" class="__cf_email__" data-cfemail="6e1a1a0f0f1e1a0f2e5f585d400d0103">[email&#160;protected]</a>'
const topic1212851Tokens = inlineHtmlToTokens(topic1212851Reply2)
assert.deepEqual(topic1212851Tokens.map(t => t.type), ['text', 'text'])
assert.equal(topic1212851Tokens.map(t => t.text || '').join(''), '谢谢老板，ttaapta@163.com')
assert.equal(topic1212851Tokens.some(t => t.href === '/cdn-cgi/l/email-protection'), false)

const cfEmailVariations = [
  '<a data-cfemail="6e1a1a0f0f1e1a0f2e5f585d400d0103" class="quiet __cf_email__ extra" href="/cdn-cgi/l/email-protection">hidden</a>',
  "<a class='quiet __cf_email__ extra' href='/cdn-cgi/l/email-protection' data-cfemail='6e1a1a0f0f1e1a0f2e5f585d400d0103'>hidden</a>",
]
for (const html of cfEmailVariations) {
  const tokens = inlineHtmlToTokens(html)
  assert.deepEqual(tokens, [{ type: 'text', text: 'ttaapta@163.com' }])
}

const malformedCfEmail = '<a href="/cdn-cgi/l/email-protection" class="__cf_email__" data-cfemail="not-hex">[email&#160;protected]</a>'
const malformedCfTokens = inlineHtmlToTokens(malformedCfEmail)
assert.deepEqual(malformedCfTokens, [{ type: 'text', text: '[email protected]' }])

const dataClassLinkTokens = inlineHtmlToTokens('<a data-class="__cf_email__" data-cfemail="6e1a1a0f0f1e1a0f2e5f585d400d0103" href="https://example.com">Example</a>')
assert.deepEqual(dataClassLinkTokens, [{ type: 'link', href: 'https://example.com', text: 'Example' }])
assert.equal(dataClassLinkTokens.some(t => t.text === 'ttaapta@163.com'), false)

const prefixedClassLinkTokens = inlineHtmlToTokens('<a xclass="__cf_email__" data-cfemail="6e1a1a0f0f1e1a0f2e5f585d400d0103" href="https://example.com/prefixed">Prefixed</a>')
assert.deepEqual(prefixedClassLinkTokens, [{ type: 'link', href: 'https://example.com/prefixed', text: 'Prefixed' }])

const ariaClassLinkTokens = inlineHtmlToTokens('<a aria-class="__cf_email__" data-cfemail="6e1a1a0f0f1e1a0f2e5f585d400d0103" href="https://example.com/aria">Aria</a>')
assert.deepEqual(ariaClassLinkTokens, [{ type: 'link', href: 'https://example.com/aria', text: 'Aria' }])

const normalLinkTokens = inlineHtmlToTokens('<a href="https://example.com/path">Example</a>')
assert.deepEqual(normalLinkTokens, [{ type: 'link', href: 'https://example.com/path', text: 'Example' }])

const memberLinkTokens = inlineHtmlToTokens('@<a href="/member/example_user">example_user</a>')
assert.deepEqual(memberLinkTokens, [{ type: 'link', href: '/member/example_user', text: 'example_user' }])

const topic1212814CodeHtml = '<pre><code>&lt;video&gt;\n  &lt;model name=&quot;cube&quot; /&gt;\n  &lt;graphics api=&quot;webgpu&quot;&gt;ok&lt;/graphics&gt;\n&lt;/video&gt;</code></pre>'
const topic1212814CodeText = extractPreCodeTextFromRenderedHtml(decodeHtml(topic1212814CodeHtml))
assert.equal(topic1212814CodeText, '<video>\n  <model name="cube" />\n  <graphics api="webgpu">ok</graphics>\n</video>')
assert.match(topic1212814CodeText, /<video>/)
assert.match(topic1212814CodeText, /<model name="cube" \/>/)
assert.match(topic1212814CodeText, /<graphics api="webgpu">ok<\/graphics>/)
assert.notEqual(topic1212814CodeText.trim(), '')

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
const readingSettingsPageSource = readFileSync('feature/settings/src/main/ets/pages/ReadingSettingsPage.ets', 'utf8')
assert.match(source, /renderedHtmlToTokens/)
assert.match(source, /inlineHtmlToTokens/)
assert.match(source, /decodeCloudflareEmail/)
assert.match(source, /htmlClassContains\(part, '__cf_email__'\)/)
assert.match(source, /data-cfemail/)
assert.ok(source.includes('`(?:^|\\\\s)${name}\\\\s*='), 'MarkdownContent.htmlAttr must require start-or-whitespace before the attribute name')
assert.doesNotMatch(source, /new RegExp\(`\$\{name\}\\\\s\*=\\\\s\*\(\["'\]\)\(\.\*\?\)\\\\1`, 'i'\)/)
assert.match(source, /parseMarkdownInlineTextTokens/)
assert.match(source, /MarkdownBlockquote/)
assert.doesNotMatch(source, /\.height\('100%'\)[\s\S]{0,160}quoteDriveColor/)
assert.doesNotMatch(source, /_classifyInlineImageSize|inlineSmall|blockLarge|INLINE_IMAGE_(?:SMALL|LARGE)|INLINE_IMAGE_FALLBACK_(?:MIN|MAX)_SIZE|_inlineImageSize\(|INLINE_IMAGE_SPAN_MAX_(?:WIDTH|HEIGHT)/)

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
assert.match(source, /return ReadingSettings\.scaleTypographyToken\(this\.headingBaseFontSize\(token\), this\.readingTextScale\);/)
assert.match(source, /return ReadingSettings\.scaleTypographyToken\(this\.headingBaseLineHeight\(token\), this\.readingTextScale\);/)
const codeBlockBody = source.match(/struct MarkdownCodeBlock[\s\S]*?\n}\n\n@Component\nstruct MarkdownAutoImage/)[0]
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
assert.doesNotMatch(readingSettingsPageSource, /Text\('行距'\)|updateReadingLineHeight|readingLineHeightMin|@StorageLink\(StorageKeys\.READING_LINE_HEIGHT\)|value:\s*this\.readingLineHeight/)
assert.match(readingSettingsPageSource, /将文字缩放恢复为默认值/)
assert.match(source, /private headingInlineTokens\(token: Token\): Token\[\]/)
assert.match(source, /const RENDER_STYLE_CONTRACT_TABLE: RenderContractStyleRow\[\]/)
assert.match(source, /parseMarkdownToRenderAst\(source: string/)
assert.match(source, /parseRenderedHtmlToRenderAst\(contentRendered: string/)
assert.match(source, /const blockRe = \/<\(table\|h\[1-6\]\|p\|ul\|ol\|blockquote\|pre\|div\)/)
assert.match(source, /tag === 'blockquote'/)
assert.match(source, /tag === 'pre'/)
assert.match(source, /private static extractPreCodeTextFromRenderedHtml\(body: string\): string/)
const preBranch = source.match(/if \(tag === 'pre'\) \{[\s\S]*?\n    \}/)?.[0] || ''
assert.match(preBranch, /MarkdownContent\.extractPreCodeTextFromRenderedHtml\(body\)/)
assert.match(preBranch, /MarkdownContent\.buildCodeBlockToken\(/)
assert.match(preBranch, /MarkdownContent\.extractPreCodeLanguageFromRenderedHtml\(raw, body\)/)
assert.doesNotMatch(preBranch, /stripHtmlTags\(body\)/)
assert.doesNotMatch(source, /tag === 'pre'[\s\S]{0,220}stripHtmlTags\(body\)/)
assert.doesNotMatch(source, /12 - level \* 2/)
assert.doesNotMatch(source, /headingLevel\(token\) <= 3/)
assert.doesNotMatch(source, /FontWeight\.Bold : FontWeight\.Medium/)
assert.doesNotMatch(source, /Math\.min\(this\.bodyFontSize\(\), ThemeConstants\.FONT_SIZE_BODY\)/)
const processTokensBody = source.match(/private static processTokens\([\s\S]*?return tokens;/)[0]
assert.doesNotMatch(processTokensBody, /renderedHtmlToMarkdown/)
assert.match(processTokensBody, /parseRenderedHtmlToRenderAst\(decodedSource, sizeRecords\)/)
assert.match(source, /return before\.trim\(\)\.length === 0 && after\.trim\(\)\.length === 0;/)
const inlineSizeSource = source.match(/function _inlineImageRenderSize[\s\S]*?\n}/)?.[0] || ''
assert.doesNotMatch(source, /INLINE_IMAGE_CONTENT_MAX_WIDTH\s*=\s*360/)
assert.match(source, /const INLINE_IMAGE_PENDING_SIZE = 1;/)
assert.match(inlineSizeSource, /availableWidth: number/)
assert.match(inlineSizeSource, /const contentMaxWidth = Math\.max\(0, availableWidth\);/)
assert.match(inlineSizeSource, /widthPx[\s\S]*heightPx/)
assert.match(inlineSizeSource, /width: INLINE_IMAGE_PENDING_SIZE,[\s\S]*height: INLINE_IMAGE_PENDING_SIZE/)
assert.match(inlineSizeSource, /scale = Math\.min\(1, contentMaxWidth \/ widthPx/)
assert.match(source, /@State private paragraphAvailableWidth: number = 0;/)
assert.match(source, /\.onAreaChange\(\(_oldValue: Area, newValue: Area\) => \{\n\s*this\.updateParagraphAvailableWidth\(newValue\);/)
assert.match(source, /SelectableInlineTokenSpans\([\s\S]*this\.inlineContentMaxWidth\(\)/)
assert.doesNotMatch(source, /return \{ width: fallback, height: fallback \}/)

console.log('PASS: V2EX rendered HTML mirror/static checks preserve adjacent images, topic1212780 image-first mixed inline content, markdown links, and member links')
