#!/usr/bin/env node

const IMAGE_BLOCK_MONO = 'customImageBlock'
const INLINE_IMAGE_PROP = 'inlineImage'
const MEDIA_QUERY_EXT_REGEX = /(?:[?&]|&amp;)(?:format|fm|ext|type|output|wx_fmt)=([a-z0-9/]+)/i
const GITHUB_FILE_IMAGE_PAGE_REGEX = /^https?:\/\/(?:www\.)?github\.com\/([^/?#]+)\/([^/?#]+)\/(?:blob|raw)\/([^?#]+)(?:[?#].*)?$/i

function normalizeMarkdownSource(md) {
  return (md || '')
    .replace(/<a\b[^>]*>\s*<img\b[^>]*\bsrc=(["'])(https?:\/\/[^"']+)\1[^>]*>\s*<\/a>/gi, '$2')
    .replace(/<img\b[^>]*\bsrc=(["'])(https?:\/\/[^"']+)\1[^>]*>/gi, '$2')
    .replace(/\]\(\s+(https?:\/\/[^\s)]+)\s*\)/gi, ']($1)')
}

function imageUrlForRender(raw) {
  const url = (raw || '').trim()
  if (!/^https?:\/\//i.test(url)) return ''
  const githubDirect = resolveGithubImagePage(url)
  if (githubDirect) return githubDirect
  if (/\.(jpe?g|png|gif|webp|bmp|svg|avif|heic|heif)(?:[?#].*)?$/i.test(url) || imageExtensionFromUrl(url)) return url
  return ''
}

function normalizeImageExtension(raw) {
  let ext = (raw || '').toLowerCase().trim()
  if (ext.includes('/')) ext = ext.split('/').pop() || ''
  if (ext === 'jpeg' || ext === 'jpg') return 'jpg'
  return ['png', 'gif', 'webp', 'bmp', 'svg', 'avif', 'heic', 'heif'].includes(ext) ? ext : ''
}

function imageExtensionFromUrl(raw) {
  const clean = (raw || '').trim().split('#')[0]
  const queryMatch = clean.match(MEDIA_QUERY_EXT_REGEX)
  const queryExt = normalizeImageExtension(queryMatch?.[1] || '')
  if (queryExt) return queryExt
  const match = clean.split('?')[0].match(/\.([a-z0-9]+)$/i)
  return normalizeImageExtension(match?.[1] || '')
}

function resolveGithubImagePage(url) {
  const match = url.match(GITHUB_FILE_IMAGE_PAGE_REGEX)
  if (!match?.[1] || !match?.[2] || !match?.[3]) return ''
  const filePath = match[3]
  if (!imageExtensionFromUrl(filePath)) return ''
  return `https://raw.githubusercontent.com/${match[1]}/${match[2]}/${filePath}`
}

function buildTextToken(text) {
  return { type: 'text', raw: text, text }
}

function isInlineImageToken(token) {
  return token && token.type === 'image' && token[INLINE_IMAGE_PROP] === true
}

function isMixedInlineImageCandidate(token) {
  if (!token || token.type !== 'image') return false
  if (isInlineImageToken(token)) return true
  const raw = String(token.raw || '').trim().toLowerCase()
  const altText = String(token.text || '').trim()
  return raw.startsWith('<img') || altText.length === 0
}

function inlineImageRenderSize(record, availableWidth = 0) {
  const widthPx = record?.widthPx ?? 0
  const heightPx = record?.heightPx ?? 0
  const contentMaxWidth = Math.max(0, availableWidth)
  if (widthPx <= 0 || heightPx <= 0) {
    return { width: 24, height: 24 }
  }
  if (contentMaxWidth <= 0) {
    return {
      width: Math.max(1, Math.round(widthPx)),
      height: Math.max(1, Math.round(heightPx))
    }
  }
  const scale = Math.min(1, contentMaxWidth / widthPx, 1200 / heightPx)
  return {
    width: Math.max(1, Math.round(widthPx * scale)),
    height: Math.max(1, Math.round(heightPx * scale))
  }
}

function buildImageToken(raw, href, text = '', inlineImage = false) {
  const token = { type: 'image', raw, href, title: null, text }
  if (inlineImage) token[INLINE_IMAGE_PROP] = true
  return token
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
    result.push(buildImageToken(rawUrl, renderUrl, '', true))
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
    if (href && (!text || text === token.href)) return [buildImageToken(token.raw || text, href, text, true)]
    return [token]
  }
  if (token.type === 'text') return splitTextImageUrls(token)
  return [token]
}

function rewriteParagraphInlineImages(paragraph) {
  paragraph.tokens = (paragraph.tokens || []).flatMap(rewriteInlineImageToken)
}

function demoteLineBreakListItemImages(paragraph, itemHtml) {
  const inlineTokens = paragraph.tokens || []
  const source = itemHtml || ''
  if (!source.includes('\n') && !source.includes('\r')) return
  const hasText = inlineTokens.some((token) => {
    if (!token || token.type === 'image' || token.type === 'br') return false
    return String(token.text || token.raw || '').trim().length > 0
  })
  if (!hasText) return
  for (const token of inlineTokens) {
    if (!token || token.type !== 'image') continue
    const raw = String(token.raw || '')
    const index = raw ? source.indexOf(raw) : -1
    if (index <= 0) continue
    const before = source.slice(0, index)
    if (before.includes('\n') || before.includes('\r')) token[INLINE_IMAGE_PROP] = false
  }
}

function splitParagraphByImages(paragraph) {
  const inlineTokens = paragraph.tokens || []
  if (!inlineTokens.some((t) => t.type === 'image' && !isInlineImageToken(t))) return []
  const hasNonImageText = inlineTokens.some((t) => {
    if (!t || t.type === 'image' || t.type === 'br') return false
    return String(t.text || t.raw || '').trim().length > 0
  })
  const canKeepImagesInline = inlineTokens
    .filter((t) => t && t.type === 'image')
    .every(isMixedInlineImageCandidate)
  if (hasNonImageText && canKeepImagesInline) {
    for (const token of inlineTokens) {
      if (token && token.type === 'image') token[INLINE_IMAGE_PROP] = true
    }
    return []
  }
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
    if (token.type === 'image' && !isInlineImageToken(token)) {
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

function canMergeSelectableParagraph(token) {
  if (!token || token.type !== 'paragraph') return false
  const inlineTokens = token.tokens || []
  if (inlineTokens.length === 0) return false
  return !inlineTokens.some((t) => t && (t.type === 'image' || isInlineImageToken(t)))
}

function mergeParagraphRange(paragraphs) {
  const tokens = []
  const raw = []
  const text = []
  for (let i = 0; i < paragraphs.length; i++) {
    const paragraph = paragraphs[i]
    if (i > 0) {
      tokens.push(buildTextToken('\n\n'))
      raw.push('\n\n')
      text.push('\n\n')
    }
    tokens.push(...(paragraph.tokens || []))
    raw.push(paragraph.raw || '')
    text.push(paragraph.text || paragraph.raw || '')
  }
  return { type: 'paragraph', raw: raw.join(''), text: text.join(''), tokens }
}

function mergeSelectableParagraphRuns(tokens) {
  let i = 0
  while (i < tokens.length) {
    if (!canMergeSelectableParagraph(tokens[i])) {
      i++
      continue
    }
    let end = i + 1
    while (end < tokens.length && canMergeSelectableParagraph(tokens[end])) end++
    if (end - i > 1) tokens.splice(i, end - i, mergeParagraphRange(tokens.slice(i, end)))
    i++
  }
}

const fixture = [
  '![pic_7.png]( https://iili.io/BtYjJwP.png)',
  '![pic_8.png]( https://iili.io/BtYjKPa.png)',
  '[![peOMvse.png]( https://s41.ax1x.com/2026/05/11/peOMvse.png)]( https://imgchr.com/i/peOMvse)',
  '',
  'normal text should stay unchanged',
  '![already_ok](https://example.com/a.png)',
  '我一个完全不懂 css 的后端，现在都开始写大屏了 <a target="_blank" href="https://i.imgur.com/huX6coX.png" rel="nofollow noopener"><img src="https://i.imgur.com/huX6coX.png" class="embedded_image" rel="noreferrer"></a>',
  '<img src="https://example.com/standalone.png" class="embedded_image">',
  '<img src="https://mmbiz.qpic.cn/sz_mmbiz_png/Z6sTV0qrAlQob38vhxI4MHRbnrf4xETXAk2WYMCBBqSQWGRdPl8EibUuict4YfKzFcekQAZjiasMDhGVUICSb6WvcBnRG1AQdibXLSiaA3dPcd0s/0?wx_fmt=png&amp;from=appmsg" class="embedded_image">'
].join('\n')

const actual = normalizeMarkdownSource(fixture)
const expected = [
  '![pic_7.png](https://iili.io/BtYjJwP.png)',
  '![pic_8.png](https://iili.io/BtYjKPa.png)',
  '[![peOMvse.png](https://s41.ax1x.com/2026/05/11/peOMvse.png)](https://imgchr.com/i/peOMvse)',
  '',
  'normal text should stay unchanged',
  '![already_ok](https://example.com/a.png)',
  '我一个完全不懂 css 的后端，现在都开始写大屏了 https://i.imgur.com/huX6coX.png',
  'https://example.com/standalone.png',
  'https://mmbiz.qpic.cn/sz_mmbiz_png/Z6sTV0qrAlQob38vhxI4MHRbnrf4xETXAk2WYMCBBqSQWGRdPl8EibUuict4YfKzFcekQAZjiasMDhGVUICSb6WvcBnRG1AQdibXLSiaA3dPcd0s/0?wx_fmt=png&amp;from=appmsg'
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
if (bareSplit.length !== 0 || inlineBareImageParagraph.tokens.length !== 2 || inlineBareImageParagraph.tokens[1].type !== 'image' || inlineBareImageParagraph.tokens[1][INLINE_IMAGE_PROP] !== true || inlineBareImageParagraph.tokens[1].href !== 'https://i.imgur.com/huX6coX.png') {
  console.error('FAIL inline bare image URL should remain inline in mixed text paragraph')
  console.error(JSON.stringify({ bareSplit, paragraph: inlineBareImageParagraph }, null, 2))
  process.exit(1)
}

const githubBareImageParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'text', raw: '预览 https://github.com/alfredxw/nova/blob/master/img/ide.png', text: '预览 https://github.com/alfredxw/nova/blob/master/img/ide.png' }
  ]
}
rewriteParagraphInlineImages(githubBareImageParagraph)
if (githubBareImageParagraph.tokens.length !== 2 ||
  githubBareImageParagraph.tokens[1].type !== 'image' ||
  githubBareImageParagraph.tokens[1][INLINE_IMAGE_PROP] !== true ||
  githubBareImageParagraph.tokens[1].href !== 'https://raw.githubusercontent.com/alfredxw/nova/master/img/ide.png') {
  console.error('FAIL github blob image URL should render through raw.githubusercontent.com as an inline image candidate')
  console.error(JSON.stringify(githubBareImageParagraph, null, 2))
  process.exit(1)
}

const mmbizBareImageParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'text', raw: '图片 https://mmbiz.qpic.cn/mmbiz_png/Z6sTV0qrAlSeIu71LpLFfVVeXHckHXWicQJg4SggDGRzXRLDVFibYjxQtXEOFTh0P3XtCRf6qvy5ibG1ibKFZ4WmS6LuCua0p37530Vhufg6how/0?from=appmsg&amp;wx_fmt=png', text: '图片 https://mmbiz.qpic.cn/mmbiz_png/Z6sTV0qrAlSeIu71LpLFfVVeXHckHXWicQJg4SggDGRzXRLDVFibYjxQtXEOFTh0P3XtCRf6qvy5ibG1ibKFZ4WmS6LuCua0p37530Vhufg6how/0?from=appmsg&amp;wx_fmt=png' }
  ]
}
rewriteParagraphInlineImages(mmbizBareImageParagraph)
if (mmbizBareImageParagraph.tokens.length !== 2 ||
  mmbizBareImageParagraph.tokens[1].type !== 'image' ||
  mmbizBareImageParagraph.tokens[1][INLINE_IMAGE_PROP] !== true ||
  mmbizBareImageParagraph.tokens[1].href !== 'https://mmbiz.qpic.cn/mmbiz_png/Z6sTV0qrAlSeIu71LpLFfVVeXHckHXWicQJg4SggDGRzXRLDVFibYjxQtXEOFTh0P3XtCRf6qvy5ibG1ibKFZ4WmS6LuCua0p37530Vhufg6how/0?from=appmsg&amp;wx_fmt=png') {
  console.error('FAIL mmbiz wx_fmt image URLs should render as inline image candidates')
  console.error(JSON.stringify(mmbizBareImageParagraph, null, 2))
  process.exit(1)
}

const renderedHtmlImageParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'text', raw: '我一个完全不懂 css 的后端，现在都开始写大屏了', text: '我一个完全不懂 css 的后端，现在都开始写大屏了' },
    { type: 'image', raw: '<img src="https://i.imgur.com/huX6coX.png" class="embedded_image" rel="noreferrer">', href: 'https://i.imgur.com/huX6coX.png', text: '' }
  ]
}
const renderedHtmlSplit = splitParagraphByImages(renderedHtmlImageParagraph)
if (renderedHtmlSplit.length !== 0 || renderedHtmlImageParagraph.tokens[1][INLINE_IMAGE_PROP] !== true) {
  console.error('FAIL rendered HTML img in mixed text paragraph should remain inline')
  console.error(JSON.stringify({ renderedHtmlSplit, paragraph: renderedHtmlImageParagraph }, null, 2))
  process.exit(1)
}

const mixedRenderedHtmlAndStandaloneImage = [
  {
    type: 'paragraph',
    tokens: [
      { type: 'text', raw: 'emoji ', text: 'emoji ' },
      buildImageToken('<img src="https://example.com/emoji.png">', 'https://example.com/emoji.png', '', true)
    ]
  },
  {
    type: 'paragraph',
    tokens: [
      buildImageToken('![standalone](https://example.com/standalone.png)', 'https://example.com/standalone.png', 'standalone', false)
    ]
  }
]
const mixedInlineSplit = splitParagraphByImages(mixedRenderedHtmlAndStandaloneImage[0])
const standaloneSplit = splitParagraphByImages(mixedRenderedHtmlAndStandaloneImage[1])
if (mixedInlineSplit.length !== 0 || mixedRenderedHtmlAndStandaloneImage[0].tokens[1][INLINE_IMAGE_PROP] !== true || standaloneSplit.length !== 0 || mixedRenderedHtmlAndStandaloneImage[1].tokens[0][INLINE_IMAGE_PROP] === true) {
  console.error('FAIL inline source-flow image and standalone image block semantics must coexist')
  console.error(JSON.stringify({ mixedInlineSplit, standaloneSplit, mixedRenderedHtmlAndStandaloneImage }, null, 2))
  process.exit(1)
}


const inlineNatural360 = inlineImageRenderSize({ widthPx: 1200, heightPx: 800 }, 360)
if (inlineNatural360.width !== 360 || inlineNatural360.height !== 240) {
  console.error('FAIL inline image actual dimensions must preserve aspect ratio under 360 available width constraint')
  console.error(JSON.stringify(inlineNatural360, null, 2))
  process.exit(1)
}
const inlineNatural280 = inlineImageRenderSize({ widthPx: 1200, heightPx: 800 }, 280)
if (inlineNatural280.width !== 280 || inlineNatural280.height !== 187) {
  console.error('FAIL inline image actual dimensions must follow variable paragraph available width constraint')
  console.error(JSON.stringify(inlineNatural280, null, 2))
  process.exit(1)
}
const inlineSmallNatural = inlineImageRenderSize({ widthPx: 32, heightPx: 18 }, 360)
if (inlineSmallNatural.width !== 32 || inlineSmallNatural.height !== 18) {
  console.error('FAIL naturally small inline images should stay small from actual dimensions, not from a separate icon class')
  console.error(JSON.stringify(inlineSmallNatural, null, 2))
  process.exit(1)
}
const inlineNoRecord = inlineImageRenderSize(null, 360)
if (inlineNoRecord.width !== 24 || inlineNoRecord.height !== 24) {
  console.error('FAIL inline image without a size record should use a visible pending load sentinel')
  console.error(JSON.stringify(inlineNoRecord, null, 2))
  process.exit(1)
}
const inlineRecordedNoWidth = inlineImageRenderSize({ widthPx: 32, heightPx: 18 }, 0)
if (inlineRecordedNoWidth.width !== 32 || inlineRecordedNoWidth.height !== 18) {
  console.error('FAIL recorded inline images without measured available width should still use the known intrinsic size')
  console.error(JSON.stringify(inlineRecordedNoWidth, null, 2))
  process.exit(1)
}

const renderedImageBeforeTextParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'image', raw: '<img src="https://example.com/topic1212780.png" class="embedded_image">', href: 'https://example.com/topic1212780.png', text: '' },
    { type: 'text', raw: '效果已经不是当下 Agent 的主要矛盾', text: '效果已经不是当下 Agent 的主要矛盾' }
  ]
}
const renderedImageBeforeTextSplit = splitParagraphByImages(renderedImageBeforeTextParagraph)
if (renderedImageBeforeTextSplit.length !== 0 || renderedImageBeforeTextParagraph.tokens.map((t) => t.type).join(',') !== 'image,text' || renderedImageBeforeTextParagraph.tokens[0][INLINE_IMAGE_PROP] !== true) {
  console.error('FAIL rendered HTML <p><img>文本</p> should preserve token order and inline source structure')
  console.error(JSON.stringify({ renderedImageBeforeTextSplit, paragraph: renderedImageBeforeTextParagraph }, null, 2))
  process.exit(1)
}

