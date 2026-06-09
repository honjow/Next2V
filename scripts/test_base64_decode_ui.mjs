#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const MIN = 12
const MAX = 512

function tryDecodeToken(token) {
  const original = String(token || '').trim()
  if (original.length < MIN || original.length > MAX) return null
  if (!/^[A-Za-z0-9+/_=\-]+$/.test(original)) return null
  const hasUrlSafe = original.includes('-') || original.includes('_')
  const hasStandard = original.includes('+') || original.includes('/')
  if (hasUrlSafe && hasStandard) return null
  const withoutPadding = original.replace(/=+$/g, '')
  if (withoutPadding.includes('=')) return null
  const remainder = withoutPadding.length % 4
  if (remainder === 1) return null
  let normalized = withoutPadding.replace(/-/g, '+').replace(/_/g, '/')
  if (remainder > 0) normalized += '===='.slice(remainder)
  let decoded
  try {
    const bytes = Buffer.from(normalized, 'base64')
    if (!bytes.length) return null
    decoded = new TextDecoder('utf-8', { fatal: true }).decode(bytes)
  } catch {
    return null
  }
  const trimmed = decoded.trim()
  if (trimmed.length < 3 || trimmed === original) return null
  if (!isReadableText(trimmed)) return null
  return { original, decoded: trimmed }
}

function isReadableText(value) {
  let readable = 0
  let total = 0
  let lettersOrDigits = 0
  let hexLike = 0
  for (const ch of value) {
    const code = ch.codePointAt(0)
    total++
    const isControl = code < 0x20 && ch !== '\n' && ch !== '\r' && ch !== '\t'
    if (!isControl && code !== 0x7f) readable++
    if (/[A-Za-z0-9]/.test(ch) || code > 0x7f) lettersOrDigits++
    if (/[A-Fa-f0-9]/.test(ch)) hexLike++
  }
  if (total === 0) return false
  if (readable / total < 0.85 || lettersOrDigits < 2) return false
  if (value.length >= 24 && hexLike / value.length > 0.9) return false
  return true
}

function b64(text) {
  return Buffer.from(text, 'utf8').toString('base64')
}

function enhanceInlineTokens(tokens) {
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]
    if (['code', 'codespan', 'link', 'image'].includes(token.type)) continue
    if (token.type === 'text') {
      const replacement = enhancedTextRun(token.text)
      if (replacement.length) {
        tokens.splice(i, 1, ...replacement)
        i += replacement.length - 1
      }
      continue
    }
    if (Array.isArray(token.tokens)) enhanceInlineTokens(token.tokens)
    if (Array.isArray(token.items)) token.items.forEach(item => item.tokens && enhanceInlineTokens(item.tokens))
  }
  return tokens
}

function findDecodableTokens(text) {
  const results = []
  const re = /[A-Za-z0-9+/_=\-]+/g
  let match
  while ((match = re.exec(String(text || '')))) {
    const decoded = tryDecodeToken(match[0])
    if (decoded) results.push(decoded)
  }
  return results
}

function enhancedTextRun(text) {
  if (!text || text.length < MIN) return []
  const result = []
  const re = /[A-Za-z0-9+/_=\-]+/g
  let last = 0
  let changed = false
  let match
  while ((match = re.exec(text))) {
    const candidate = match[0]
    const decoded = tryDecodeToken(candidate)
    if (!decoded) continue
    if (match.index > last) result.push({ type: 'text', text: text.slice(last, match.index) })
    result.push({ type: 'text', text: candidate })
    result.push({ type: 'base64Decode', original: decoded.original, decoded: decoded.decoded, text: '' })
    last = match.index + candidate.length
    changed = true
  }
  if (!changed) return []
  if (last < text.length) result.push({ type: 'text', text: text.slice(last) })
  return result
}

function renderText(tokens, mode = 'badge') {
  return tokens.map(t => {
    if (t.type === 'base64Decode') {
      if (mode === 'inline') return ` 解码：${t.decoded}`
      if (mode === 'badge') return ' Base64'
      return ''
    }
    if (Array.isArray(t.tokens)) return renderText(t.tokens, mode)
    return t.text || ''
  }).join('')
}

