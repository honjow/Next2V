#!/usr/bin/env node

const IMAGE_BLOCK_MONO = 'customImageBlock'

function normalizeMarkdownSource(md) {
  return (md || '').replace(/\]\(\s+(https?:\/\/[^\s)]+)\s*\)/gi, ']($1)')
}

function imageUrlForRender(raw) {
  const url = (raw || '').trim()
  if (!/^https?:\/\//i.test(url)) return ''
  if (/\.(jpe?g|png|gif|webp|bmp|svg|avif|heic|heif)(?:[?#].*)?$/i.test(url)) return url
  return ''
}

function buildTextToken(text) {
  return { type: 'text', raw: text, text }
}

function buildImageToken(raw, href, text = '') {
  return { type: 'image', raw, href, title: null, text }
}

function splitTextImageUrls(token) {
  const text = token.text || token.raw || ''
  const result = []
  const re = /https?:\/\/[^\s<>()]+/gi
  let last = 0
  let m = re.exec(text)
  while (m) {
    const rawUrl = m[0].replace(/[.,!?;:，。！？；：]+$/g, '')
    const renderUrl = imageUrlForRender(rawUrl)
    if (!renderUrl) {
      m = re.exec(text)
      continue
    }
    if (m.index > last) result.push(buildTextToken(text.slice(last, m.index)))
    result.push(buildImageToken(rawUrl, renderUrl))
    last = m.index + rawUrl.length
    m = re.exec(text)
  }
  if (last === 0) return [token]
  if (last < text.length) result.push(buildTextToken(text.slice(last)))
  return result
}

function firstNestedImage(token) {
  const children = token.tokens || []
  for (const child of children) {
    if (child.type === 'image') {
      const href = imageUrlForRender(child.href)
      if (href) return { ...child, href }
    }
  }
  return null
}

function rewriteInlineImageToken(token) {
  if (token.type === 'link') {
    const nested = firstNestedImage(token)
    if (nested) return [nested]
    const href = imageUrlForRender(token.href)
    const text = (token.text || '').trim()
    if (href && (!text || text === token.href)) return [buildImageToken(token.raw || text, href, text)]
    return [token]
  }
  if (token.type === 'text') return splitTextImageUrls(token)
  return [token]
}

function rewriteParagraphInlineImages(paragraph) {
  paragraph.tokens = (paragraph.tokens || []).flatMap(rewriteInlineImageToken)
}

function splitParagraphByImages(paragraph) {
  const inlineTokens = paragraph.tokens || []
  if (!inlineTokens.some((t) => t.type === 'image')) return []
  const result = []
  let textTokens = []
  const flush = () => {
    const meaningful = textTokens.filter((t) => t.type !== 'br' && String(t.raw || t.text || '').trim())
    if (meaningful.length) {
      result.push({
        type: 'paragraph',
        raw: textTokens.map((t) => t.raw || t.text || '').join(''),
        text: textTokens.map((t) => t.text || t.raw || '').join(''),
        tokens: textTokens
      })
    }
  }
  for (const token of inlineTokens) {
    if (token.type === 'image') {
      flush()
      textTokens = []
      token.type = IMAGE_BLOCK_MONO
      result.push(token)
    } else {
      textTokens.push(token)
    }
  }
  flush()
  return result.length > 1 ? result : []
}

function promoteStandaloneImageParagraphs(tokens) {
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]
    if (token.type === 'paragraph') {
      const inlineTokens = token.tokens || []
      const meaningful = inlineTokens.filter((t) => t && t.type !== 'br')
      if (meaningful.length > 0 && meaningful.every((t) => t.type === 'image')) {
        for (const imageToken of meaningful) imageToken.type = IMAGE_BLOCK_MONO
        tokens.splice(i, 1, ...meaningful)
        i += meaningful.length - 1
      }
    }
  }
}

const fixture = [
  '![pic_7.png]( https://iili.io/BtYjJwP.png)',
  '![pic_8.png]( https://iili.io/BtYjKPa.png)',
  '[![peOMvse.png]( https://s41.ax1x.com/2026/05/11/peOMvse.png)]( https://imgchr.com/i/peOMvse)',
  '',
  'normal text should stay unchanged',
  '![already_ok](https://example.com/a.png)'
].join('\n')

const actual = normalizeMarkdownSource(fixture)
const expected = [
  '![pic_7.png](https://iili.io/BtYjJwP.png)',
  '![pic_8.png](https://iili.io/BtYjKPa.png)',
  '[![peOMvse.png](https://s41.ax1x.com/2026/05/11/peOMvse.png)](https://imgchr.com/i/peOMvse)',
  '',
  'normal text should stay unchanged',
  '![already_ok](https://example.com/a.png)'
].join('\n')

if (actual !== expected) {
  console.error('FAIL markdown image/link destination spacing normalization')
  console.error('expected:\n' + expected)
  console.error('actual:\n' + actual)
  process.exit(1)
}

const tokens = [{
  type: 'paragraph',
  tokens: [
    { type: 'image', href: 'https://iili.io/BtYjJwP.png', text: 'pic_7.png' },
    { type: 'br' },
    { type: 'image', href: 'https://iili.io/BtYjKPa.png', text: 'pic_8.png' },
    { type: 'br' },
    { type: 'image', href: 'https://iili.io/BtYglEB.png', text: 'pic_10.png' }
  ]
}]
promoteStandaloneImageParagraphs(tokens)
if (tokens.length !== 3 || !tokens.every((t) => t.type === IMAGE_BLOCK_MONO)) {
  console.error('FAIL multiple standalone image paragraph promotion')
  console.error(JSON.stringify(tokens, null, 2))
  process.exit(1)
}

const linkedImageParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'text', raw: '正文\n', text: '正文\n' },
    { type: 'link', raw: '[![peOMvse.png](https://s41.ax1x.com/2026/05/11/peOMvse.png)](https://imgchr.com/i/peOMvse)', href: 'https://imgchr.com/i/peOMvse', text: 'peOMvse.png', tokens: [
      { type: 'image', raw: '![peOMvse.png](https://s41.ax1x.com/2026/05/11/peOMvse.png)', href: 'https://s41.ax1x.com/2026/05/11/peOMvse.png', text: 'peOMvse.png' }
    ] },
    { type: 'link', raw: '[![peOMjMD.png](https://s41.ax1x.com/2026/05/11/peOMjMD.png)](https://imgchr.com/i/peOMjMD)', href: 'https://imgchr.com/i/peOMjMD', text: 'peOMjMD.png', tokens: [
      { type: 'image', raw: '![peOMjMD.png](https://s41.ax1x.com/2026/05/11/peOMjMD.png)', href: 'https://s41.ax1x.com/2026/05/11/peOMjMD.png', text: 'peOMjMD.png' }
    ] }
  ]
}
rewriteParagraphInlineImages(linkedImageParagraph)
const linkedSplit = splitParagraphByImages(linkedImageParagraph)
if (linkedSplit.length !== 3 || linkedSplit[1].type !== IMAGE_BLOCK_MONO || linkedSplit[1].href !== 'https://s41.ax1x.com/2026/05/11/peOMvse.png' || linkedSplit[2].type !== IMAGE_BLOCK_MONO || linkedSplit[2].href !== 'https://s41.ax1x.com/2026/05/11/peOMjMD.png') {
  console.error('FAIL linked image markdown paragraph splitting')
  console.error(JSON.stringify(linkedSplit, null, 2))
  process.exit(1)
}

const inlineBareImageParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'text', raw: '我一个完全不懂 css 的后端，现在都开始写大屏了 https://i.imgur.com/huX6coX.png', text: '我一个完全不懂 css 的后端，现在都开始写大屏了 https://i.imgur.com/huX6coX.png' }
  ]
}
rewriteParagraphInlineImages(inlineBareImageParagraph)
const bareSplit = splitParagraphByImages(inlineBareImageParagraph)
if (bareSplit.length !== 2 || bareSplit[1].type !== IMAGE_BLOCK_MONO || bareSplit[1].href !== 'https://i.imgur.com/huX6coX.png') {
  console.error('FAIL inline bare image URL paragraph splitting')
  console.error(JSON.stringify(bareSplit, null, 2))
  process.exit(1)
}

console.log('PASS: markdown image spacing, linked images, and inline bare image URLs')
