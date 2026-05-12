#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const fixture = readFileSync(new URL('./fixtures/topic_1210250_image_replies.html', import.meta.url), 'utf8')

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

function parseNumber(value) {
  const parsed = Number.parseInt(value || '0', 10)
  return Number.isFinite(parsed) ? parsed : 0
}

function extractAttr(tag, name) {
  const re = new RegExp(`${name}=['"]([^'"]*)['"]`, 'i')
  const m = (tag || '').match(re)
  return m?.[1] ? decodeHtml(m[1]) : ''
}

function imageMarkdownFromTag(tag, fallbackHref = '') {
  const src = extractAttr(tag, 'src') || decodeHtml(fallbackHref).trim()
  const alt = extractAttr(tag, 'alt')
  return src ? `![${alt}](${src})` : ''
}

function replyHtmlToMarkdown(html) {
  return decodeHtml((html || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>\s*<p[^>]*>/gi, '\n\n')
    .replace(/<p[^>]*>/gi, '')
    .replace(/<\/p>/gi, '')
    .replace(/<pre[^>]*><code[^>]*>([\s\S]*?)<\/code><\/pre>/gi, '\n```\n$1\n```\n')
    .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>\s*(<img\b[^>]*>)\s*<\/a>/gi, (_all, href, imgTag) => imageMarkdownFromTag(imgTag, href))
    .replace(/<img\b[^>]*>/gi, tag => imageMarkdownFromTag(tag))
    .replace(/@?\s*<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>[\s\S]*?<\/a>/gi, '[@$1](/member/$1)')
    .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)')
    .replace(/<[^>]+>/g, ''))
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

function parseReplies(html) {
  const replies = []
  const replyRe = /<div\s+id=['"]r_(\d+)['"][^>]*class=['"][^'"]*\bcell\b[^'"]*['"][^>]*>([\s\S]*?)(?=<div\s+id=['"]r_\d+['"][^>]*class=['"][^'"]*\bcell\b|<div\s+class=['"]sep20['"]|$)/gi
  let m = replyRe.exec(html)
  while (m) {
    const id = parseNumber(m[1])
    const block = m[2] || ''
    const contentRendered = block.match(/<div[^>]*class=['"][^'"]*\breply_content\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i)?.[1]?.trim() || ''
    const username = block.match(/<a[^>]+href=['"]\/member\/([^'"]+)['"][^>]*>/i)?.[1] || ''
    replies.push({ id, username, content: replyHtmlToMarkdown(contentRendered), content_rendered: contentRendered })
    m = replyRe.exec(html)
  }
  return replies
}

const replies = parseReplies(fixture)
const imageReplies = replies.filter(reply => /<img\b/i.test(reply.content_rendered)).slice(0, 5)
assert.equal(imageReplies.length, 5, 'fixture should contain at least five first-layer image replies')

const expected = [
  [17598492, 'https://i.imgur.com/DXS3x2H.png'],
  [17598493, 'https://i.imgur.com/ghVwGYT.png'],
  [17598494, 'https://i.imgur.com/U3Xz7Es.png'],
  [17598496, 'https://i.imgur.com/H6Gbmuk.png'],
  [17598497, 'https://i.imgur.com/01QPpcb.png'],
]
for (let i = 0; i < expected.length; i++) {
  const [id, url] = expected[i]
  assert.equal(imageReplies[i].id, id)
  assert.equal(imageReplies[i].content, `![](${url})`)
  assert.doesNotMatch(imageReplies[i].content, /^\[\]\(/, 'linked image must not become an empty text link')
}

assert.equal(replyHtmlToMarkdown('<a href="https://example.com">linked text</a>'), '[linked text](https://example.com)')
assert.equal(replyHtmlToMarkdown('@<a href="/member/alice">alice</a>'), '[@alice](/member/alice)')
assert.equal(replyHtmlToMarkdown('<img src="https://example.com/a.png" alt="a">'), '![a](https://example.com/a.png)')

const parserSource = readFileSync(new URL('../shared/src/main/ets/parser/V2exTopicRepliesParser.ets', import.meta.url), 'utf8')
assert.match(parserSource, /imageTagToMarkdown/, 'production parser should have a dedicated img-to-markdown conversion')
assert.match(parserSource, /<a\[\^>\]\+href=\['"\]\(\[\^'"\]\+\)\['"\]\[\^>\]\*>\\s\*\(<img\\b\[\^>\]\*>\)\\s\*<\\\/a>/, 'production parser should convert linked img anchors before generic links')
assert.match(parserSource, /<img\\b\[\^>\]\*>/, 'production parser should convert standalone img tags')

console.log('PASS: /t/1210250 image-only linked replies convert to image markdown')
