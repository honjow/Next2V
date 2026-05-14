#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

function decodeHtml(value) {
  return (value || '')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
}

function attr(tag, name) {
  const re = new RegExp(`${name}=['"]([^'"]*)['"]`, 'i')
  const m = tag.match(re)
  return m ? decodeHtml(m[1]).trim() : ''
}

function imageTagToMarkdown(tag, fallbackHref) {
  const src = attr(tag, 'src') || decodeHtml(fallbackHref || '').trim()
  return src || ''
}

function replyHtmlToMarkdown(html) {
  return decodeHtml((html || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>\s*<p[^>]*>/gi, '\n\n')
    .replace(/<p[^>]*>/gi, '')
    .replace(/<\/p>/gi, '')
    .replace(/<pre[^>]*><code[^>]*>([\s\S]*?)<\/code><\/pre>/gi, '\n```\n$1\n```\n')
    .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>\s*(<img\b[^>]*>)\s*<\/a>/gi,
      (_match, href, imgTag) => imageTagToMarkdown(imgTag, href))
    .replace(/<img\b[^>]*>/gi, match => imageTagToMarkdown(match, ''))
    .replace(/@?\s*<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>[\s\S]*?<\/a>/gi, '[@$1](/member/$1)')
    .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)')
    .replace(/<[^>]+>/g, ''))
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

const sameLine = '看样子，这只是冰山一角，这个同事，以后有你受的了 <a target="_blank" href="https://i.imgur.com/14cwgsI.png" rel="nofollow noopener"><img src="https://i.imgur.com/14cwgsI.png" class="embedded_image" rel="noreferrer"></a>'
assert.equal(
  replyHtmlToMarkdown(sameLine),
  '看样子，这只是冰山一角，这个同事，以后有你受的了 https://i.imgur.com/14cwgsI.png'
)

const exactReply127 = '@<a href="/member/iixy">iixy</a> #6 要黑丝也可以 <a target="_blank" href="https://i.imgur.com/MA8YqTP.png" rel="nofollow noopener" target="_blank"><img src="https://i.imgur.com/MA8YqTP.png" class="embedded_image" rel="noreferrer"></a>'
assert.equal(
  replyHtmlToMarkdown(exactReply127),
  '[@iixy](/member/iixy) #6 要黑丝也可以 https://i.imgur.com/MA8YqTP.png'
)
assert.doesNotMatch(replyHtmlToMarkdown(exactReply127), /\n/)

const explicitBreak = '前<br><a href="https://example.com/a.png"><img src="https://example.com/a.png"></a><br>后'
assert.equal(replyHtmlToMarkdown(explicitBreak), '前\nhttps://example.com/a.png\n后')

const parserSource = readFileSync('shared/src/main/ets/parser/V2exTopicRepliesParser.ets', 'utf8')
assert.doesNotMatch(parserSource, /return `\\n\\n\$\{src\}\\n\\n`/)
assert.match(parserSource, /return src\b/)

const replyCardSource = readFileSync('shared/src/main/ets/components/ReplyCard.ets', 'utf8')
assert.match(replyCardSource, /this\.reply\.content_rendered/)
assert.match(replyCardSource, /return this\.reply\.content_rendered/)

const markdownSource = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
assert.doesNotMatch(markdownSource, /if \(!value\.startsWith\('<'\)\)/)

console.log('PASS: V2EX reply HTML image conversion and ReplyCard rendered source flow preserve webpage inline layout')