const repro1218385ListItemHtml = '管理 agent\n<img alt="" class="embedded_image" loading="lazy" referrerpolicy="no-referrer" rel="noreferrer" src="https://i.imgur.com/qGqExIQ.png"/> '
const repro1218385ListItemParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'text', raw: '管理 agent ', text: '管理 agent ' },
    buildImageToken('<img alt="" class="embedded_image" loading="lazy" referrerpolicy="no-referrer" rel="noreferrer" src="https://i.imgur.com/qGqExIQ.png"/>', 'https://i.imgur.com/qGqExIQ.png', '', true)
  ]
}
demoteLineBreakListItemImages(repro1218385ListItemParagraph, repro1218385ListItemHtml)
if (repro1218385ListItemParagraph.tokens[1][INLINE_IMAGE_PROP] !== false) {
  console.error('FAIL topic 1218385 list item screenshot image must render as block content below the list text')
  console.error(JSON.stringify(repro1218385ListItemParagraph, null, 2))
  process.exit(1)
}

const sameLineInlineListItemHtml = '状态 <img src="https://example.com/icon.png" class="emoji">'
const sameLineInlineListItemParagraph = {
  type: 'paragraph',
  tokens: [
    { type: 'text', raw: '状态 ', text: '状态 ' },
    buildImageToken('<img src="https://example.com/icon.png" class="emoji">', 'https://example.com/icon.png', '', true)
  ]
}
demoteLineBreakListItemImages(sameLineInlineListItemParagraph, sameLineInlineListItemHtml)
if (sameLineInlineListItemParagraph.tokens[1][INLINE_IMAGE_PROP] !== true) {
  console.error('FAIL same-line list item images/icons should keep inline source semantics')
  console.error(JSON.stringify(sameLineInlineListItemParagraph, null, 2))
  process.exit(1)
}