function parseSimpleMarkdownInline(value) {
  const tokens = []
  const re = /\[([^\]\n]+)\]\(([^)]+)\)|`([^`]+)`/g
  let last = 0
  let match
  while ((match = re.exec(value))) {
    if (match.index > last) tokens.push({ type: 'text', text: value.slice(last, match.index) })
    if (match[2]) tokens.push({ type: 'link', href: match[2], text: match[1], tokens: [{ type: 'text', text: match[1] }] })
    else tokens.push({ type: 'codespan', text: match[3] })
    last = match.index + match[0].length
  }
  if (last < value.length) tokens.push({ type: 'text', text: value.slice(last) })
  return tokens
}

function parseSimpleHtmlInline(value) {
  const tokens = []
  const re = /<a\b[^>]*>[\s\S]*?<\/a>|<code\b[^>]*>[\s\S]*?<\/code>/gi
  let last = 0
  let match
  while ((match = re.exec(value))) {
    if (match.index > last) tokens.push({ type: 'text', text: strip(value.slice(last)) })
    const part = match[0]
    if (/^<a/i.test(part)) tokens.push({ type: 'link', href: attr(part, 'href'), text: strip(part), tokens: [{ type: 'text', text: strip(part) }] })
    else tokens.push({ type: 'codespan', text: strip(part) })
    last = re.lastIndex
  }
  if (last < value.length) tokens.push({ type: 'text', text: strip(value.slice(last).replace(/<[^>]+>/g, '')) })
  return tokens.filter(t => t.type !== 'text' || t.text)
}

function strip(value) { return String(value || '').replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&') }
function attr(tag, name) { return tag.match(new RegExp(`${name}=["']([^"']+)["']`, 'i'))?.[1] || '' }

const email = b64('hello@example.com')
assert.equal(tryDecodeToken(email)?.decoded, 'hello@example.com', 'email sample is recognized')
assert.equal(tryDecodeToken(b64('微信: wx-id_123'))?.decoded, '微信: wx-id_123', 'WeChat/readable text sample is recognized')
assert.equal(tryDecodeToken('5Lit5paH5b6u5L-h5Y-3IHd4X2FiYzEyMw')?.decoded, '中文微信号 wx_abc123', 'URL-safe base64 is recognized')
assert.equal(tryDecodeToken('aGVsbG9AZXhhbXBsZS5jb20')?.decoded, 'hello@example.com', 'missing padding is repaired')

const decodable512Prefix = b64(`${'hello@example.com '.repeat(21)}wxid42`)
assert.equal(decodable512Prefix.length, MAX, 'regression prefix is exactly the scanner max length')
assert.equal(tryDecodeToken(decodable512Prefix)?.decoded, `${'hello@example.com '.repeat(21)}wxid42`, 'regression prefix alone would be decodable')
const overlongToken = `${decodable512Prefix}AAAA`
assert.equal(overlongToken.length > MAX, true, 'regression token is over max length')
assert.equal(findDecodableTokens(overlongToken).length, 0, 'overlong continuous token is rejected as a whole')
assert.equal(enhancedTextRun(overlongToken).length, 0, 'overlong continuous token does not produce badge/inline candidate tokens')
const overlongTokens = enhanceInlineTokens([{ type: 'text', text: overlongToken }])
assert.equal(overlongTokens.some(t => t.type === 'base64Decode'), false, 'overlong continuous token has no Base64 decode token')
const overlongRenderedBadge = renderText(overlongTokens, 'badge')
const overlongRenderedInline = renderText(overlongTokens, 'inline')
assert.equal(overlongRenderedBadge.includes('Base64'), false, 'overlong continuous token does not produce a badge')
assert.equal(overlongRenderedInline.includes('解码：'), false, 'overlong continuous token does not inline decoded text')

for (const rejected of ['YWJj', '/////wAAAAAA', Buffer.from([0, 1, 2, 3, 4, 5, 6, 7, 8]).toString('base64'), '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef']) {
  assert.equal(tryDecodeToken(rejected), null, `rejects ${rejected}`)
}

const codeCandidate = b64('secret@example.com')
assert.equal(enhanceInlineTokens([{ type: 'code', text: codeCandidate }]).some(t => t.type === 'base64Decode'), false, 'code block is not enhanced')
assert.equal(enhanceInlineTokens([{ type: 'codespan', text: codeCandidate }]).some(t => t.type === 'base64Decode'), false, 'codespan is not enhanced')
assert.equal(enhanceInlineTokens([{ type: 'link', href: 'https://example.com', text: codeCandidate, tokens: [{ type: 'text', text: codeCandidate }] }]).some(t => t.type === 'base64Decode'), false, 'link text is not enhanced')

const markdownTokens = enhanceInlineTokens(parseSimpleMarkdownInline(`联系 ${email}`))
const htmlTokens = enhanceInlineTokens(parseSimpleHtmlInline(`<p>联系 ${email}</p>`))
assert.deepEqual(markdownTokens.map(t => t.type), htmlTokens.map(t => t.type), 'Markdown and rendered HTML ordinary text get same enhancement shape')
assert.equal(renderText(markdownTokens, 'badge').includes('hello@example.com'), false, 'default badge mode does not inline decoded plaintext')
assert.equal(renderText(markdownTokens, 'badge').includes('Base64'), true, 'default badge/action is explicit')
assert.equal(renderText(markdownTokens, 'badge').includes('解码：hello@example.com'), false, 'default badge mode does not inline decoded plaintext with label')
assert.equal(renderText(markdownTokens, 'inline').includes('解码：hello@example.com'), true, 'inline mode clearly labels decoded plaintext')

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
const settings = readFileSync('shared/src/main/ets/settings/ReadingSettings.ets', 'utf8')
const storageKeys = readFileSync('shared/src/main/ets/constants/StorageKeys.ets', 'utf8')
const readingFontPage = readFileSync('feature/settings/src/main/ets/pages/ReadingSettingsPage.ets', 'utf8')
const settingsPage = readFileSync('feature/settings/src/main/ets/pages/SettingsPage.ets', 'utf8')
// i18n migration: the Base64 setting title/subtitle moved to ResourceManager keys on SettingsPage,
// and the mode-option labels (tap-to-view / inline-display) moved into SettingsPageCoordinator.
const settingsCoordinator = readFileSync('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets', 'utf8')
assert.match(source, /enhanceBase64TextTokens\(tokens\)/)
assert.match(source, /type === 'code' \|\| type === 'codespan' \|\| type === 'link'/)
assert.match(source, /Span\(" Base64"\)/)
assert.match(source, /struct Base64PopupBadge[\s\S]*@Local private isPopupVisible: boolean = false[\s\S]*Button\(\)[\s\S]*Text\("Base64"\)/, 'default badge uses a component-local stateful Button anchor for device hit testing')
assert.match(source, /SelectableInlineTokenFlow[\s\S]*Base64PopupBadge\(\{[\s\S]*token: t as Base64DecodeToken/, 'Base64 badge mode is split out of Text Span flow when popup interaction is needed')
assert.match(source, /struct SelectableInlineTokenFlow[\s\S]*@Param fontColor: ResourceColor[\s\S]*@Param fontWeight: FontWeight[\s\S]*@Param lineHeight: number[\s\S]*@Param textAlign: TextAlign[\s\S]*@Param wordBreak: WordBreak[\s\S]*@Param copyOption: CopyOptions[\s\S]*@Param textSelectable: TextSelectableMode/, 'badge flow exposes explicit typography, wrapping, copy, and selection props instead of implicit body defaults')
assert.match(source, /struct SelectableInlineTokenFlow[\s\S]*\.fontWeight\(this\.fontWeight\)[\s\S]*\.fontColor\(this\.fontColor\)[\s\S]*\.lineHeight\(this\.lineHeight\)[\s\S]*\.textAlign\(this\.textAlign\)[\s\S]*\.wordBreak\(this\.wordBreak\)[\s\S]*\.copyOption\(this\.copyOption\)[\s\S]*\.textSelectable\(this\.textSelectable\)/, 'badge flow applies explicit style/behavior props to text fragments')
assert.match(source, /SelectableInlineTokenFlow\(\{\s*\n\s*tokens: this\.headingInlineTokens\(token\),[\s\S]{0,900}fontColor: this\.headingColor\(token\),[\s\S]{0,120}fontWeight: this\.headingWeight\(token\),[\s\S]{0,120}lineHeight: this\.headingLineHeight\(token\),[\s\S]{0,240}copyOption: CopyOptions\.LocalDevice,[\s\S]{0,120}textSelectable: TextSelectableMode\.SELECTABLE_FOCUSABLE/, 'badge-containing heading path preserves heading color/weight/lineHeight and copy/selectable semantics')
assert.match(source, /SelectableInlineTokenFlow\(\{\s*\n\s*tokens: this\.cellTokens\(cell\),[\s\S]{0,900}fontWeight: header \? FontWeight\.Medium : FontWeight\.Regular,[\s\S]{0,160}textAlign: this\.cellTextAlign\(cell\),[\s\S]{0,120}wordBreak: WordBreak\.BREAK_WORD,[\s\S]{0,120}copyOption: CopyOptions\.LocalDevice,[\s\S]{0,120}textSelectable: TextSelectableMode\.SELECTABLE_FOCUSABLE/, 'badge-containing table cell path preserves header/body weight, alignment, word break, and copy/selectable semantics')
assert.match(source, /SelectableInlineTokenFlow\(\{\s*\n\s*tokens: this\.inlineTokens\(\),[\s\S]{0,900}lineHeight: this\.bodyLineHeight\(\),[\s\S]{0,160}wordBreak: WordBreak\.BREAK_WORD,[\s\S]{0,120}copyOption: CopyOptions\.LocalDevice,[\s\S]{0,120}textSelectable: TextSelectableMode\.SELECTABLE_FOCUSABLE/, 'badge-containing paragraph path preserves line height, word break, and copy/selectable semantics')
assert.doesNotMatch(source, /Span\(" Base64"\)[\s\S]{0,800}\.bindPopup/, 'Text Span fallback must not be the popup anchor')
assert.doesNotMatch(source, /Base64\/解码/)
assert.doesNotMatch(source, /AlertDialog\.show/, 'default badge must use system Popup instead of AlertDialog')
assert.match(source, /struct Base64PopupBadge[\s\S]*@Builder\s+Base64PopupContent\(\)[\s\S]*Text\(this\.token\.decoded\)/, 'Base64 custom popup builder renders decoded text directly')
assert.match(source, /Button\(\)[\s\S]*\.bindPopup\(this\.isPopupVisible, \{[\s\S]*builder: this\.Base64PopupContent[\s\S]*autoCancel: true[\s\S]*mask: false[\s\S]*onStateChange:/, 'default badge popup uses CustomPopupOptions builder on the Button anchor with autoCancel, mask:false, and state sync')
const base64PopupContent = source.match(/@Builder\s+Base64PopupContent\(\) \{[\s\S]*?\n  \}\n\n  build\(\)/)?.[0] || ''
assert.match(base64PopupContent, /Text\(this\.token\.decoded\)/, 'Base64 popup content shows decoded text only')
assert.match(base64PopupContent, /\.onClick\(\(\) => \{[\s\S]*_copyDecodedBase64Text\(this\.token\.decoded\);[\s\S]*this\.isPopupVisible = false;/, 'clicking popup content copies decoded text and closes the popup')
assert.doesNotMatch(base64PopupContent, /Base64 解码|原文：|Button\(|value: "复制"|value: "关闭"|AlertDialog/, 'Base64 custom popup content must not include title, original summary, or buttons')
const base64PopupOptions = source.match(/\.bindPopup\(this\.isPopupVisible, \{[\s\S]*?\n    \}\);/)?.[0] || ''
assert.match(base64PopupOptions, /builder: this\.Base64PopupContent/, 'Base64 badge opens CustomPopupOptions through builder')
assert.doesNotMatch(base64PopupOptions, /\bprimaryButton\s*:|\bsecondaryButton\s*:/, 'Base64 CustomPopupOptions must not use primaryButton or secondaryButton')
assert.doesNotMatch(base64PopupOptions, /\bwidth\s*:/, 'Base64 CustomPopupOptions must not set width; let custom content and system space decide')
assert.doesNotMatch(base64PopupOptions, /message:|value: "复制"|value: "关闭"|Base64 解码|原文：|AlertDialog/, 'Base64 CustomPopupOptions must not use ordinary message/actions or dialog labels')
assert.doesNotMatch(source, /AlertDialog\.show/, 'default badge must use system Popup instead of AlertDialog')
assert.doesNotMatch(source, /console\.(?:log|info|warn|error)\([^\n]*(?:decoded|Base64 解码|解码文本)/, 'decoded Base64 text must not be logged')
assert.match(settings, /KEY_BASE64_DECODE_MODE: string = StorageKeys\.READING_BASE64_DECODE_MODE/)
assert.match(storageKeys, /READING_BASE64_DECODE_MODE: string = 'readingBase64DecodeMode'/)
assert.match(settings, /BASE64_MODE_BADGE: string = 'badge'/)
assert.match(settingsPage, /title: \$r\('app\.string\.base64_decode'\)/) // "Base64 解码"
assert.match(settingsCoordinator, /label: \$r\('app\.string\.tap_to_view'\), value: ReadingSettings\.BASE64_MODE_BADGE/) // "点击查看"
assert.match(settingsCoordinator, /label: \$r\('app\.string\.inline_display'\), value: ReadingSettings\.BASE64_MODE_INLINE/) // "文内显示"
assert.doesNotMatch(readingFontPage, /Base64 解码/)
assert.doesNotMatch(readingFontPage, /BASE64_MODE/)

console.log('PASS: Base64 decode UI detection, AST enhancement, privacy default, inline labeling, and settings contract')