const paragraphRun = [
  { type: 'paragraph', raw: '第一段', text: '第一段', tokens: [buildTextToken('第一段')] },
  { type: 'paragraph', raw: '第二段', text: '第二段', tokens: [buildTextToken('第二段')] },
  { type: 'customImageBlock', href: 'https://example.com/a.png' },
  { type: 'paragraph', raw: '第三段', text: '第三段', tokens: [buildTextToken('第三段')] },
  { type: 'paragraph', raw: '第四段', text: '第四段', tokens: [buildTextToken('第四段')] }
]
mergeSelectableParagraphRuns(paragraphRun)
if (paragraphRun.length !== 3 || paragraphRun[0].tokens.length !== 3 || paragraphRun[0].tokens[1].text !== '\n\n' || paragraphRun[2].tokens[1].text !== '\n\n') {
  console.error('FAIL selectable paragraph runs should merge adjacent text paragraphs across blank lines')
  console.error(JSON.stringify(paragraphRun, null, 2))
  process.exit(1)
}

const paragraphRunWithInlineImage = [
  { type: 'paragraph', raw: '前', text: '前', tokens: [buildTextToken('前')] },
  { type: 'paragraph', raw: '图', text: '图', tokens: [buildTextToken('图'), buildImageToken('https://example.com/i.png', 'https://example.com/i.png', '', true)] }
]
mergeSelectableParagraphRuns(paragraphRunWithInlineImage)
if (paragraphRunWithInlineImage.length !== 2) {
  console.error('FAIL inline image paragraphs should not be merged into selectable text runs')
  console.error(JSON.stringify(paragraphRunWithInlineImage, null, 2))
  process.exit(1)
}

const source = await import('node:fs').then(fs => fs.readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8'))
const imageInternalsSource = await import('node:fs').then(fs => fs.readFileSync('shared/src/main/ets/components/markdown/MarkdownImageInternals.ets', 'utf8'))
const imageRenderingSource = `${source}\n${imageInternalsSource}`
const customListMatch = source.match(/struct CustomList[\s\S]*?\/\/ customInlineBuilder callback/)
if (!customListMatch) {
  console.error('FAIL could not locate CustomList source block')
  process.exit(1)
}
const customListSource = customListMatch[0]
if (!/MarkdownParagraph\(\{[\s\S]*paragraphToken: child as Tokens\.Paragraph/.test(customListSource)) {
  console.error('FAIL CustomList must delegate paragraph rendering to MarkdownParagraph to preserve text/image token order')
  process.exit(1)
}
if (!/demoteLineBreakListItemImages\(paragraph, match\[1\]\)/.test(source) || !/private static demoteLineBreakListItemImages\(paragraph: Tokens\.Paragraph, itemHtml: string\): void/.test(source)) {
  console.error('FAIL rendered HTML list item images after a source line break must be demoted from inline spans to block image content')
  process.exit(1)
}
if (/paragraphTextTokens|paragraphImageTokens/.test(customListSource)) {
  console.error('FAIL CustomList must not render all paragraph text before all paragraph images')
  process.exit(1)
}
const processTokensMatch = source.match(/private static processTokens[\s\S]*?return tokens;/)
if (!processTokensMatch) {
  console.error('FAIL could not locate processTokens source block')
  process.exit(1)
}
const processTokensSource = processTokensMatch[0]
if (/splitMixedImageParagraphs\(/.test(processTokensSource)) {
  console.error('FAIL processTokens must not split mixed text/image paragraphs into top-level custom blocks')
  process.exit(1)
}
if (!/buildImageToken\(String\(record(?:\["raw"\]|\.raw) \?\? text\), href, text, true\)/.test(source)) {
  console.error('FAIL bare/autolinked image URLs should start as inline candidates and only standalone lines should be demoted')
  process.exit(1)
}
if (/_classifyInlineImageSize|inlineSmall|blockLarge|INLINE_IMAGE_(?:SMALL|LARGE)|INLINE_IMAGE_FALLBACK_(?:MIN|MAX)_SIZE|_inlineImageSize\(/.test(source)) {
  console.error('FAIL image dimensions must not classify inline vs block layout or use inline-small fallback classes')
  process.exit(1)
}
if (/INLINE_IMAGE_SPAN_MAX_WIDTH|INLINE_IMAGE_SPAN_MAX_HEIGHT/.test(source)) {
  console.error('FAIL inline images must not use fixed 320x240 span caps')
  process.exit(1)
}
const inlineSizeSource = `${imageRenderingSource.match(/function _inlineImageRenderSize[\s\S]*?\n}/)?.[0] || ''}\n${imageRenderingSource.match(/function _inlineImageRenderSizeByUrl[\s\S]*?\n}/)?.[0] || ''}`
if (/INLINE_IMAGE_CONTENT_MAX_WIDTH\s*=\s*360/.test(source) || !/const INLINE_IMAGE_PENDING_SIZE = 24;/.test(imageRenderingSource) || !/availableWidth: number/.test(inlineSizeSource) || !/const contentMaxWidth = Math\.max\(0, availableWidth\);/.test(inlineSizeSource) || !/widthPx[\s\S]*heightPx/.test(inlineSizeSource) || !/width: INLINE_IMAGE_PENDING_SIZE,[\s\S]*height: INLINE_IMAGE_PENDING_SIZE/.test(inlineSizeSource) || !/contentMaxWidth <= 0[\s\S]*Math\.round\(widthPx\)[\s\S]*Math\.round\(heightPx\)/.test(inlineSizeSource) || !/contentMaxWidth \/ widthPx/.test(inlineSizeSource)) {
  console.error('FAIL inline image dimensions should use a visible pending sentinel, then prefer known dimensions before measured width is available')
  process.exit(1)
}
if (!/@Local private paragraphAvailableWidth: number = 0;/.test(source) || !/@Param contentAvailableWidth: number = 0;/.test(source) || !/return this\.contentAvailableWidth;/.test(source) || !/\.onAreaChange\(\(_oldValue: Area, newValue: Area\) => \{\n\s*this\.updateParagraphAvailableWidth\(newValue\);/.test(source) || !/SelectableInlineTokenSpans\([\s\S]*this\.inlineContentMaxWidth\(\)/.test(source) || !/contentAvailableWidth: this\.contentAvailableWidth/.test(source)) {
  console.error('FAIL MarkdownParagraph must measure paragraph width, fall back to root content width, and pass it into inline image sizing')
  process.exit(1)
}
if (!/splitResolvedWideInlineImages\(tokens, sizeRecords\)/.test(source) || !/splitParagraphByResolvedWideInlineImages/.test(source) || !/shouldFlowInlineImageAsBlock/.test(source) || !/record\.widthPx > 96 \|\| record\.heightPx > 48/.test(source)) {
  console.error('FAIL resolved large inline images must have a source-order block fallback after ImageSpan dynamic sizing fails')
  process.exit(1)
}
if (/return \{ width: fallback, height: fallback \}/.test(source)) {
  console.error('FAIL missing inline image records must not fall back to font-size square icons')
  process.exit(1)
}
if (/\(event\?\.loadingStatus \?\? 0\) !== 1/.test(source) || !/widthPx <= 0 \|\| heightPx <= 0/.test(imageRenderingSource)) {
  console.error('FAIL inline image completion should record any onComplete event with valid intrinsic dimensions, including loadingStatus 0 data-load callbacks')
  process.exit(1)
}
const paragraphMatch = source.match(/struct MarkdownParagraph[\s\S]*?\n}\n\n@ComponentV2\nstruct MarkdownBlockquote/)
if (!paragraphMatch || !/ForEach\(this\.inlineTokens\(\)/.test(paragraphMatch[0])) {
  console.error('FAIL MarkdownParagraph must render mixed block images by iterating the original inline token order')
  process.exit(1)
}

console.log('PASS: markdown image spacing, linked image blocks, mixed inline image tokens, paragraph selection runs, and source-order mixed paragraph rendering')
